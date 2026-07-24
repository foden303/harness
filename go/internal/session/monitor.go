package session

import (
	"bufio"
	"container/ring"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/foden303/harness/go/internal/gitport"
)

// driftTailWindow is the number of trailing lines collectDrift scans.
// Keeps memory bounded (window × one line) even as session.events.jsonl grows large.
const driftTailWindow = 200

// MonitorHandler is the SessionStart hook handler (project state collection).
// On session start it collects project state and generates session.json and tooling-policy.json.
//
// shell version: scripts/session-monitor.sh
type MonitorHandler struct {
	// StateDir is the state directory path. When empty it is inferred from cwd.
	StateDir string
	// PlansFile is the Plans.md path. When empty, projectRoot/Plans.md is used.
	PlansFile string
	// now injects the current time (for tests). When nil, time.Now() is used.
	now func() time.Time
	// MemHealthCommand is the harness-mem health-check function (for test injection).
	// When nil, the production default implementation (bin/harness mem health) is used.
	MemHealthCommand func(ctx context.Context) (healthy bool, reason string, err error)
}

// monitorInput is the stdin JSON for the SessionStart hook.
type monitorInput struct {
	SessionID string `json:"session_id,omitempty"`
	CWD       string `json:"cwd,omitempty"`
}

// sessionStateJSON is the complete schema of session.json.
type sessionStateJSON struct {
	SessionID          string            `json:"session_id"`
	ParentID           interface{}       `json:"parent_session_id"`
	State              string            `json:"state"`
	StateVersion       int               `json:"state_version"`
	StartedAt          string            `json:"started_at"`
	UpdatedAt          string            `json:"updated_at"`
	ResumeToken        string            `json:"resume_token"`
	EventSeq           int               `json:"event_seq"`
	LastEventID        string            `json:"last_event_id"`
	ForkCount          int               `json:"fork_count"`
	Orchestration      orchestrationJSON `json:"orchestration"`
	CWD                string            `json:"cwd"`
	ProjectName        string            `json:"project_name"`
	PromptSeq          int               `json:"prompt_seq"`
	Git                gitStateJSON      `json:"git"`
	Plans              plansStateJSON    `json:"plans"`
	HarnessMem         harnessMemJSON    `json:"harness_mem"`
	ChangesThisSession []interface{}     `json:"changes_this_session"`
}

// harnessMemJSON is the schema of the harness_mem field in session.json.
type harnessMemJSON struct {
	Healthy     bool   `json:"healthy"`
	LastChecked string `json:"last_checked"`
	LastError   string `json:"last_error"`
}

type orchestrationJSON struct {
	MaxStateRetries     int `json:"max_state_retries"`
	RetryBackoffSeconds int `json:"retry_backoff_seconds"`
}

type gitStateJSON struct {
	Branch             string `json:"branch"`
	UncommittedChanges int    `json:"uncommitted_changes"`
	LastCommit         string `json:"last_commit"`
}

type plansStateJSON struct {
	Exists         bool  `json:"exists"`
	LastModified   int64 `json:"last_modified"`
	WIPTasks       int   `json:"wip_tasks"`
	TODOTasks      int   `json:"todo_tasks"`
	PendingTasks   int   `json:"pending_tasks"`
	CompletedTasks int   `json:"completed_tasks"`
}

// toolingPolicyJSON is the schema of tooling-policy.json (simplified version).
// Avoids heavy external command dependencies for LSP/MCP detection, generating only basic information.
type toolingPolicyJSON struct {
	LSP     lspPolicyJSON    `json:"lsp"`
	Plugins pluginPolicyJSON `json:"plugins"`
	MCP     mcpPolicyJSON    `json:"mcp"`
	Skills  skillsPolicyJSON `json:"skills"`
}

type lspPolicyJSON struct {
	Available           bool            `json:"available"`
	Plugins             string          `json:"plugins"`
	AvailableByExt      map[string]bool `json:"available_by_ext"`
	LastUsedPromptSeq   int             `json:"last_used_prompt_seq"`
	LastUsedToolName    string          `json:"last_used_tool_name"`
	UsedSinceLastPrompt bool            `json:"used_since_last_prompt"`
}

type pluginPolicyJSON struct {
	Installed       *int   `json:"installed"`
	EnabledEstimate *int   `json:"enabled_estimate"`
	Source          string `json:"source"`
}

type mcpPolicyJSON struct {
	Configured      *int     `json:"configured"`
	Disabled        *int     `json:"disabled"`
	EnabledEstimate *int     `json:"enabled_estimate"`
	Sources         []string `json:"sources"`
}

type skillsPolicyJSON struct {
	Index            []interface{} `json:"index"`
	DecisionRequired bool          `json:"decision_required"`
}

// Handle reads the SessionStart payload from stdin,
// generates session.json and tooling-policy.json, and writes a state summary to stdout.
func (h *MonitorHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	var inp monitorInput
	if len(data) > 0 {
		_ = json.Unmarshal(data, &inp)
	}

	projectRoot := resolveProjectRoot(inp.CWD)
	if projectRoot == "" {
		cwd, _ := os.Getwd()
		projectRoot = cwd
	}

	stateDir := h.StateDir
	if stateDir == "" {
		stateDir = filepath.Join(projectRoot, ".claude", "state")
	}

	// symlink check
	if isSymlink(stateDir) || isSymlink(filepath.Dir(stateDir)) {
		fmt.Fprintf(os.Stderr, "[session-monitor] Warning: symlink detected in state directory path, aborting\n")
		return nil
	}

	if err := os.MkdirAll(stateDir, 0700); err != nil {
		return nil
	}

	plansFile := h.PlansFile
	if plansFile == "" {
		plansFile = filepath.Join(projectRoot, "Plans.md")
	}

	now := h.currentTime()
	nowStr := now.UTC().Format(time.RFC3339)

	// collect project information
	projectName := filepath.Base(projectRoot)
	gitState := h.collectGitState(projectRoot)
	plansState := h.collectPlansState(plansFile)

	// 48.1.1: harness-mem health check
	memHealthy, memReason, _ := h.checkMemHealth(projectRoot)
	memState := harnessMemJSON{
		Healthy:     memHealthy,
		LastChecked: nowStr,
		LastError:   memReason,
	}
	if memHealthy {
		memState.LastError = ""
	}

	// generate session.json (decide resume vs. new)
	sessionFile := filepath.Join(stateDir, "session.json")
	h.generateSessionFile(sessionFile, projectRoot, projectName, nowStr, gitState, plansState, memState)

	// generate tooling-policy.json
	policyFile := filepath.Join(stateDir, "tooling-policy.json")
	h.generateToolingPolicy(policyFile)

	// write summary to stdout
	h.writeSummary(w, projectName, gitState, plansState)

	// 48.1.1: harness-mem unhealthy warning
	if !memHealthy {
		reason := memReason
		if reason == "" {
			reason = "unknown"
		}
		fmt.Fprintf(w, "⚠️ harness-mem unhealthy: %s\n", reason)
	}

	// 48.1.2: advisor/reviewer drift detection
	driftLines := h.collectDrift(stateDir, projectRoot)
	for _, line := range driftLines {
		fmt.Fprintln(w, line)
	}

	// 48.1.3: Plans.md threshold evaluation
	if warning := h.checkPlansDrift(plansState, projectRoot); warning != "" {
		fmt.Fprintln(w, warning)
	}

	return nil
}

// collectGitState collects git information.
func (h *MonitorHandler) collectGitState(projectRoot string) gitStateJSON {
	if !isGitRepository(projectRoot) {
		return gitStateJSON{
			Branch:             "(no git)",
			UncommittedChanges: 0,
			LastCommit:         "none",
		}
	}

	return gitStateJSON{
		Branch:             h.readGitBranch(projectRoot),
		UncommittedChanges: 0, // fixed at 0 to avoid a heavy operation
		LastCommit:         h.readGitLastCommit(projectRoot),
	}
}

// readGitBranch reads the branch name via the git command.
func (h *MonitorHandler) readGitBranch(projectRoot string) string {
	branch, err := runGit(projectRoot, "rev-parse", "--abbrev-ref", "HEAD")
	if err == nil && branch != "" {
		return branch
	}

	sha, err := runGit(projectRoot, "rev-parse", "--short=7", "HEAD")
	if err == nil && sha != "" {
		return sha
	}
	return "unknown"
}

// readGitLastCommit reads the latest commit SHA via the git command.
func (h *MonitorHandler) readGitLastCommit(projectRoot string) string {
	sha, err := runGit(projectRoot, "rev-parse", "--short=7", "HEAD")
	if err == nil && sha != "" {
		return sha
	}
	return "none"
}

func isGitRepository(projectRoot string) bool {
	if _, err := runGit(projectRoot, "rev-parse", "--git-dir"); err != nil {
		return false
	}
	return true
}

func runGit(projectRoot string, args ...string) (string, error) {
	output, err := gitport.Output(projectRoot, args...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(output), nil
}

// collectPlansState collects the state of Plans.md.
func (h *MonitorHandler) collectPlansState(plansFile string) plansStateJSON {
	fi, err := os.Stat(plansFile)
	if err != nil {
		return plansStateJSON{Exists: false}
	}

	wipCount := countMatches(plansFile, "cc:WIP")
	todoCount := countMatches(plansFile, "cc:TODO")
	pendingCount := countMatches(plansFile, "pm:pending")
	completedCount := countMatches(plansFile, "cc:done")

	return plansStateJSON{
		Exists:         true,
		LastModified:   fi.ModTime().Unix(),
		WIPTasks:       wipCount,
		TODOTasks:      todoCount,
		PendingTasks:   pendingCount,
		CompletedTasks: completedCount,
	}
}

// generateSessionFile generates session.json (deciding resume vs. new).
func (h *MonitorHandler) generateSessionFile(
	sessionFile, projectRoot, projectName, nowStr string,
	git gitStateJSON,
	plans plansStateJSON,
	mem harnessMemJSON,
) {
	if isSymlink(sessionFile) {
		return
	}

	resumeMode := false
	var existing sessionStateJSON

	// load the existing session
	if data, err := os.ReadFile(sessionFile); err == nil {
		if json.Unmarshal(data, &existing) == nil {
			// resume mode if ended_at is not set;
			// here, resume if EventSeq > 0 and State is one of the active states
			if existing.SessionID != "" && existing.State != "stopped" && existing.State != "completed" && existing.State != "failed" {
				resumeMode = true
			}
		}
	}

	forkMode := os.Getenv("HARNESS_SESSION_FORK") == "true"
	if forkMode {
		resumeMode = false
	}

	var sess sessionStateJSON

	if resumeMode {
		// update the existing session
		existing.CWD = projectRoot
		existing.ProjectName = projectName
		existing.UpdatedAt = nowStr
		existing.Git = git
		existing.Plans = plans
		existing.HarnessMem = mem
		existing.StateVersion = 1
		sess = existing
	} else {
		// new session
		sessionID := fmt.Sprintf("session-%d", time.Now().UnixNano())
		resumeToken := fmt.Sprintf("resume-%d", time.Now().UnixNano())
		parentID := interface{}(nil)
		if forkMode && existing.SessionID != "" {
			parentID = existing.SessionID
		}

		sess = sessionStateJSON{
			SessionID:    sessionID,
			ParentID:     parentID,
			State:        "initialized",
			StateVersion: 1,
			StartedAt:    nowStr,
			UpdatedAt:    nowStr,
			ResumeToken:  resumeToken,
			EventSeq:     0,
			LastEventID:  "",
			ForkCount:    0,
			Orchestration: orchestrationJSON{
				MaxStateRetries:     3,
				RetryBackoffSeconds: 10,
			},
			CWD:                projectRoot,
			ProjectName:        projectName,
			PromptSeq:          0,
			Git:                git,
			Plans:              plans,
			HarnessMem:         mem,
			ChangesThisSession: []interface{}{},
		}
	}

	data, err := json.MarshalIndent(sess, "", "  ")
	if err != nil {
		return
	}

	_ = writeFileAtomic(sessionFile, append(data, '\n'), 0600)
}

// generateToolingPolicy generates tooling-policy.json.
// Avoids heavy external command dependencies (claude plugin list, MCP server search, etc.),
// generating only a basic scaffold.
func (h *MonitorHandler) generateToolingPolicy(policyFile string) {
	if isSymlink(policyFile) {
		return
	}

	policy := toolingPolicyJSON{
		LSP: lspPolicyJSON{
			Available:           false,
			Plugins:             "",
			AvailableByExt:      map[string]bool{},
			LastUsedPromptSeq:   0,
			LastUsedToolName:    "",
			UsedSinceLastPrompt: false,
		},
		Plugins: pluginPolicyJSON{
			Installed:       nil,
			EnabledEstimate: nil,
			Source:          "",
		},
		MCP: mcpPolicyJSON{
			Configured:      nil,
			Disabled:        nil,
			EnabledEstimate: nil,
			Sources:         []string{},
		},
		Skills: skillsPolicyJSON{
			Index:            []interface{}{},
			DecisionRequired: false,
		},
	}

	data, err := json.MarshalIndent(policy, "", "  ")
	if err != nil {
		return
	}

	_ = writeFileAtomic(policyFile, append(data, '\n'), 0644)
}

// writeSummary writes the session state summary to w.
func (h *MonitorHandler) writeSummary(w io.Writer, projectName string, git gitStateJSON, plans plansStateJSON) {
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "Session start - project state")
	fmt.Fprintln(w, strings.Repeat("─", 36))
	fmt.Fprintf(w, "Project: %s\n", projectName)
	fmt.Fprintf(w, "Branch: %s\n", git.Branch)

	if plans.Exists {
		total := plans.WIPTasks + plans.TODOTasks + plans.PendingTasks
		if total > 0 {
			fmt.Fprintf(w, "Plans.md: WIP %d / TODO %d\n", plans.WIPTasks, plans.TODOTasks+plans.PendingTasks)
		}
	}

	fmt.Fprintln(w, strings.Repeat("─", 36))
	fmt.Fprintln(w, "")
}

// currentTime returns the current time.
func (h *MonitorHandler) currentTime() time.Time {
	if h.now != nil {
		return h.now()
	}
	return time.Now()
}

// formatInt returns an int as a pointer (for tooling-policy null values).
func formatInt(v int) *int {
	return &v
}

// atoi converts a string to an int.
func atoi(s string) int {
	v, _ := strconv.Atoi(strings.TrimSpace(s))
	return v
}

// ---------------------------------------------------------------------------
// 48.1.1: harness-mem health check
// ---------------------------------------------------------------------------

// resolveHarnessBinary returns a trusted path to the harness executable binary.
// Priority:
//  1. os.Executable() — the currently running harness binary (most trusted)
//  2. CLAUDE_PLUGIN_ROOT/bin/harness — the plugin-installed path
//  3. exec.LookPath("harness") — harness on PATH
//
// projectRoot/bin/harness is outside the trust boundary (a malicious binary
// could be planted inside the repo), so it is not included in resolution.
func resolveHarnessBinary() (string, error) {
	if exe, err := os.Executable(); err == nil && exe != "" {
		return exe, nil
	}
	if root := os.Getenv("CLAUDE_PLUGIN_ROOT"); root != "" {
		candidate := filepath.Join(root, "bin", "harness")
		if _, statErr := os.Stat(candidate); statErr == nil {
			return candidate, nil
		}
	}
	if lookPath, lookErr := exec.LookPath("harness"); lookErr == nil {
		return lookPath, nil
	}
	return "", errors.New("harness binary not found")
}

// checkMemHealth checks the health of harness-mem.
// When h.MemHealthCommand is set, it is used (for test injection).
// When nil, the production default implementation (exec of bin/harness mem health) is used.
func (h *MonitorHandler) checkMemHealth(projectRoot string) (healthy bool, reason string, err error) {
	if h.MemHealthCommand != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		return h.MemHealthCommand(ctx)
	}
	return h.defaultMemHealthCheck(projectRoot)
}

// defaultMemHealthCheck execs bin/harness mem health and returns the result.
// The projectRoot argument is kept for signature backward compatibility but unused.
// The previous implementation exec'd projectRoot/bin/harness, which risked
// bypassing the guardrail if a malicious binary was planted inside the repo.
// Since v4.3.1 it resolves in the order os.Executable() → CLAUDE_PLUGIN_ROOT/bin/harness → PATH
// (all trusted installed paths).
func (h *MonitorHandler) defaultMemHealthCheck(_ string) (healthy bool, reason string, err error) {
	binaryPath, resolveErr := resolveHarnessBinary()
	if resolveErr != nil {
		// skip if the binary is not found (do not stop monitoring as a whole)
		return true, "", nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, binaryPath, "mem", "health")
	output, cmdErr := cmd.Output()

	// timeout / exec failure
	if ctx.Err() != nil {
		return false, "timeout", ctx.Err()
	}
	if cmdErr != nil {
		// exit code 1 means unhealthy (a normal failure)
		// parse JSON output if present
		if len(output) > 0 {
			var result struct {
				Healthy bool   `json:"healthy"`
				Reason  string `json:"reason"`
			}
			if jsonErr := json.Unmarshal(output, &result); jsonErr == nil {
				return result.Healthy, result.Reason, nil
			}
		}
		return false, cmdErr.Error(), cmdErr
	}

	// exit 0: parse JSON
	var result struct {
		Healthy bool   `json:"healthy"`
		Reason  string `json:"reason"`
	}
	if jsonErr := json.Unmarshal(output, &result); jsonErr != nil {
		return true, "", nil // treat parse failure optimistically as healthy
	}
	return result.Healthy, result.Reason, nil
}

// ---------------------------------------------------------------------------
// 48.1.2: advisor/reviewer drift detection
// ---------------------------------------------------------------------------

// advisorEventJSON is the schema of each line in session.events.jsonl (minimal).
type advisorEventJSON struct {
	SchemaVersion string `json:"schema_version"`
	TaskID        string `json:"task_id"`
	TriggerHash   string `json:"trigger_hash"`
	Ts            string `json:"ts"`
}

// collectDrift scans the trailing 200 lines of session.events.jsonl to detect
// unanswered advisor/reviewer requests past their TTL, and returns warning lines.
func (h *MonitorHandler) collectDrift(stateDir, projectRoot string) []string {
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	ttl := h.readAdvisorTTL(projectRoot)
	now := h.currentTime()

	f, err := os.Open(eventsFile)
	if err != nil {
		return nil
	}
	defer f.Close()

	// Collect the trailing driftTailWindow lines with container/ring.
	// The old implementation piled all lines into a slice then truncated later, growing
	// memory proportionally to the file line count; switch to a fixed-size ring buffer for bounded memory.
	// Always check scanner.Err() too; on I/O error, give up drift detection and return nil
	// (the contract is not to stop the session monitor itself).
	r := ring.New(driftTailWindow)
	lineCount := 0
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		r.Value = scanner.Text()
		r = r.Next()
		lineCount++
	}
	if err := scanner.Err(); err != nil {
		return nil
	}

	// Expand the ring into a []string in oldest-to-newest order.
	// When lineCount < driftTailWindow, nil remains in the front, so skip via type assertion.
	// When lineCount >= driftTailWindow, r points at the oldest position, so just go around once.
	window := lineCount
	if window > driftTailWindow {
		window = driftTailWindow
	}
	lines := make([]string, 0, window)
	r.Do(func(v any) {
		if s, ok := v.(string); ok {
			lines = append(lines, s)
		}
	})

	// collect requests and responses
	type requestInfo struct {
		ts    time.Time
		hasTs bool
		seq   int // appearance order when ts is absent
	}
	advisorRequests := make(map[string]requestInfo) // key: task_id+trigger_hash
	advisorResponses := make(map[string]bool)       // key: task_id+trigger_hash
	reviewRequests := make(map[string]requestInfo)  // key: task_id+trigger_hash
	reviewResponses := make(map[string]bool)        // key: task_id+trigger_hash

	for seq, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var ev advisorEventJSON
		if err := json.Unmarshal([]byte(line), &ev); err != nil {
			continue
		}

		key := makeEventKey(ev.TaskID, ev.TriggerHash)

		var ts time.Time
		hasTs := false
		if ev.Ts != "" {
			if parsed, parseErr := time.Parse(time.RFC3339, ev.Ts); parseErr == nil {
				ts = parsed
				hasTs = true
			}
		}

		switch ev.SchemaVersion {
		case "advisor-request.v1":
			advisorRequests[key] = requestInfo{ts: ts, hasTs: hasTs, seq: seq}
		case "advisor-response.v1":
			advisorResponses[key] = true
		case "worker-report.v1", "review-request.v1":
			reviewRequests[key] = requestInfo{ts: ts, hasTs: hasTs, seq: seq}
		case "review-result.v1":
			reviewResponses[key] = true
		}
	}

	var warnings []string

	// advisor drift: show only the single oldest unanswered request past TTL
	var oldestAdvisorKey string
	var oldestAdvisorElapsed int64 = -1
	var oldestAdvisorID string

	for key, req := range advisorRequests {
		if advisorResponses[key] {
			continue // skip if already answered
		}
		if !req.hasTs {
			continue // skip if ts is absent
		}
		elapsed := int64(now.Sub(req.ts).Seconds())
		if elapsed <= ttl {
			continue // skip if under TTL
		}
		if oldestAdvisorElapsed < 0 || elapsed > oldestAdvisorElapsed {
			oldestAdvisorElapsed = elapsed
			oldestAdvisorKey = key
			// request_id: task_id, or the short hash of trigger_hash
			parts := strings.SplitN(key, ":", 2)
			if parts[0] != "" {
				oldestAdvisorID = parts[0]
			} else if len(parts) > 1 {
				h := parts[1]
				if len(h) > 7 {
					h = h[:7]
				}
				oldestAdvisorID = h
			}
		}
	}
	_ = oldestAdvisorKey
	if oldestAdvisorElapsed >= 0 {
		warnings = append(warnings,
			fmt.Sprintf("⚠️ advisor drift: request_id=%s, waiting %ds", oldestAdvisorID, oldestAdvisorElapsed))
	}

	// reviewer drift: unanswered review request past TTL
	var oldestReviewerKey string
	var oldestReviewerElapsed int64 = -1
	var oldestReviewerID string

	for key, req := range reviewRequests {
		if reviewResponses[key] {
			continue
		}
		if !req.hasTs {
			continue
		}
		elapsed := int64(now.Sub(req.ts).Seconds())
		if elapsed <= ttl {
			continue
		}
		if oldestReviewerElapsed < 0 || elapsed > oldestReviewerElapsed {
			oldestReviewerElapsed = elapsed
			oldestReviewerKey = key
			parts := strings.SplitN(key, ":", 2)
			if parts[0] != "" {
				oldestReviewerID = parts[0]
			} else if len(parts) > 1 {
				rh := parts[1]
				if len(rh) > 7 {
					rh = rh[:7]
				}
				oldestReviewerID = rh
			}
		}
	}
	_ = oldestReviewerKey
	if oldestReviewerElapsed >= 0 {
		warnings = append(warnings,
			fmt.Sprintf("⚠️ reviewer drift: request_id=%s, waiting %ds", oldestReviewerID, oldestReviewerElapsed))
	}

	return warnings
}

// makeEventKey generates an event key from task_id and trigger_hash.
func makeEventKey(taskID, triggerHash string) string {
	return taskID + ":" + triggerHash
}

// readAdvisorTTL reads orchestration.advisor_ttl_seconds from config.yaml.
// On failure it returns the default value 600.
func (h *MonitorHandler) readAdvisorTTL(projectRoot string) int64 {
	const defaultTTL = int64(600)

	configPath := filepath.Clean(filepath.Join(projectRoot, ".harness.config.yaml"))
	f, err := os.Open(configPath)
	if err != nil {
		return defaultTTL
	}
	defer f.Close()

	inOrchestration := false
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		// section detection (no indent)
		if !strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") {
			inOrchestration = strings.TrimRight(trimmed, ":") == "orchestration"
			continue
		}

		if !inOrchestration {
			continue
		}

		if strings.Contains(trimmed, "advisor_ttl_seconds:") {
			parts := strings.SplitN(trimmed, ":", 2)
			if len(parts) == 2 {
				val := strings.TrimSpace(parts[1])
				if v, err := strconv.ParseInt(val, 10, 64); err == nil {
					return v
				}
			}
		}
	}
	return defaultTTL
}

// ---------------------------------------------------------------------------
// 48.1.3: Plans.md threshold evaluation
// ---------------------------------------------------------------------------

// checkPlansDrift checks whether the state of Plans.md exceeds thresholds, and
// returns a warning line (⚠️ plans drift: ...) if so. Returns an empty string otherwise.
func (h *MonitorHandler) checkPlansDrift(plans plansStateJSON, projectRoot string) string {
	if !plans.Exists {
		return ""
	}

	wipThreshold, staleHours := h.readPlansDriftConfig(projectRoot)
	now := h.currentTime()

	wipHit := plans.WIPTasks >= wipThreshold

	lastMod := time.Unix(plans.LastModified, 0)
	elapsedHours := int64(now.Sub(lastMod).Hours())
	staleHit := elapsedHours >= staleHours

	if !wipHit && !staleHit {
		return ""
	}

	return fmt.Sprintf("⚠️ plans drift: WIP=%d, stale_for=%dh", plans.WIPTasks, elapsedHours)
}

// readPlansDriftConfig reads the monitor.plans_drift section from config.yaml.
// On failure it returns the default values (wip_threshold=5, stale_hours=24).
func (h *MonitorHandler) readPlansDriftConfig(projectRoot string) (wipThreshold int, staleHours int64) {
	wipThreshold = 5
	staleHours = 24

	configPath := filepath.Clean(filepath.Join(projectRoot, ".harness.config.yaml"))
	f, err := os.Open(configPath)
	if err != nil {
		return
	}
	defer f.Close()

	inMonitor := false
	inPlansDrift := false

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		// top-level section detection (no indent)
		if !strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") {
			sectionName := strings.TrimRight(trimmed, ":")
			inMonitor = sectionName == "monitor"
			inPlansDrift = false
			continue
		}

		if !inMonitor {
			continue
		}

		// plans_drift subsection detection (one indent level)
		if strings.HasPrefix(line, "  ") && !strings.HasPrefix(line, "    ") {
			subSection := strings.TrimRight(trimmed, ":")
			inPlansDrift = subSection == "plans_drift"
			continue
		}

		if !inPlansDrift {
			continue
		}

		// two-indent-level keys
		if strings.Contains(trimmed, "wip_threshold:") {
			parts := strings.SplitN(trimmed, ":", 2)
			if len(parts) == 2 {
				if v, err := strconv.Atoi(strings.TrimSpace(parts[1])); err == nil {
					wipThreshold = v
				}
			}
		} else if strings.Contains(trimmed, "stale_hours:") {
			parts := strings.SplitN(trimmed, ":", 2)
			if len(parts) == 2 {
				if v, err := strconv.ParseInt(strings.TrimSpace(parts[1]), 10, 64); err == nil {
					staleHours = v
				}
			}
		}
	}
	return
}
