package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/foden303/harness/go/internal/gitport"
)

// UsageTrackerHandler is the PostToolUse hook handler (usage tracking).
// It records the use of Skill / SlashCommand / Task tools to .claude/state/usage-stats.jsonl.
// When the JSONL file exceeds 100KB, it is renamed to .bak and rotated.
//
// shell version: scripts/usage-tracker.sh
type UsageTrackerHandler struct {
	// ProjectRoot is the path to the project root. If empty, cwd is used.
	ProjectRoot string
}

// usageTrackerInput is the stdin JSON of the PostToolUse hook.
type usageTrackerInput struct {
	ToolName  string          `json:"tool_name"`
	ToolInput json.RawMessage `json:"tool_input"`
	CWD       string          `json:"cwd"`
}

// skillToolInput is the tool_input of the Skill tool.
type skillToolInput struct {
	Skill string `json:"skill"`
}

// slashCommandInput is the tool_input of the SlashCommand tool.
type slashCommandInput struct {
	Command string `json:"command"`
	Name    string `json:"name"`
}

// taskToolInput is the tool_input of the Task tool.
type taskToolInput struct {
	SubagentType string `json:"subagent_type"`
}

// usageEntry is one line entry in usage-stats.jsonl.
type usageEntry struct {
	Type      string `json:"type"`
	Name      string `json:"name"`
	Digest    string `json:"digest,omitempty"`
	Timestamp string `json:"timestamp"`
}

// usageTrackerResponse is the response of the UsageTracker hook.
type usageTrackerResponse struct {
	Continue bool `json:"continue"`
}

const (
	usageStatsFile    = "usage-stats.jsonl"
	usageMaxSizeBytes = 100 * 1024 // 100KB
)

// Handle reads the PostToolUse payload from stdin and records usage.
// It always returns {"continue":true} even on error (usage tracking never blocks the main flow).
func (h *UsageTrackerHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	if len(data) > 0 {
		var inp usageTrackerInput
		if err := json.Unmarshal(data, &inp); err == nil && inp.ToolName != "" {
			// Determine the project root (CWD field takes priority)
			projectRoot := h.resolveProjectRoot(inp.CWD)
			h.track(inp, projectRoot)
		}
	}

	return writeUsageJSON(w, usageTrackerResponse{Continue: true})
}

// resolveProjectRoot determines the project root to record to.
// It tries in the order: inp.CWD -> git rev-parse -> h.ProjectRoot -> os.Getwd().
func (h *UsageTrackerHandler) resolveProjectRoot(cwd string) string {
	if cwd != "" {
		if root, err := gitRepoRoot(cwd); err == nil {
			return root
		}
		return cwd
	}
	if h.ProjectRoot != "" {
		return h.ProjectRoot
	}
	wd, _ := os.Getwd()
	return wd
}

// gitRepoRoot returns the git repository root for the given directory.
func gitRepoRoot(dir string) (string, error) {
	out, err := gitport.Output(dir, "rev-parse", "--show-toplevel")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

// track records usage according to tool_name.
func (h *UsageTrackerHandler) track(inp usageTrackerInput, projectRoot string) {
	var entry *usageEntry

	switch inp.ToolName {
	case "Skill":
		entry = h.trackSkill(inp, projectRoot)
	case "SlashCommand":
		entry = h.trackSlashCommand(inp, projectRoot)
	case "Task":
		entry = h.trackTask(inp)
	}

	if entry == nil {
		return
	}

	// Append to the JSONL file
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		return
	}
	statsFile := filepath.Join(stateDir, usageStatsFile)
	h.appendEntry(statsFile, entry)
}

// trackSkill records the use of the Skill tool and returns the entry.
// For the sync-ssot-from-memory / memory skills, it also creates the ssot-synced flag.
func (h *UsageTrackerHandler) trackSkill(inp usageTrackerInput, projectRoot string) *usageEntry {
	var toolIn skillToolInput
	if err := json.Unmarshal(inp.ToolInput, &toolIn); err != nil || toolIn.Skill == "" {
		return nil
	}

	// "harness:impl" → "impl"
	baseName := extractBaseName(toolIn.Skill, ":")

	// SSOT sync flag
	if baseName == "sync-ssot-from-memory" || baseName == "memory" ||
		strings.Contains(toolIn.Skill, "sync-ssot-from-memory") ||
		strings.Contains(toolIn.Skill, ":memory") {
		h.touchSSOTFlag(projectRoot)
	}

	return &usageEntry{
		Type:      "skill",
		Name:      baseName,
		Digest:    digest(inp.ToolInput),
		Timestamp: nowISO(),
	}
}

// trackSlashCommand records the use of the SlashCommand tool and returns the entry.
func (h *UsageTrackerHandler) trackSlashCommand(inp usageTrackerInput, projectRoot string) *usageEntry {
	var toolIn slashCommandInput
	if err := json.Unmarshal(inp.ToolInput, &toolIn); err != nil {
		return nil
	}

	cmdName := toolIn.Command
	if cmdName == "" {
		cmdName = toolIn.Name
	}
	if cmdName == "" {
		return nil
	}

	// Strip the leading "/"
	baseName := strings.TrimPrefix(cmdName, "/")

	// SSOT sync flag
	if strings.Contains(baseName, "sync-ssot-from-memory") || baseName == "memory" {
		h.touchSSOTFlag(projectRoot)
	}

	return &usageEntry{
		Type:      "command",
		Name:      baseName,
		Digest:    digest(inp.ToolInput),
		Timestamp: nowISO(),
	}
}

// trackTask records the use of the Task tool and returns the entry.
func (h *UsageTrackerHandler) trackTask(inp usageTrackerInput) *usageEntry {
	var toolIn taskToolInput
	if err := json.Unmarshal(inp.ToolInput, &toolIn); err != nil || toolIn.SubagentType == "" {
		return nil
	}

	return &usageEntry{
		Type:      "agent",
		Name:      toolIn.SubagentType,
		Digest:    digest(inp.ToolInput),
		Timestamp: nowISO(),
	}
}

// touchSSOTFlag creates the .claude/state/.ssot-synced-this-session flag file.
func (h *UsageTrackerHandler) touchSSOTFlag(projectRoot string) {
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)
	flag := filepath.Join(stateDir, ".ssot-synced-this-session")
	_ = os.WriteFile(flag, []byte(""), 0600)
}

// appendEntry appends the entry to the JSONL file.
// If the file size exceeds 100KB, it renames it to .bak before creating a new one.
func (h *UsageTrackerHandler) appendEntry(statsFile string, entry *usageEntry) {
	// Rotation check
	if fi, err := os.Stat(statsFile); err == nil && fi.Size() > usageMaxSizeBytes {
		bakFile := statsFile + ".bak"
		_ = os.Rename(statsFile, bakFile)
	}

	line, err := json.Marshal(entry)
	if err != nil {
		return
	}

	f, err := os.OpenFile(statsFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = fmt.Fprintf(f, "%s\n", line)
}

// extractBaseName returns the last segment of a string separated by colons or slashes.
func extractBaseName(s, sep string) string {
	parts := strings.Split(s, sep)
	return parts[len(parts)-1]
}

// digest returns the first 100 characters of the raw JSON bytes (for logging).
func digest(raw json.RawMessage) string {
	s := string(raw)
	if len(s) > 100 {
		return s[:100]
	}
	return s
}

// nowISO returns the current time in RFC3339 format.
func nowISO() string {
	return time.Now().UTC().Format(time.RFC3339)
}

// writeUsageJSON writes v to w as JSON.
func writeUsageJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}
