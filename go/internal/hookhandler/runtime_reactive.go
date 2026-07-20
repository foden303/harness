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

// reactiveInput is the stdin JSON payload passed to runtime-reactive.sh.
type reactiveInput struct {
	HookEventName string `json:"hook_event_name"`
	EventName     string `json:"event_name"`
	SessionID     string `json:"session_id"`
	CWD           string `json:"cwd"`
	ProjectRoot   string `json:"project_root"`
	FilePath      string `json:"file_path"`
	Path          string `json:"path"`
	PreviousCWD   string `json:"previous_cwd"`
	FromCWD       string `json:"from_cwd"`
	TaskID        string `json:"task_id"`
	TaskTitle     string `json:"task_title"`
	Description   string `json:"description"`
	Task          *struct {
		ID          string `json:"id"`
		Title       string `json:"title"`
		Description string `json:"description"`
	} `json:"task"`
}

// reactiveLogEntry is an entry recorded in runtime-reactive.jsonl.
type reactiveLogEntry struct {
	Event       string `json:"event"`
	Timestamp   string `json:"timestamp"`
	SessionID   string `json:"session_id"`
	CWD         string `json:"cwd"`
	FilePath    string `json:"file_path"`
	PreviousCWD string `json:"previous_cwd"`
	TaskID      string `json:"task_id"`
	TaskTitle   string `json:"task_title"`
}

// reactiveHookOutput is a response in hookSpecificOutput format.
type reactiveHookOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// reactiveApproveOutput is a response in approve format.
type reactiveApproveOutput struct {
	Decision string `json:"decision"`
	Reason   string `json:"reason"`
}

// HandleRuntimeReactive is the Go port of runtime-reactive.sh.
//
// It handles the three events TaskCreated / FileChanged / CwdChanged in a unified way:
//   - TaskCreated: log background task creation
//   - FileChanged: detect changes to Plans.md, AGENTS.md, .claude/rules/, hooks.json, settings.json → instruct re-read via systemMessage
//   - CwdChanged: directory change → prompt context re-verification
func HandleRuntimeReactive(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		return writeReactiveApprove(out, "Reactive hook: no payload")
	}

	var input reactiveInput
	if err := json.Unmarshal(data, &input); err != nil {
		return writeReactiveApprove(out, "Reactive hook: no payload")
	}

	// Get hook_event_name or event_name
	eventName := input.HookEventName
	if eventName == "" {
		eventName = input.EventName
	}

	// Determine project_root
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot = input.ProjectRoot
	}
	if projectRoot == "" {
		if cwd, err := os.Getwd(); err == nil {
			projectRoot = cwd
		}
	}

	// Get the file path and normalize it
	filePath := input.FilePath
	if filePath == "" {
		filePath = input.Path
	}
	filePath = normalizeReactivePath(filePath, projectRoot)

	// Normalize previous_cwd
	previousCWD := input.PreviousCWD
	if previousCWD == "" {
		previousCWD = input.FromCWD
	}
	previousCWD = normalizeReactivePath(previousCWD, projectRoot)

	// Get task_id and task_title
	taskID := input.TaskID
	taskTitle := input.TaskTitle
	if input.Task != nil {
		if taskID == "" {
			taskID = input.Task.ID
		}
		if taskTitle == "" {
			taskTitle = input.Task.Title
			if taskTitle == "" {
				taskTitle = input.Task.Description
			}
		}
	}
	if taskTitle == "" {
		taskTitle = input.Description
	}

	// session_id
	sessionID := input.SessionID

	// State directory and log file
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	logFile := filepath.Join(stateDir, "runtime-reactive.jsonl")
	_ = os.MkdirAll(stateDir, 0o755)

	timestamp := time.Now().UTC().Format(time.RFC3339)

	// Record the log entry
	logEntry := reactiveLogEntry{
		Event:       eventName,
		Timestamp:   timestamp,
		SessionID:   sessionID,
		CWD:         projectRoot,
		FilePath:    filePath,
		PreviousCWD: previousCWD,
		TaskID:      taskID,
		TaskTitle:   taskTitle,
	}
	if logData, err := json.Marshal(logEntry); err == nil {
		appendToJSONL(logFile, logData)
	}

	// Generate a per-event message
	message := buildReactiveMessage(eventName, filePath, resolveHarnessLocale(projectRoot))

	if message != "" {
		return writeReactiveHookOutput(out, eventName, message)
	}
	return writeReactiveApprove(out, fmt.Sprintf("Reactive hook tracked: %s", eventName))
}

// buildReactiveMessage generates a message based on the event and the changed path.
// Corresponds to the case statement in runtime-reactive.sh.
func buildReactiveMessage(eventName, filePath, locale string) string {
	switch eventName {
	case "FileChanged":
		return buildFileChangedMessage(filePath, locale)
	case "CwdChanged":
		return "The working directory changed. If you moved to another repository or worktree, re-read AGENTS.md, Plans.md, and local rules before continuing."
	case "TaskCreated":
		// TaskCreated logs only (no message)
		return ""
	}
	return ""
}

// buildFileChangedMessage generates the message for the FileChanged event.
func buildFileChangedMessage(filePath, locale string) string {
	// Plans.md change
	if filePath == "Plans.md" || strings.HasSuffix(filePath, "/Plans.md") {
		return "Plans.md was updated. Re-read the latest task status before the next implementation or review step."
	}

	// Changes to AGENTS.md, CLAUDE.md, .claude/rules/, hooks.json, settings.json
	if isRuleOrConfigFile(filePath) {
		return "Working rules or Harness settings were updated. Use the latest rules for the next operation."
	}

	return ""
}

// isRuleOrConfigFile determines whether the file path is a rule/config file.
// Corresponds to the case pattern in runtime-reactive.sh:
// AGENTS.md, CLAUDE.md, .claude/rules/*, hooks/hooks.json, .claude-plugin/settings.json
func isRuleOrConfigFile(filePath string) bool {
	// AGENTS.md
	if filePath == "AGENTS.md" || strings.HasSuffix(filePath, "/AGENTS.md") {
		return true
	}
	// CLAUDE.md
	if filePath == "CLAUDE.md" || strings.HasSuffix(filePath, "/CLAUDE.md") {
		return true
	}
	// Under the .claude/rules/ directory
	if strings.HasPrefix(filePath, ".claude/rules/") || strings.Contains(filePath, "/.claude/rules/") {
		return true
	}
	// hooks/hooks.json
	if filePath == "hooks/hooks.json" || strings.HasSuffix(filePath, "/hooks/hooks.json") {
		return true
	}
	// .claude-plugin/settings.json
	if filePath == ".claude-plugin/settings.json" || strings.HasSuffix(filePath, "/.claude-plugin/settings.json") {
		return true
	}
	return false
}

// normalizeReactivePath normalizes the path to a relative path from the project root.
// Corresponds to the normalize_for_match() function in runtime-reactive.sh.
func normalizeReactivePath(rawPath, projectRoot string) string {
	if rawPath == "" {
		return ""
	}

	// Resolve symbolic links (when possible)
	if resolved, err := filepath.EvalSymlinks(rawPath); err == nil {
		rawPath = resolved
	}

	if projectRoot != "" {
		// Resolve symbolic links (when possible)
		normalizedRoot := projectRoot
		if resolved, err := filepath.EvalSymlinks(projectRoot); err == nil {
			normalizedRoot = resolved
		}

		// Make relative to the project root
		if rawPath == normalizedRoot {
			rawPath = "."
		} else if strings.HasPrefix(rawPath, normalizedRoot+"/") {
			rawPath = rawPath[len(normalizedRoot)+1:]
		}
	}

	// Remove the ./ prefix
	rawPath = strings.TrimPrefix(rawPath, "./")
	return rawPath
}

// appendToJSONL appends an entry to a JSONL file.
func appendToJSONL(path string, data []byte) {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.Write(append(data, '\n'))
}

// writeReactiveHookOutput writes a response in hookSpecificOutput format.
func writeReactiveHookOutput(out io.Writer, eventName, message string) error {
	var resp reactiveHookOutput
	resp.HookSpecificOutput.HookEventName = eventName
	resp.HookSpecificOutput.AdditionalContext = message
	return writeJSON(out, resp)
}

// writeReactiveApprove writes a response in approve format.
func writeReactiveApprove(out io.Writer, reason string) error {
	resp := reactiveApproveOutput{
		Decision: "approve",
		Reason:   reason,
	}
	return writeJSON(out, resp)
}
