package hookcodec

import (
	"testing"
)

// The canonical action under test — `git push --force` via Bash. Normalize must
// collapse the tolerated payload shapes to ToolName="Bash" with the command in
// tool_input; the resolved host is always claude.
const forceCmd = "git push --force origin main"

func TestNormalize_Claude(t *testing.T) {
	raw := []byte(`{
		"session_id":"sess-claude-1",
		"hook_event_name":"PreToolUse",
		"tool_name":"Bash",
		"tool_input":{"command":"git push --force origin main"},
		"cwd":"/repo"
	}`)
	in, host, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if host != HostClaude {
		t.Errorf("inferred host = %q, want claude", host)
	}
	if in.ToolName != "Bash" {
		t.Errorf("ToolName = %q, want Bash", in.ToolName)
	}
	if got := in.ToolInput["command"]; got != forceCmd {
		t.Errorf("command = %v, want %q", got, forceCmd)
	}
	if in.SessionID != "sess-claude-1" {
		t.Errorf("SessionID = %q, want sess-claude-1", in.SessionID)
	}
	if in.CWD != "/repo" {
		t.Errorf("CWD = %q, want /repo", in.CWD)
	}
}

func TestNormalize_ConversationIDAlias(t *testing.T) {
	// A payload that keys identity off conversation_id still populates SessionID
	// (tolerance). The resolved host is always claude.
	raw := []byte(`{
		"conversation_id":"conv-9",
		"tool_name":"Bash",
		"tool_input":{"command":"git push --force origin main"},
		"cwd":"/work"
	}`)
	in, host, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if host != HostClaude {
		t.Errorf("host = %q, want claude", host)
	}
	if in.SessionID != "conv-9" {
		t.Errorf("SessionID = %q, want conv-9 (from conversation_id)", in.SessionID)
	}
	if in.ToolName != "Bash" || in.ToolInput["command"] != forceCmd {
		t.Errorf("normalized tool = %q/%v, want Bash/%q", in.ToolName, in.ToolInput["command"], forceCmd)
	}
}

func TestNormalize_ShellPreToolUse(t *testing.T) {
	// A payload with a structured "Shell" tool_input. Normalize maps the "Shell"
	// tool name to the canonical "Bash" so the policy kernel (R06/R11) can match.
	raw := []byte(`{
		"session_id":"sess-1",
		"tool_name":"Shell",
		"tool_input":{"command":"git push --force origin main","working_directory":"/proj"},
		"cwd":"/proj"
	}`)
	in, host, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if host != HostClaude {
		t.Errorf("host = %q, want claude", host)
	}
	if in.ToolName != "Bash" {
		t.Errorf("ToolName = %q, want Bash (mapped from Shell)", in.ToolName)
	}
	if got := in.ToolInput["command"]; got != forceCmd {
		t.Errorf("command = %v, want %q", got, forceCmd)
	}
	if in.CWD != "/proj" {
		t.Errorf("CWD = %q, want /proj", in.CWD)
	}
}

func TestNormalize_TopLevelCommandShorthand(t *testing.T) {
	// A top-level command shorthand with no tool_name synthesizes ToolName="Bash".
	// cwd present wins over workspace_roots, but workspace_roots[0] is the fallback.
	raw := []byte(`{
		"session_id":"sess-1",
		"command":"git push --force origin main",
		"cwd":"/proj",
		"sandbox":false,
		"workspace_roots":["/proj","/other"]
	}`)
	in, host, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if host != HostClaude {
		t.Errorf("inferred host = %q, want claude", host)
	}
	if in.ToolName != "Bash" {
		t.Errorf("ToolName = %q, want Bash (synthesized from top-level command)", in.ToolName)
	}
	if got := in.ToolInput["command"]; got != forceCmd {
		t.Errorf("command = %v, want %q", got, forceCmd)
	}
	if in.CWD != "/proj" {
		t.Errorf("CWD = %q, want /proj", in.CWD)
	}
}

func TestNormalize_ShellToolNameMapsToBash(t *testing.T) {
	// A payload with tool_name "Shell" + tool_input.command (plus arbitrary
	// metadata fields that must be ignored). Without the Shell-to-Bash mapping
	// this shape would slip past the policy kernel (fail-open), because only the
	// top-level-command shorthand was normalized to "Bash".
	raw := []byte(`{
		"session_id":"73236a11-4816-44ed-95fb-deb1fb666d5c",
		"model":"composer-2.5",
		"tool_name":"Shell",
		"tool_input":{"command":"git push --force origin main"},
		"workspace_roots":["/proj"]
	}`)
	in, host, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if host != HostClaude {
		t.Errorf("host = %q, want claude", host)
	}
	if in.ToolName != "Bash" {
		t.Errorf("ToolName = %q, want Bash (mapped from Shell payload)", in.ToolName)
	}
	if got := in.ToolInput["command"]; got != forceCmd {
		t.Errorf("command = %v, want %q", got, forceCmd)
	}
}

func TestNormalize_WorkspaceRootsFallback(t *testing.T) {
	// No cwd → first workspace_roots entry becomes CWD.
	raw := []byte(`{
		"session_id":"sess-1",
		"command":"git push --force origin main",
		"workspace_roots":["/first","/second"]
	}`)
	in, host, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if host != HostClaude {
		t.Errorf("host = %q, want claude", host)
	}
	if in.CWD != "/first" {
		t.Errorf("CWD = %q, want /first (workspace_roots[0])", in.CWD)
	}
	if in.PluginRoot != "/first" {
		t.Errorf("PluginRoot = %q, want /first (cwd fallback)", in.PluginRoot)
	}
}

func TestNormalize_FilePathShorthand(t *testing.T) {
	// A top-level file_path with an explicit tool_name (e.g. Write) becomes
	// tool_input.file_path.
	raw := []byte(`{
		"session_id":"s1",
		"tool_name":"Write",
		"file_path":"/repo/.claude-plugin/settings.json"
	}`)
	in, _, err := Normalize(raw, "claude")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if got := in.ToolInput["file_path"]; got != "/repo/.claude-plugin/settings.json" {
		t.Errorf("file_path = %v, want the settings path", got)
	}
}

func TestNormalize_PathAlias(t *testing.T) {
	raw := []byte(`{"session_id":"s1","tool_name":"Read","path":"/etc/hosts"}`)
	in, _, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if got := in.ToolInput["file_path"]; got != "/etc/hosts" {
		t.Errorf("file_path = %v, want /etc/hosts (from path alias)", got)
	}
}

func TestNormalize_ToolInputPreservedOverShorthand(t *testing.T) {
	// When both a structured tool_input.command and a top-level command are
	// present, the explicit tool_input value is NOT overwritten.
	raw := []byte(`{
		"session_id":"s1",
		"tool_name":"Bash",
		"tool_input":{"command":"structured"},
		"command":"shorthand"
	}`)
	in, _, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if got := in.ToolInput["command"]; got != "structured" {
		t.Errorf("command = %v, want structured (tool_input must win)", got)
	}
}

func TestNormalize_EmptyInput(t *testing.T) {
	if _, _, err := Normalize(nil, ""); err == nil {
		t.Fatal("expected error for nil input")
	}
	if _, _, err := Normalize([]byte("   \n\t"), ""); err == nil {
		t.Fatal("expected error for whitespace-only input")
	}
}

func TestNormalize_InvalidJSON(t *testing.T) {
	if _, _, err := Normalize([]byte("{not json"), ""); err == nil {
		t.Fatal("expected error for invalid JSON")
	}
}

func TestNormalize_MissingToolName(t *testing.T) {
	// A payload with neither a tool_name nor a command has no usable action.
	raw := []byte(`{"session_id":"s1","cwd":"/x"}`)
	_, _, err := Normalize(raw, "")
	if err == nil {
		t.Fatal("expected error when no tool action is present")
	}
}

func TestNormalize_ToolInputNeverNil(t *testing.T) {
	raw := []byte(`{"session_id":"s1","tool_name":"Read"}`)
	in, _, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if in.ToolInput == nil {
		t.Error("ToolInput must be a non-nil map")
	}
}

func TestNormalize_ToolNameCamelAlias(t *testing.T) {
	raw := []byte(`{"session_id":"s1","toolName":"Bash","tool_input":{"command":"ls"}}`)
	in, _, err := Normalize(raw, "")
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if in.ToolName != "Bash" {
		t.Errorf("ToolName = %q, want Bash (from toolName alias)", in.ToolName)
	}
}
