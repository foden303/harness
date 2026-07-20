package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// ClearPendingHandler is the PostToolUse hook handler (clears pending-skills).
// After a Skill tool runs, it removes .claude/state/pending-skills/*.pending files.
// The Skill invocation is treated as the quality gate having run, clearing the pending state.
//
// shell version: scripts/posttooluse-clear-pending.sh
type ClearPendingHandler struct {
	// ProjectRoot is the path to the project root. Uses cwd when empty.
	ProjectRoot string
}

// clearPendingResponse is the response of the ClearPending hook.
type clearPendingResponse struct {
	Continue bool `json:"continue"`
}

// Handle reads the payload from stdin (unused) and removes all *.pending files
// in the pending-skills directory.
func (h *ClearPendingHandler) Handle(r io.Reader, w io.Writer) error {
	// Discard stdin (this handler does not use its input)
	_, _ = io.ReadAll(r)

	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	pendingDir := filepath.Join(projectRoot, ".claude", "state", "pending-skills")

	// Skip if the pending directory does not exist
	if _, err := os.Stat(pendingDir); os.IsNotExist(err) {
		return writePendingJSON(w, clearPendingResponse{Continue: true})
	}

	// Remove all *.pending files
	matches, err := filepath.Glob(filepath.Join(pendingDir, "*.pending"))
	if err == nil {
		for _, path := range matches {
			_ = os.Remove(path)
		}
	}

	return writePendingJSON(w, clearPendingResponse{Continue: true})
}

// writePendingJSON writes v to w as JSON.
func writePendingJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}
