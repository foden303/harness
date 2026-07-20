package session

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/foden303/harness/go/internal/orchestration"
)

// CleanupHandler is the SessionEnd hook handler.
// It removes temporary files on session end.
//
// shell version: scripts/session-cleanup.sh
type CleanupHandler struct {
	// StateDir is the state directory path. When empty it is inferred from cwd.
	StateDir string
}

// cleanupInput is the stdin JSON for the SessionEnd hook.
type cleanupInput struct {
	CWD       string `json:"cwd,omitempty"`
	SessionID string `json:"session_id,omitempty"`
}

// cleanupResponse is the response with the cleanup result.
type cleanupResponse struct {
	Continue bool   `json:"continue"`
	Message  string `json:"message"`
}

// Handle reads the SessionEnd payload from stdin, removes
// temporary files, and writes the result to stdout.
func (h *CleanupHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	var inp cleanupInput
	if len(data) > 0 {
		_ = json.Unmarshal(data, &inp)
	}

	// determine the state directory
	stateDir := h.StateDir
	if stateDir == "" {
		projectRoot := resolveProjectRoot(inp.CWD)
		stateDir = filepath.Join(projectRoot, ".claude", "state")
	}

	// early return if the state directory does not exist
	if _, err := os.Stat(stateDir); err != nil {
		return writeJSON(w, cleanupResponse{Continue: true, Message: "No state directory"})
	}

	// symlink check (security)
	if isSymlink(stateDir) {
		return writeJSON(w, cleanupResponse{Continue: true, Message: "State directory is symlink, skipping"})
	}

	// remove the fixed temporary files
	tempFiles := []string{
		"pending-skill.json",
		"current-operation.json",
	}
	for _, name := range tempFiles {
		path := filepath.Join(stateDir, name)
		if isRegularFile(path) {
			_ = os.Remove(path)
		}
	}

	// clean up inbox-*.tmp files
	h.cleanupGlob(stateDir, "inbox-*.tmp")

	// Phase 90: safety-net rollup of this session into the lifetime orchestration
	// accumulator (idempotent with the TaskCompleted rollup). Record-only, fail-open.
	orchestration.Run(resolveProjectRoot(inp.CWD), inp.SessionID)

	return writeJSON(w, cleanupResponse{Continue: true, Message: "Session cleanup completed"})
}

// cleanupGlob removes files matching a glob pattern within the state directory.
func (h *CleanupHandler) cleanupGlob(stateDir, pattern string) {
	matches, err := filepath.Glob(filepath.Join(stateDir, pattern))
	if err != nil {
		return
	}
	for _, path := range matches {
		if isRegularFile(path) {
			_ = os.Remove(path)
		}
	}
}

// isRegularFile returns whether the path is a regular file (excluding symlinks).
func isRegularFile(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return fi.Mode().IsRegular()
}

// cleanupFilenameGlobMatch returns whether the filename glob-matches the pattern.
// Uses filepath.Match, but only supports patterns without path separators.
func cleanupFilenameGlobMatch(pattern, name string) bool {
	matched, err := filepath.Match(pattern, name)
	if err != nil {
		return false
	}
	return matched
}

// buildCleanupSummary builds a list of files targeted for cleanup, for logging (debug use).
func buildCleanupSummary(files []string) string {
	if len(files) == 0 {
		return "none"
	}
	return strings.Join(files, ", ")
}

// formatCleanupResult returns the cleanup result as JSON (for error display).
func formatCleanupResult(deleted int, err error) string {
	if err != nil {
		return fmt.Sprintf(`{"continue":true,"message":"cleanup partial: %d files removed, error: %v"}`, deleted, err)
	}
	return fmt.Sprintf(`{"continue":true,"message":"Session cleanup completed: %d files removed"}`, deleted)
}
