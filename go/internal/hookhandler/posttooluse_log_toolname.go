package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// PostToolUseLogToolNameHandler is the PostToolUse hook handler.
// It logs all tool usage and manages LSP tool tracking and session event logs.
//
// shell version: scripts/posttooluse-log-toolname.sh
type PostToolUseLogToolNameHandler struct {
	// ProjectRoot is the path to the project root. If empty, cwd is used.
	ProjectRoot string
}

// logToolNameInput is the stdin JSON of the PostToolUse hook.
type logToolNameInput struct {
	ToolName  string               `json:"tool_name"`
	SessionID string               `json:"session_id"`
	ToolInput logToolNameToolInput `json:"tool_input"`
}

type logToolNameToolInput struct {
	FilePath string `json:"file_path"`
	Command  string `json:"command"`
	Skill    string `json:"skill"`
}

// toolEventEntry is one line entry in tool-events.jsonl.
type toolEventEntry struct {
	V             int    `json:"v"`
	Ts            string `json:"ts"`
	SessionID     string `json:"session_id"`
	PromptSeq     int    `json:"prompt_seq"`
	HookEventName string `json:"hook_event_name"`
	ToolName      string `json:"tool_name"`
}

// sessionEventEntry is one line entry in session-events.jsonl.
type sessionEventEntry struct {
	ID    string          `json:"id"`
	Type  string          `json:"type"`
	Ts    string          `json:"ts"`
	State string          `json:"state"`
	Data  json.RawMessage `json:"data,omitempty"`
}

// sessionState is the minimal structure of session.json.
type sessionState struct {
	PromptSeq int    `json:"prompt_seq"`
	EventSeq  int    `json:"event_seq"`
	State     string `json:"state"`
	UpdatedAt string `json:"updated_at"`
	LastEvID  string `json:"last_event_id"`
}

// skillsUsedState is the structure of session-skills-used.json.
type skillsUsedState struct {
	Used         []string `json:"used"`
	SessionStart string   `json:"session_start"`
	LastUsed     string   `json:"last_used,omitempty"`
}

const (
	toolEventsFile    = "tool-events.jsonl"
	sessionEventsFile = "session-events.jsonl"
	skillsUsedFile    = "session-skills-used.json"
	logMaxSizeBytes   = 256 * 1024 // 256KB
	logMaxLines       = 2000
	logMaxGenerations = 5
	sessionEvMaxLines = 500
)

// Handle reads the PostToolUse payload from stdin and records logs.
func (h *PostToolUseLogToolNameHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	if len(data) > 0 {
		var inp logToolNameInput
		if err := json.Unmarshal(data, &inp); err == nil && inp.ToolName != "" {
			projectRoot := h.resolveProjectRoot()
			stateDir := filepath.Join(projectRoot, ".claude", "state")
			_ = os.MkdirAll(stateDir, 0700)

			promptSeq := h.readPromptSeq(stateDir)

			// LSP tracking (always runs)
			if strings.Contains(strings.ToLower(inp.ToolName), "lsp") {
				h.trackLSP(stateDir, inp.ToolName, promptSeq)
			}

			// Phase0 log collection (only when CC_HARNESS_PHASE0_LOG=1)
			if os.Getenv("CC_HARNESS_PHASE0_LOG") == "1" {
				h.appendToolEvent(stateDir, inp, promptSeq)
			}

			// Session event log (important tools only)
			if isImportantTool(inp.ToolName) {
				ts := time.Now().UTC().Format(time.RFC3339)
				dataJSON := buildEventData(inp)
				h.appendSessionEvent(stateDir, inp.ToolName, ts, dataJSON)
			}

			// Skill tracking (per session)
			if inp.ToolName == "Skill" {
				h.trackSkillUsed(stateDir, inp.ToolInput.Skill)
			}
		}
	}

	// Always return {"continue": true}
	_, err := fmt.Fprintf(w, `{"continue":true}%s`, "\n")
	return err
}

// resolveProjectRoot resolves the project root.
func (h *PostToolUseLogToolNameHandler) resolveProjectRoot() string {
	if h.ProjectRoot != "" {
		return h.ProjectRoot
	}
	wd, _ := os.Getwd()
	return wd
}

// readPromptSeq reads prompt_seq from session.json.
func (h *PostToolUseLogToolNameHandler) readPromptSeq(stateDir string) int {
	sessionFile := filepath.Join(stateDir, "session.json")
	rawData, err := os.ReadFile(sessionFile)
	if err != nil {
		return 0
	}
	var s map[string]interface{}
	if err := json.Unmarshal(rawData, &s); err != nil {
		return 0
	}
	if v, ok := s["prompt_seq"].(float64); ok {
		return int(v)
	}
	return 0
}

// trackLSP records LSP tool usage to tooling-policy.json.
func (h *PostToolUseLogToolNameHandler) trackLSP(stateDir, toolName string, promptSeq int) {
	policyFile := filepath.Join(stateDir, "tooling-policy.json")
	rawData, err := os.ReadFile(policyFile)
	if err != nil {
		return
	}

	var policy map[string]interface{}
	if err := json.Unmarshal(rawData, &policy); err != nil {
		return
	}

	lsp, ok := policy["lsp"].(map[string]interface{})
	if !ok {
		lsp = make(map[string]interface{})
	}
	lsp["last_used_prompt_seq"] = promptSeq
	lsp["last_used_tool_name"] = toolName
	lsp["used_since_last_prompt"] = true
	policy["lsp"] = lsp

	updated, err := json.MarshalIndent(policy, "", "  ")
	if err != nil {
		return
	}

	tmp := policyFile + ".tmp"
	if err := os.WriteFile(tmp, updated, 0600); err != nil {
		return
	}
	_ = os.Rename(tmp, policyFile)
}

// appendToolEvent appends a JSONL entry to tool-events.jsonl (locked with flock).
func (h *PostToolUseLogToolNameHandler) appendToolEvent(stateDir string, inp logToolNameInput, promptSeq int) {
	logFile := filepath.Join(stateDir, toolEventsFile)
	lockFile := logFile + ".lock"

	entry := toolEventEntry{
		V:             1,
		Ts:            time.Now().UTC().Format(time.RFC3339),
		SessionID:     inp.SessionID,
		PromptSeq:     promptSeq,
		HookEventName: "PostToolUse",
		ToolName:      inp.ToolName,
	}

	line, err := json.Marshal(entry)
	if err != nil {
		return
	}

	withFileLock(lockFile, func() {
		// Rotation check
		if needsRotation(logFile, logMaxSizeBytes, logMaxLines) {
			rotateLog(logFile, logMaxGenerations)
		}

		f, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			return
		}
		defer f.Close()
		_, _ = fmt.Fprintf(f, "%s\n", line)
	})
}

// appendSessionEvent appends to the session event log and updates session.json.
func (h *PostToolUseLogToolNameHandler) appendSessionEvent(stateDir, toolName, ts, dataJSON string) {
	sessionFile := filepath.Join(stateDir, "session.json")
	eventLogFile := filepath.Join(stateDir, sessionEventsFile)
	lockFile := eventLogFile + ".lock"

	if _, err := os.Stat(sessionFile); os.IsNotExist(err) {
		return
	}

	withFileLock(lockFile, func() {
		// Read session.json
		rawData, err := os.ReadFile(sessionFile)
		if err != nil {
			return
		}
		var session map[string]interface{}
		if err := json.Unmarshal(rawData, &session); err != nil {
			return
		}

		// Increment event_seq
		eventSeq := 0
		if v, ok := session["event_seq"].(float64); ok {
			eventSeq = int(v)
		}
		eventSeq++
		eventID := fmt.Sprintf("event-%06d", eventSeq)

		currentState := "executing"
		if v, ok := session["state"].(string); ok && v != "" {
			currentState = v
		}

		// Update session.json
		session["updated_at"] = ts
		session["last_event_id"] = eventID
		session["event_seq"] = eventSeq

		updated, err := json.MarshalIndent(session, "", "  ")
		if err != nil {
			return
		}
		tmp := sessionFile + ".tmp"
		if err := os.WriteFile(tmp, updated, 0600); err != nil {
			return
		}
		_ = os.Rename(tmp, sessionFile)

		// Initialize the event log file
		_ = touchFile(eventLogFile)

		// Rotation check (line count only)
		if needsRotationLines(eventLogFile, sessionEvMaxLines) {
			rotateLog(eventLogFile, logMaxGenerations)
		}

		// Build the entry
		toolType := strings.ToLower(toolName)
		var eventLine []byte
		if dataJSON != "" {
			eventLine, _ = json.Marshal(map[string]interface{}{
				"id":    eventID,
				"type":  "tool." + toolType,
				"ts":    ts,
				"state": currentState,
				"data":  json.RawMessage(dataJSON),
			})
		} else {
			eventLine, _ = json.Marshal(map[string]interface{}{
				"id":    eventID,
				"type":  "tool." + toolType,
				"ts":    ts,
				"state": currentState,
			})
		}

		f, err := os.OpenFile(eventLogFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			return
		}
		defer f.Close()
		_, _ = fmt.Fprintf(f, "%s\n", eventLine)
	})
}

// trackSkillUsed records Skill tool usage to session-skills-used.json.
func (h *PostToolUseLogToolNameHandler) trackSkillUsed(stateDir, skillName string) {
	skillsFile := filepath.Join(stateDir, skillsUsedFile)

	if skillName == "" {
		skillName = "unknown"
	}

	// Initialize if the file does not exist
	if _, err := os.Stat(skillsFile); os.IsNotExist(err) {
		initial := skillsUsedState{
			Used:         []string{},
			SessionStart: time.Now().UTC().Format(time.RFC3339),
		}
		rawData, _ := json.MarshalIndent(initial, "", "  ")
		_ = os.WriteFile(skillsFile, rawData, 0600)
	}

	rawData, err := os.ReadFile(skillsFile)
	if err != nil {
		return
	}

	var state skillsUsedState
	if err := json.Unmarshal(rawData, &state); err != nil {
		return
	}

	state.Used = append(state.Used, skillName)
	state.LastUsed = time.Now().UTC().Format(time.RFC3339)

	updated, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return
	}

	tmp := skillsFile + ".tmp"
	if err := os.WriteFile(tmp, updated, 0600); err != nil {
		return
	}
	_ = os.Rename(tmp, skillsFile)
}

// isImportantTool determines whether the tool is an important one.
func isImportantTool(toolName string) bool {
	switch toolName {
	case "Write", "Edit", "Bash", "Task", "Skill", "SlashCommand":
		return true
	}
	return false
}

// buildEventData builds the event data JSON string from the tool usage.
func buildEventData(inp logToolNameInput) string {
	if inp.ToolInput.FilePath != "" {
		fp := trimText(inp.ToolInput.FilePath, 200)
		return fmt.Sprintf(`{"file_path":%s}`, jsonString(fp))
	}
	if inp.ToolInput.Command != "" {
		cmd := trimText(inp.ToolInput.Command, 200)
		return fmt.Sprintf(`{"command":%s}`, jsonString(cmd))
	}
	return ""
}

// trimText truncates a string to at most maxLen characters (rune-wise).
func trimText(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) > maxLen {
		return string(runes[:maxLen])
	}
	return s
}

// jsonString converts a Go string into its JSON string representation.
func jsonString(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}

// needsRotation determines whether the log file needs rotation (by size and line count).
func needsRotation(path string, maxBytes, maxLines int) bool {
	fi, err := os.Stat(path)
	if err != nil {
		return false
	}
	if int(fi.Size()) >= maxBytes {
		return true
	}
	return needsRotationLines(path, maxLines)
}

// needsRotationLines determines whether the log file's line count exceeds the threshold.
func needsRotationLines(path string, maxLines int) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()

	count := 0
	buf := make([]byte, 32*1024)
	for {
		n, err := f.Read(buf)
		for i := 0; i < n; i++ {
			if buf[i] == '\n' {
				count++
				if count >= maxLines {
					return true
				}
			}
		}
		if err != nil {
			break
		}
	}
	return false
}

// rotateLog rotates the log file (.1 -> .2 -> ... -> maxGen).
func rotateLog(path string, maxGen int) {
	// Delete the oldest
	oldest := fmt.Sprintf("%s.%d", path, maxGen)
	_ = os.Remove(oldest)

	// Rename .{n-1} -> .{n}
	for i := maxGen - 1; i >= 1; i-- {
		src := fmt.Sprintf("%s.%d", path, i)
		dst := fmt.Sprintf("%s.%d", path, i+1)
		_ = os.Rename(src, dst)
	}

	// Move the current one to .1
	_ = os.Rename(path, path+".1")
	// Create a new file
	_ = touchFile(path)
}

// touchFile creates the file (leaving it as-is if it already exists).
func touchFile(path string) error {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	return f.Close()
}

// withFileLock acquires a file lock and runs fn.
// It uses the flock(2) system call and, on failure, runs without a lock (best-effort).
func withFileLock(lockFile string, fn func()) {
	f, err := os.OpenFile(lockFile, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		// If the lock file cannot be opened, run without a lock
		fn()
		return
	}
	defer f.Close()

	// Exclusive lock via flock (no timeout, blocking)
	if err := fileLock(int(f.Fd()), fileLockExclusive); err != nil {
		// On environments where flock is unavailable, run without a lock
		fn()
		return
	}
	defer func() {
		_ = fileLock(int(f.Fd()), fileLockUnlock)
	}()

	fn()
}
