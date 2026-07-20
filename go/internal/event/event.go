// Package event implements the worker-runtime-side hook handlers.
//
// Each handler receives CC hook JSON from stdin, performs the necessary
// processing, and returns the result on stdout.
// It maintains the same I/O protocol as the shell scripts (hook-handlers/*.sh).
//
// SPEC.md §12 package boundary: these are worker-runtime-side handlers,
// kept separate from internal/guard/ (hook-fastpath).
package event

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// Common types
// ---------------------------------------------------------------------------

// Input is the JSON payload received from CC hooks via stdin.
// It has no required fields like tool_name (unlike the guard package).
type Input struct {
	SessionID  string `json:"session_id,omitempty"`
	HookEvent  string `json:"hook_event_name,omitempty"`
	ToolName   string `json:"tool_name,omitempty"`
	AgentID    string `json:"agent_id,omitempty"`
	AgentType  string `json:"agent_type,omitempty"`
	Error      string `json:"error,omitempty"`
	Message    string `json:"message,omitempty"`
	CWD        string `json:"cwd,omitempty"`
	PluginRoot string `json:"plugin_root,omitempty"`

	// For PermissionDenied
	Tool         string `json:"tool,omitempty"`
	DeniedReason string `json:"denied_reason,omitempty"`
	Reason       string `json:"reason,omitempty"`

	// For Notification
	NotificationType string `json:"notification_type,omitempty"`
	Type             string `json:"type,omitempty"`
	Matcher          string `json:"matcher,omitempty"`
}

// ApproveResponse is a basic approve response.
type ApproveResponse struct {
	Decision          string `json:"decision"`
	Reason            string `json:"reason,omitempty"`
	AdditionalContext string `json:"additionalContext,omitempty"`
}

// SystemMessageResponse is a response containing systemMessage.
type SystemMessageResponse struct {
	SystemMessage string `json:"systemMessage,omitempty"`
}

// RetryResponse is a response containing a retry flag.
type RetryResponse struct {
	Retry         bool   `json:"retry"`
	SystemMessage string `json:"systemMessage,omitempty"`
}

// ---------------------------------------------------------------------------
// Common utilities
// ---------------------------------------------------------------------------

// ReadInput reads JSON from r and converts it to Input.
// Empty input returns an error.
func ReadInput(r io.Reader) (Input, error) {
	data, err := io.ReadAll(r)
	if err != nil {
		return Input{}, fmt.Errorf("reading stdin: %w", err)
	}
	if len(data) == 0 {
		return Input{}, fmt.Errorf("empty input")
	}

	var input Input
	if err := json.Unmarshal(data, &input); err != nil {
		return Input{}, fmt.Errorf("parsing JSON: %w", err)
	}
	return input, nil
}

// WriteJSON writes v to w as JSON (with a trailing newline).
func WriteJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}

// Now returns the current time in ISO 8601 UTC format.
func Now() string {
	return time.Now().UTC().Format(time.RFC3339)
}

// ResolveStateDir returns the state directory path from PROJECT_ROOT.
// When CLAUDE_PLUGIN_DATA is set, it is scoped by a per-project hash.
func ResolveStateDir(projectRoot string) string {
	pluginData := os.Getenv("CLAUDE_PLUGIN_DATA")
	if pluginData != "" {
		// Scope by the project root hash (first 12 characters)
		h := simpleHash(projectRoot)
		return filepath.Join(pluginData, "projects", h)
	}
	return filepath.Join(projectRoot, ".claude", "state")
}

// simpleHash generates a simple 12-character hash from the project root path.
// Implemented in pure Go to avoid depending on shasum.
func simpleHash(s string) string {
	// FNV-like hash (no security needed, used as an identifier)
	var h uint64 = 14695981039346656037
	for i := 0; i < len(s); i++ {
		h ^= uint64(s[i])
		h *= 1099511628211
	}
	return fmt.Sprintf("%012x", h)
}

// EnsureStateDir creates the state directory.
// Returns an error if it is a symlink (security measure).
func EnsureStateDir(stateDir string) error {
	parent := filepath.Dir(stateDir)

	// Symlink check
	if isSymlink(parent) || isSymlink(stateDir) {
		return fmt.Errorf("security: symlinked state path refused: %s", stateDir)
	}

	if err := os.MkdirAll(stateDir, 0700); err != nil {
		return fmt.Errorf("creating state dir: %w", err)
	}
	return nil
}

// isSymlink returns whether the path is a symlink.
func isSymlink(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeSymlink != 0
}

// RotateJSONL truncates a JSONL file to 400 lines when it exceeds 500 lines.
func RotateJSONL(path string) {
	if isSymlink(path) || isSymlink(path+".tmp") {
		return
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return
	}

	// Count lines
	lines := splitLines(data)
	if len(lines) <= 500 {
		return
	}

	// Keep the last 400 lines
	kept := lines[len(lines)-400:]
	content := joinLines(kept)
	_ = os.WriteFile(path+".tmp", []byte(content), 0600)
	_ = os.Rename(path+".tmp", path)
}

// splitLines splits by newline and excludes empty lines.
func splitLines(data []byte) []string {
	var lines []string
	start := 0
	for i, b := range data {
		if b == '\n' {
			line := string(data[start:i])
			if line != "" {
				lines = append(lines, line)
			}
			start = i + 1
		}
	}
	if start < len(data) {
		line := string(data[start:])
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}

// joinLines joins a slice of lines with newlines (with a trailing newline).
func joinLines(lines []string) string {
	return strings.Join(lines, "\n") + "\n"
}
