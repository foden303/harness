package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
)

// CommitCleanupHandler is the PostToolUse hook handler (cleanup after git commit).
// After a git commit command succeeds, it removes the review approval state files.
//
// shell version: scripts/posttooluse-commit-cleanup.sh
type CommitCleanupHandler struct {
	// ProjectRoot is the path to the project root. Uses cwd when empty.
	ProjectRoot string
}

// commitCleanupInput is the stdin JSON for the PostToolUse hook.
type commitCleanupInput struct {
	ToolName   string                 `json:"tool_name,omitempty"`
	ToolInput  map[string]interface{} `json:"tool_input,omitempty"`
	ToolResult interface{}            `json:"tool_result,omitempty"`
}

// Handle reads the PostToolUse payload from stdin and, if a git commit command
// succeeded, removes the review approval state files.
// This handler writes only a log message to stdout (no JSON needed).
func (h *CommitCleanupHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	if len(data) == 0 {
		return nil
	}

	var inp commitCleanupInput
	if err := json.Unmarshal(data, &inp); err != nil {
		return nil
	}

	// Skip anything other than the Bash tool
	if inp.ToolName != "Bash" {
		return nil
	}

	// Get the command
	command := ""
	if v, ok := inp.ToolInput["command"]; ok {
		if s, ok := v.(string); ok {
			command = s
		}
	}
	if command == "" {
		return nil
	}

	// Check whether it is a git commit command (case-insensitive)
	if !isGitCommitCommand(command) {
		return nil
	}

	// Convert the tool result to a string
	toolResult := ""
	switch v := inp.ToolResult.(type) {
	case string:
		toolResult = v
	case map[string]interface{}:
		if b, err := json.Marshal(v); err == nil {
			toolResult = string(b)
		}
	}

	// Skip if it contains an error
	if containsErrorIndicator(toolResult) {
		return nil
	}

	// Remove the review approval state files
	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	reviewStateFile := projectRoot + "/.claude/state/review-approved.json"
	reviewResultFile := projectRoot + "/.claude/state/review-result.json"

	stateFileExists := fileExists(reviewStateFile)
	resultFileExists := fileExists(reviewResultFile)

	if stateFileExists || resultFileExists {
		_ = os.Remove(reviewStateFile)
		_ = os.Remove(reviewResultFile)

		_, _ = fmt.Fprint(w, "[Commit Guard] Cleared review approval state. Run an independent review again before the next commit.\n")
	}

	return nil
}

// isGitCommitCommand determines whether the command string contains "git commit".
// Equivalent to bash grep -Eiq: '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)'
func isGitCommitCommand(command string) bool {
	lower := strings.ToLower(command)
	// Scan sequentially for the "git commit" pattern
	searchFrom := 0
	for searchFrom < len(lower) {
		idx := strings.Index(lower[searchFrom:], "git")
		if idx < 0 {
			break
		}
		absIdx := searchFrom + idx

		// The character before "git" must be line start or whitespace
		if absIdx > 0 && !isWordBoundaryBefore(lower[absIdx-1]) {
			searchFrom = absIdx + 1
			continue
		}

		// There must be whitespace after "git"
		afterGit := absIdx + 3
		if afterGit >= len(lower) || !isWordBoundaryBefore(lower[afterGit]) {
			searchFrom = absIdx + 1
			continue
		}

		// Skip whitespace and look for "commit"
		i := afterGit
		for i < len(lower) && isWordBoundaryBefore(lower[i]) {
			i++
		}
		if strings.HasPrefix(lower[i:], "commit") {
			after := i + 6
			if after >= len(lower) || isWordBoundaryBefore(lower[after]) {
				return true
			}
		}
		searchFrom = absIdx + 1
	}
	return false
}

// isWordBoundaryBefore returns whether c is whitespace (a word boundary).
func isWordBoundaryBefore(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

// containsErrorIndicator determines whether the tool result contains signs of an error.
func containsErrorIndicator(result string) bool {
	lower := strings.ToLower(result)
	for _, indicator := range []string{"error", "fatal", "failed", "nothing to commit"} {
		if strings.Contains(lower, indicator) {
			return true
		}
	}
	return false
}
