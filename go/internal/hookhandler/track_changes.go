package hookhandler

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// trackChangesInput is the stdin JSON passed to track-changes.sh.
type trackChangesInput struct {
	ToolName  string `json:"tool_name"`
	CWD       string `json:"cwd"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
	ToolResponse struct {
		FilePath string `json:"filePath"`
	} `json:"tool_response"`
}

// changedFileEntry is a single-line entry in .claude/state/changed-files.jsonl.
type changedFileEntry struct {
	File      string `json:"file"`
	Action    string `json:"action"`
	Timestamp string `json:"timestamp"`
	Important bool   `json:"important"`
}

// trackChangesMaxLines is the rotation threshold for the JSONL file.
const trackChangesMaxLines = 500

// trackChangesDedupWindow is the dedup window for the same file (2 hours).
const trackChangesDedupWindow = 2 * time.Hour

// changedFilesPath is the path of the change-record file.
const changedFilesPath = ".claude/state/changed-files.jsonl"

// importantFilePatterns are the patterns for deciding important files.
var importantFilePatterns = []string{
	"Plans.md",
	"CLAUDE.md",
	"AGENTS.md",
}

// HandleTrackChanges is the Go port of track-changes.sh.
//
// called on PostToolUse Write/Edit/Task events, records file changes
// into .claude/state/changed-files.jsonl.
//
// behavior:
//   - cross-platform path normalization (handles Windows backslashes)
//   - 2-hour dedup (suppresses consecutive records of the same file)
//   - rotates when JSONL exceeds 500 lines (removes old lines)
func HandleTrackChanges(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	if len(strings.TrimSpace(string(data))) == 0 {
		return emptyPostToolOutput(out)
	}

	var input trackChangesInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	// get tool_input.file_path or tool_response.filePath
	filePath := input.ToolInput.FilePath
	if filePath == "" {
		filePath = input.ToolResponse.FilePath
	}

	// exit when there is no file path
	if filePath == "" {
		return emptyPostToolOutput(out)
	}

	// cross-platform path normalization (Windows backslash -> slash)
	filePath = normalizePathSeparators(filePath)

	// convert to a project-relative path when CWD is given
	if input.CWD != "" {
		cwd := normalizePathSeparators(input.CWD)
		filePath = makeRelativePath(filePath, cwd)
	}

	toolName := input.ToolName
	if toolName == "" {
		toolName = "unknown"
	}

	// decide whether it is an important file
	important := isImportantFile(filePath)

	now := time.Now().UTC()
	timestamp := now.Format(time.RFC3339)

	// dedup check: whether the same file was already recorded within 2 hours
	if isDuplicateWithin(filePath, now, trackChangesDedupWindow) {
		return emptyPostToolOutput(out)
	}

	// create the state directory
	stateDir := filepath.Dir(changedFilesPath)
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return emptyPostToolOutput(out)
	}

	// check the existing line count and rotate
	if err := rotateIfNeeded(changedFilesPath, trackChangesMaxLines); err != nil {
		// ignore rotation failure and continue
		fmt.Fprintf(os.Stderr, "[track-changes] rotate: %v\n", err)
	}

	// append the entry to the JSONL
	entry := changedFileEntry{
		File:      filePath,
		Action:    toolName,
		Timestamp: timestamp,
		Important: important,
	}
	entryJSON, err := json.Marshal(entry)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	f, err := os.OpenFile(changedFilesPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return emptyPostToolOutput(out)
	}
	defer f.Close()

	if _, err := fmt.Fprintf(f, "%s\n", entryJSON); err != nil {
		return emptyPostToolOutput(out)
	}

	return emptyPostToolOutput(out)
}

// normalizePathSeparators converts Windows backslashes to slashes.
func normalizePathSeparators(p string) string {
	return strings.ReplaceAll(p, "\\", "/")
}

// makeRelativePath converts filePath to a relative path when it is under cwd.
func makeRelativePath(filePath, cwd string) string {
	// append a trailing slash for a prefix match
	cwdWithSlash := strings.TrimRight(cwd, "/") + "/"
	if strings.HasPrefix(filePath+"/", cwdWithSlash) || filePath == strings.TrimRight(cwd, "/") {
		if strings.HasPrefix(filePath, cwdWithSlash) {
			return filePath[len(cwdWithSlash):]
		}
	}
	return filePath
}

// isImportantFile decides whether a file is important.
// targets Plans.md, CLAUDE.md, AGENTS.md, and test files.
func isImportantFile(filePath string) bool {
	for _, pattern := range importantFilePatterns {
		if strings.Contains(filePath, pattern) {
			return true
		}
	}
	// detect test files
	if strings.Contains(filePath, ".test.") ||
		strings.Contains(filePath, ".spec.") ||
		strings.Contains(filePath, "__tests__") {
		return true
	}
	return false
}

// isDuplicateWithin checks whether the same file was already recorded within the window.
func isDuplicateWithin(filePath string, now time.Time, window time.Duration) bool {
	f, err := os.Open(changedFilesPath)
	if err != nil {
		// no duplicate when the file does not exist
		return false
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var entry changedFileEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			continue
		}
		if entry.File != filePath {
			continue
		}
		t, err := time.Parse(time.RFC3339, entry.Timestamp)
		if err != nil {
			continue
		}
		if now.Sub(t) < window {
			return true
		}
	}
	return false
}

// rotateIfNeeded removes old lines when the JSONL file exceeds maxLines.
func rotateIfNeeded(path string, maxLines int) error {
	f, err := os.Open(path)
	if err != nil {
		// no rotation needed when the file does not exist
		return nil
	}

	var lines []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) != "" {
			lines = append(lines, line)
		}
	}
	f.Close()

	if len(lines) <= maxLines {
		return nil
	}

	// remove old lines (keep the last maxLines lines)
	lines = lines[len(lines)-maxLines:]

	tmpPath := path + ".tmp"
	tmp, err := os.Create(tmpPath)
	if err != nil {
		return fmt.Errorf("create tmp: %w", err)
	}

	w := bufio.NewWriter(tmp)
	for _, line := range lines {
		if _, err := fmt.Fprintln(w, line); err != nil {
			tmp.Close()
			os.Remove(tmpPath)
			return fmt.Errorf("write tmp: %w", err)
		}
	}
	if err := w.Flush(); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return fmt.Errorf("flush tmp: %w", err)
	}
	tmp.Close()

	return os.Rename(tmpPath, path)
}
