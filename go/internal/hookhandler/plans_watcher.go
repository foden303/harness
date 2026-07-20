package hookhandler

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// exitFailClosed is called on fail-closed paths such as lock acquisition failure.
// In the PostToolUse hook spec, a non-zero exit code is treated as a hook error.
// This prevents "lost updates" where Plans changes are silently dropped.
// It is never called directly from tests (replaced via a mockable variable).
var exitFailClosed = func(msg string) {
	fmt.Fprintf(os.Stderr, "[plans-watcher] fail-closed exit: %s\n", msg)
	os.Exit(1)
}

// plansWatcherInput is the stdin JSON passed to plans-watcher.sh.
type plansWatcherInput struct {
	ToolName  string `json:"tool_name"`
	CWD       string `json:"cwd"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
	ToolResponse struct {
		FilePath string `json:"filePath"`
	} `json:"tool_response"`
}

// plansStateFile is the path to the file storing the previous state.
const plansStateFile = ".claude/state/plans-state.json"

// plansLockFile is the path to the flock file used for mutual exclusion on plans-state.json.
// Semantically equivalent to the 3-tier fallback in the shell version scripts/plans-watcher.sh.
const plansLockFile = ".claude/state/locks/plans.flock"

// plansLockDirSuffix is the name of the mkdir-based fallback lock used in environments where flock is unavailable.
const plansLockDirSuffix = ".dir"

// plansLockMaxRetries is the maximum number of retries for lock acquisition.
const plansLockMaxRetries = 3

// flockCall and sleepCall are replaceable for testing.
var flockCall = func(fd int, how int) error {
	return fileLock(fd, how)
}

var sleepCall = time.Sleep

// plansLockHandle represents either a flock or a mkdir fallback lock.
type plansLockHandle struct {
	file    *os.File
	lockDir string
	mode    string
}

// acquirePlansLock acquires an exclusive lock protecting plans-state.json.
// It normally uses flock, and only falls back to a mkdir-based atomic lock
// when flock is unavailable (e.g. on shared storage).
func acquirePlansLock(lockPath string) (*plansLockHandle, error) {
	if err := os.MkdirAll(filepath.Dir(lockPath), 0o755); err != nil {
		return nil, fmt.Errorf("mkdir for plans lock: %w", err)
	}
	for attempt := 1; attempt <= plansLockMaxRetries; attempt++ {
		f, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0o644)
		if err != nil {
			return nil, fmt.Errorf("open plans lock file: %w", err)
		}

		if err := flockCall(int(f.Fd()), fileLockExclusive|fileLockNonblock); err == nil {
			return &plansLockHandle{
				file:    f,
				lockDir: lockPath + plansLockDirSuffix,
				mode:    "flock",
			}, nil
		} else if !isPlansLockBusy(err) {
			f.Close()
			return acquirePlansMkdirLock(lockPath + plansLockDirSuffix)
		}

		f.Close()
		if attempt < plansLockMaxRetries {
			sleepCall(1 * time.Second)
		}
	}
	return nil, fmt.Errorf("failed to acquire plans lock after %d retries", plansLockMaxRetries)
}

func acquirePlansMkdirLock(lockDir string) (*plansLockHandle, error) {
	for attempt := 1; attempt <= plansLockMaxRetries; attempt++ {
		if err := os.Mkdir(lockDir, 0o755); err == nil {
			return &plansLockHandle{
				lockDir: lockDir,
				mode:    "mkdir",
			}, nil
		} else if !errors.Is(err, os.ErrExist) {
			return nil, fmt.Errorf("mkdir fallback lock: %w", err)
		}

		if attempt < plansLockMaxRetries {
			sleepCall(1 * time.Second)
		}
	}
	return nil, fmt.Errorf("failed to acquire mkdir fallback lock after %d retries", plansLockMaxRetries)
}

func isPlansLockBusy(err error) bool {
	return fileLockBusy(err)
}

// releasePlansLock releases the lock and closes the file.
func releasePlansLock(lock *plansLockHandle) {
	if lock == nil {
		return
	}
	switch lock.mode {
	case "mkdir":
		os.Remove(lock.lockDir) //nolint:errcheck
	default:
		if lock.file == nil {
			return
		}
		flockCall(int(lock.file.Fd()), fileLockUnlock) //nolint:errcheck
		lock.file.Close()
	}
}

// pmNotificationFile is the path to the PM notification file.
const pmNotificationFile = ".claude/state/pm-notification.md"

// plansState is the aggregated marker-count state of Plans.md.
type plansState struct {
	Timestamp   string `json:"timestamp"`
	PmPending   int    `json:"pm_pending"`
	CcTodo      int    `json:"cc_todo"`
	CcWip       int    `json:"cc_wip"`
	CcDone      int    `json:"cc_done"`
	PmConfirmed int    `json:"pm_confirmed"`
}

// plansFileNames are the candidate Plans.md file names to search for.
var plansFileNames = []string{"Plans.md", "plans.md", "PLANS.md", "PLANS.MD"}

// HandlePlansWatcher is the Go port of plans-watcher.sh.
//
// It is invoked on PostToolUse Write/Edit events and detects changes to Plans.md.
// It generates an aggregate summary of WIP/TODO/done markers and writes it to the PM notification file.
// Files other than Plans.md are skipped.
func HandlePlansWatcher(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	if len(strings.TrimSpace(string(data))) == 0 {
		return emptyPostToolOutput(out)
	}

	var input plansWatcherInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	// Get the changed file path
	changedFile := input.ToolInput.FilePath
	if changedFile == "" {
		changedFile = input.ToolResponse.FilePath
	}

	if changedFile == "" {
		return emptyPostToolOutput(out)
	}

	// Convert to a relative path if CWD is available
	if input.CWD != "" {
		changedFile = makeRelativePath(
			normalizePathSeparators(changedFile),
			normalizePathSeparators(input.CWD),
		)
	}

	// Locate the Plans.md file (honoring the config file's plansDirectory).
	// If input.CWD is present, use it as the projectRoot.
	// This fixes the issue of referencing the wrong Plans.md when the hook process's CWD differs from input.CWD.
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	plansFile := resolvePlansPath(projectRoot)
	if plansFile == "" {
		return emptyPostToolOutput(out)
	}

	// Skip if the changed file is not Plans.md (strict full-path comparison)
	if !isPlansFileWithRoot(changedFile, plansFile, projectRoot) {
		return emptyPostToolOutput(out)
	}

	// Resolve CWD into a single variable.
	// By deriving the lock path and state file path from the same CWD,
	// even when hooks run concurrently in different worktrees (CWD A / CWD B),
	// "same CWD -> same lock + same state" and "different CWD -> separate lock + separate state" hold,
	// so per-project independent mutual exclusion works correctly.
	cwd := input.CWD
	if cwd == "" {
		var cwdErr error
		cwd, cwdErr = os.Getwd()
		if cwdErr != nil {
			cwd = ""
		}
	}

	// Derive the lock path and state file path from the same cwd
	lockPath := plansLockFile
	stateFilePath := plansStateFile
	if cwd != "" {
		lockPath = filepath.Join(cwd, plansLockFile)
		// plansStateFile is a relative-path constant, so join it with cwd to make an absolute path
		stateFilePath = filepath.Join(cwd, plansStateFile)
	}

	// Protect the read-modify-write of plans-state.json with flock.
	// Fail-closed so state is not lost due to contention with the Worker: abort processing if lock acquisition fails.
	// In the PostToolUse hook spec, a non-zero exit code is treated as a hook error.
	// Returning emptyPostToolOutput (= empty success response) would make the hook framework interpret it as success,
	// causing a lost update. Returning exit code 1 via exitFailClosed
	// explicitly reports the dropped Plans update to the hook framework as an error.
	lockFile, lockErr := acquirePlansLock(lockPath)
	if lockErr != nil {
		fmt.Fprintf(os.Stderr, "[plans-watcher] lock acquisition failed (fail-closed): %v\n", lockErr)
		exitFailClosed("lock acquisition timed out (3 retries exhausted)")
		// exitFailClosed normally calls os.Exit(1), but fall back to an empty
		// response in case it passes through when mock-replaced during tests.
		return emptyPostToolOutput(out)
	}
	defer releasePlansLock(lockFile)

	// Aggregate the current state
	current, err := collectPlansState(plansFile)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	// Load the previous state (using the CWD-based absolute path)
	prev := loadPrevPlansState(stateFilePath)

	// Save the state (using the CWD-based absolute path)
	stateDir := filepath.Dir(stateFilePath)
	if mkErr := os.MkdirAll(stateDir, 0o755); mkErr == nil {
		savePlansState(stateFilePath, current)
	}

	// Determine the type of change
	hasNewTasks := current.PmPending > prev.PmPending
	hasCompletedTasks := current.CcDone > prev.CcDone

	if !hasNewTasks && !hasCompletedTasks {
		return emptyPostToolOutput(out)
	}

	// Generate the PM notification file
	locale := resolveHarnessLocale(cwd)
	if err := writePMNotification(cwd, current, hasNewTasks, hasCompletedTasks, locale); err != nil {
		fmt.Fprintf(os.Stderr, "[plans-watcher] write notification: %v\n", err)
	}

	// Output the notification summary via systemMessage
	summary := buildSummaryMessage(current, hasNewTasks, hasCompletedTasks, locale)
	o := postToolOutput{}
	o.HookSpecificOutput.HookEventName = "PostToolUse"
	o.HookSpecificOutput.AdditionalContext = summary
	return writeJSON(out, o)
}

// findPlansFile looks for Plans.md in the current directory.
func findPlansFile() string {
	for _, name := range plansFileNames {
		if _, err := os.Stat(name); err == nil {
			return name
		}
	}
	return ""
}

// isPlansFile determines whether the changed file is Plans.md.
//
// Decision logic:
//  1. Exact match via filepath.Clean (handles both relative and absolute paths)
//  2. If changedFile is a relative path, convert it to absolute using projectRoot and re-compare
//
// The old implementation's case-insensitive basename fallback was removed.
// A basename-only comparison would erroneously match a same-named file in another directory
// (e.g. /tmp/other/Plans.md), so only strict full-path matching is used.
func isPlansFile(changedFile, plansFile string) bool {
	// Normalize with filepath.Clean and require an exact match
	if filepath.Clean(changedFile) == filepath.Clean(plansFile) {
		return true
	}
	return false
}

// isPlansFileWithRoot supplements projectRoot when changedFile is a relative path, then compares.
// Used when called from HandlePlansWatcher.
func isPlansFileWithRoot(changedFile, plansFile, projectRoot string) bool {
	// If changedFile is an absolute path, compare it as-is
	if filepath.IsAbs(changedFile) {
		return isPlansFile(changedFile, plansFile)
	}
	// If relative, convert to an absolute path rooted at projectRoot
	absChanged := filepath.Join(projectRoot, changedFile)
	return isPlansFile(absChanged, plansFile)
}

// countMarker returns the number of occurrences of the marker string in Plans.md.
func countMarker(plansFile, marker string) int {
	data, err := os.ReadFile(plansFile)
	if err != nil {
		return 0
	}
	re := regexp.MustCompile(regexp.QuoteMeta(marker))
	return len(re.FindAllIndex(data, -1))
}

// collectPlansState aggregates the markers in Plans.md.
func collectPlansState(plansFile string) (plansState, error) {
	if _, err := os.Stat(plansFile); err != nil {
		return plansState{}, fmt.Errorf("plans file not found: %w", err)
	}

	pmPending := countMarker(plansFile, "pm:pending")
	ccTodo := countMarker(plansFile, "cc:TODO")
	ccWip := countMarker(plansFile, "cc:WIP")
	ccDone := countMarker(plansFile, "cc:done")
	pmConfirmed := countMarker(plansFile, "pm:confirmed")

	return plansState{
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		PmPending:   pmPending,
		CcTodo:      ccTodo,
		CcWip:       ccWip,
		CcDone:      ccDone,
		PmConfirmed: pmConfirmed,
	}, nil
}

// loadPrevPlansState loads the previously saved state. Returns the zero value if it does not exist.
// stateFilePath accepts either an absolute or a relative path.
func loadPrevPlansState(stateFilePath string) plansState {
	data, err := os.ReadFile(stateFilePath)
	if err != nil {
		return plansState{}
	}
	var state plansState
	if err := json.Unmarshal(data, &state); err != nil {
		return plansState{}
	}
	return state
}

// savePlansState saves the current state to a file.
// stateFilePath accepts either an absolute or a relative path.
func savePlansState(stateFilePath string, state plansState) {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return
	}
	os.WriteFile(stateFilePath, append(data, '\n'), 0o644) //nolint:errcheck
}

// buildSummaryMessage builds the notification summary string.
func buildSummaryMessage(state plansState, hasNewTasks, hasCompletedTasks bool, locale string) string {
	var sb strings.Builder

	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	sb.WriteString("Plans.md update detected\n")
	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	if hasNewTasks {
		sb.WriteString("New task: PM requested work\n")
		sb.WriteString("   -> Check the status with /sync-status, then start with /work\n")
	}

	if hasCompletedTasks {
		sb.WriteString("Task completed: ready to report to PM\n")
		sb.WriteString("   -> Report with /handoff-to-pm-claude\n")
	}

	sb.WriteString("\nCurrent status:\n")
	sb.WriteString("   pm:pending    : " + strconv.Itoa(state.PmPending) + "\n")
	sb.WriteString("   cc:TODO        : " + strconv.Itoa(state.CcTodo) + "\n")
	sb.WriteString("   cc:WIP         : " + strconv.Itoa(state.CcWip) + "\n")
	sb.WriteString("   cc:done       : " + strconv.Itoa(state.CcDone) + "\n")
	sb.WriteString("   pm:confirmed  : " + strconv.Itoa(state.PmConfirmed) + "\n")
	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	return sb.String()
}

// writePMNotification generates the PM notification file.
func writePMNotification(cwd string, state plansState, hasNewTasks, hasCompletedTasks bool, locale string) error {
	pmPath := pmNotificationFile
	if cwd != "" {
		pmPath = filepath.Join(cwd, pmNotificationFile)
	}

	stateDir := filepath.Dir(pmPath)
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return fmt.Errorf("mkdir state dir: %w", err)
	}

	ts := time.Now().Format("2006-01-02 15:04:05")
	content := []byte(buildPMNotificationContent(state, hasNewTasks, hasCompletedTasks, ts, locale))
	if err := os.WriteFile(pmPath, content, 0o644); err != nil {
		return fmt.Errorf("write pm-notification.md: %w", err)
	}

	return nil
}

func buildPMNotificationContent(_ plansState, hasNewTasks, hasCompletedTasks bool, ts, locale string) string {
	var sb strings.Builder
	sb.WriteString("# Notification for PM\n\n")
	sb.WriteString("**Generated at**: " + ts + "\n\n")
	sb.WriteString("## Status changes\n\n")

	if hasNewTasks {
		sb.WriteString("### New task\n\n")
		sb.WriteString("PM requested a new task (pm:pending).\n\n")
	}

	if hasCompletedTasks {
		sb.WriteString("### Completed task\n\n")
		sb.WriteString("Impl Claude completed a task. Please review it (cc:done).\n\n")
	}

	sb.WriteString("---\n\n")
	sb.WriteString("**Next action**: Review in PM Claude, then re-request if needed (/handoff-to-impl-claude).\n")
	return sb.String()
}
