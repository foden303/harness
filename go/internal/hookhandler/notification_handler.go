package hookhandler

// notification_handler.go
// Go port of notification-handler.sh.
//
// Records Notification events (permission_prompt, idle_prompt, auth_success, etc.)
// to .claude/state/notification-events.jsonl.
// The notification handler never blocks (always approves).

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// notificationInput is the stdin JSON of the Notification hook.
type notificationInput struct {
	NotificationType string `json:"notification_type"`
	Type             string `json:"type"`
	Matcher          string `json:"matcher"`
	SessionID        string `json:"session_id"`
	AgentType        string `json:"agent_type"`
}

// notificationLogEntry is one entry in notification-events.jsonl.
type notificationLogEntry struct {
	Event            string `json:"event"`
	NotificationType string `json:"notification_type"`
	SessionID        string `json:"session_id"`
	AgentType        string `json:"agent_type"`
	Timestamp        string `json:"timestamp"`
}

// HandleNotification is the Go port of notification-handler.sh.
//
// Invoked by the Notification hook, it records notification events to
// .claude/state/notification-events.jsonl.
// The notification handler always returns approve (never blocks).
func HandleNotification(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		// No input: exit normally (equivalent to exit 0)
		return nil
	}

	var input notificationInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		// Pass through even on parse failure (the notification handler never blocks)
		return nil
	}

	// Resolve notification_type (fall back to type / matcher)
	notificationType := input.NotificationType
	if notificationType == "" {
		notificationType = input.Type
	}
	if notificationType == "" {
		notificationType = input.Matcher
	}

	// Ensure the state directory exists
	stateDir := resolveNotificationStateDir()
	if mkErr := ensureNotificationStateDir(stateDir); mkErr != nil {
		// Pass through even if directory creation fails
		return nil
	}

	// Record to JSONL
	logFile := filepath.Join(stateDir, "notification-events.jsonl")
	entry := notificationLogEntry{
		Event:            "notification",
		NotificationType: notificationType,
		SessionID:        input.SessionID,
		AgentType:        input.AgentType,
		Timestamp:        time.Now().UTC().Format(time.RFC3339),
	}
	if logErr := appendNotificationLog(logFile, entry); logErr != nil {
		// Ignore log write failures
		_ = logErr
	}

	// Emit important notifications about Breezing background Workers to stderr (for debugging)
	if notificationType == "permission_prompt" && input.AgentType != "" {
		fmt.Fprintf(os.Stderr, "Notification: permission_prompt for agent_type=%s\n", input.AgentType)
	}
	if notificationType == "elicitation_dialog" && input.AgentType != "" {
		fmt.Fprintf(os.Stderr,
			"Notification: elicitation_dialog for agent_type=%s (auto-skipped in background)\n",
			input.AgentType)
	}

	// terminalSequence output (CC 2.1.141+, opt-in via HARNESS_TERMINAL_NOTIFY)
	// For notifications that should grab the operator's attention (permission_prompt / elicitation_dialog),
	// Claude Code can fire a desktop notification / window title / bell even without a controlling terminal.
	if title, body, ok := notificationTerminalTitleBody(notificationType, input.AgentType); ok {
		seq := BuildTerminalSequence(title, body)
		if seq != "" {
			resp := map[string]interface{}{
				"decision":         "approve",
				"reason":           "notification logged",
				"terminalSequence": seq,
			}
			if writeErr := writeJSON(out, resp); writeErr != nil {
				return writeErr
			}
			return nil
		}
	}

	// The notification handler always exits normally (approve)
	return nil
}

// notificationTerminalTitleBody builds the title/body used for terminalSequence from notification_type.
// For unknown types it returns ok=false, and no terminalSequence is emitted.
func notificationTerminalTitleBody(notificationType, agentType string) (string, string, bool) {
	agent := agentType
	if agent == "" {
		agent = "main"
	}
	switch notificationType {
	case "permission_prompt":
		return "Claude Code: permission prompt", agent + " waiting for approval", true
	case "elicitation_dialog":
		return "Claude Code: elicitation", agent + " MCP elicitation", true
	case "idle_prompt":
		return "Claude Code: idle", "session idle", true
	case "auth_success":
		return "Claude Code: auth success", "", true
	default:
		return "", "", false
	}
}

// resolveNotificationStateDir returns the state directory, taking environment variables into account.
// If CLAUDE_PLUGIN_DATA is set, it switches to project scope.
func resolveNotificationStateDir() string {
	pluginData := os.Getenv("CLAUDE_PLUGIN_DATA")
	if pluginData != "" {
		projectRoot := os.Getenv("PROJECT_ROOT")
		if projectRoot == "" {
			cwd, err := os.Getwd()
			if err == nil {
				projectRoot = cwd
			}
		}
		hash := shortHashNotification(projectRoot)
		return filepath.Join(pluginData, "projects", hash)
	}

	projectRoot := os.Getenv("PROJECT_ROOT")
	if projectRoot == "" {
		cwd, err := os.Getwd()
		if err == nil {
			projectRoot = cwd
		}
	}
	return filepath.Join(projectRoot, ".claude", "state")
}

// ensureNotificationStateDir creates the directory and refuses symbolic links.
func ensureNotificationStateDir(stateDir string) error {
	parent := filepath.Dir(stateDir)

	// Symlink check (security)
	if isSymlink(parent) || isSymlink(stateDir) {
		return fmt.Errorf("symlinked state path refused: %s", stateDir)
	}

	if mkErr := os.MkdirAll(stateDir, 0o700); mkErr != nil {
		return fmt.Errorf("mkdir state dir: %w", mkErr)
	}

	// Verify again after creation
	info, statErr := os.Lstat(stateDir)
	if statErr != nil {
		return fmt.Errorf("stat state dir: %w", statErr)
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("state dir is symlink: %s", stateDir)
	}
	return nil
}

// appendNotificationLog appends one entry to the JSONL file and rotates it.
func appendNotificationLog(logFile string, entry notificationLogEntry) error {
	// Symlink check
	if isSymlink(logFile) {
		return fmt.Errorf("symlinked log file refused: %s", logFile)
	}

	entryJSON, err := json.Marshal(entry)
	if err != nil {
		return fmt.Errorf("marshal log entry: %w", err)
	}

	f, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("open log file: %w", err)
	}
	defer f.Close()

	if _, writeErr := fmt.Fprintf(f, "%s\n", entryJSON); writeErr != nil {
		return fmt.Errorf("write log entry: %w", writeErr)
	}

	// Rotation: if over 500 lines, truncate to 400 lines
	return rotateJSONL(logFile, 500, 400)
}

// shortHashNotification returns a short (12-char) hash of the project root path.
// Equivalent to bash's shasum -a 256 | cut -c1-12.
func shortHashNotification(input string) string {
	if input == "" {
		return "default"
	}
	// Simple hash: FNV-1a based (no external dependencies)
	var h uint64 = 14695981039346656037
	for i := 0; i < len(input); i++ {
		h ^= uint64(input[i])
		h *= 1099511628211
	}
	return fmt.Sprintf("%012x", h&0xffffffffffff)
}
