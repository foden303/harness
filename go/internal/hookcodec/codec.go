// Package hookcodec normalizes the pre-tool stdin JSON that Claude sends into
// the canonical hookproto.HookInput, and renders the expected deny output. This
// lets the R01-R13 policy engine (go/internal/policy) adjudicate without the
// kernel knowing which host it is serving.
//
// Claude is the only host: session_id / tool_name / tool_input / cwd
// (== hookproto.HookInput). Normalize still tolerates a few field-name aliases
// so a slightly different payload shape does not fail open.
//
// The package depends only on the standard library and pkg/hookproto, so it
// stays composable with the pure guardrail kernel.
package hookcodec

import (
	"encoding/json"
	"fmt"

	"github.com/foden303/harness/go/pkg/hookproto"
)

// HostClaude is the only host identifier returned by Normalize and accepted by
// DenyOutput.
const HostClaude = "claude"

// rawPayload is a permissive view over a host's pre-tool stdin JSON. Every host
// field this codec cares about is declared with all known aliases so a single
// json.Unmarshal captures them regardless of which host produced the payload.
// Unknown fields are ignored (hosts add their own metadata we don't need).
type rawPayload struct {
	// session / conversation identity
	SessionID       string `json:"session_id"`
	ConversationID  string `json:"conversation_id"`
	ConversationID2 string `json:"conversationId"`

	// tool identity
	ToolName  string                 `json:"tool_name"`
	ToolName2 string                 `json:"toolName"`
	ToolInput map[string]interface{} `json:"tool_input"`

	// shell-event shorthands (top-level command)
	Command string `json:"command"`

	// file-edit shorthands
	FilePath string `json:"file_path"`
	Path     string `json:"path"`

	// working directory
	CWD            string   `json:"cwd"`
	WorkspaceRoot  string   `json:"workspace_root"`
	WorkspaceRoots []string `json:"workspace_roots"`

	// event name
	HookEventName string `json:"hook_event_name"`

	// harness extension
	PluginRoot string `json:"plugin_root"`
}

// Normalize parses Claude's raw pre-tool stdin JSON into the canonical
// hookproto.HookInput, tolerating a few field-name aliases. hostHint is accepted
// for call-site compatibility but ignored: the resolved host is always claude.
//
// It returns the normalized input, the resolved host name (always "claude"), and
// an error. The error is non-nil only when the payload is empty/invalid JSON or
// carries no usable tool action (so callers can fail open exactly like
// hook.ReadInput).
func Normalize(raw []byte, hostHint string) (hookproto.HookInput, string, error) {
	_ = hostHint // Claude is the only host.
	if len(raw) == 0 {
		return hookproto.HookInput{}, "", fmt.Errorf("empty input")
	}
	// Reject whitespace-only payloads the same way hook.ReadInput does.
	if isBlank(raw) {
		return hookproto.HookInput{}, "", fmt.Errorf("empty input")
	}

	var p rawPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return hookproto.HookInput{}, "", fmt.Errorf("parsing JSON: %w", err)
	}

	host := HostClaude

	input := hookproto.HookInput{
		SessionID:     firstNonEmpty(p.SessionID, p.ConversationID, p.ConversationID2),
		CWD:           firstNonEmpty(p.CWD, p.WorkspaceRoot, firstSlice(p.WorkspaceRoots)),
		HookEventName: p.HookEventName,
	}

	// PluginRoot keeps existing behavior: explicit plugin_root wins, else fall
	// back to the resolved cwd (matches the pre-91.4 Claude path where callers
	// derived the project root from cwd).
	input.PluginRoot = firstNonEmpty(p.PluginRoot, input.CWD)

	// ToolName: explicit field (either alias) wins; otherwise a shell-shaped
	// event (a top-level command) is a Bash action.
	input.ToolName = firstNonEmpty(p.ToolName, p.ToolName2)
	if input.ToolName == "" && p.Command != "" {
		input.ToolName = "Bash"
	}
	// Some hosts name their shell tool "Shell". The policy kernel only knows
	// the canonical "Bash" name, so an unmapped "Shell" would slip past
	// R06/R11. No host uses "Shell" for anything else, so the mapping is
	// unconditional.
	if input.ToolName == "Shell" {
		input.ToolName = "Bash"
	}

	// ToolInput: prefer the explicit map; otherwise synthesize one from the
	// shell/file shorthands so the policy engine (which reads tool_input
	// ["command"] / ["file_path"]) sees a uniform structure.
	input.ToolInput = resolveToolInput(p)

	if input.ToolName == "" {
		return hookproto.HookInput{}, host, fmt.Errorf("missing required field 'tool_name'")
	}

	return input, host, nil
}

// resolveToolInput builds the canonical tool_input map. An explicit tool_input
// map is used as-is, but a top-level command/file_path is still merged in when
// the map omits it (some hosts send both the structured map and the shorthand;
// the shorthand only fills gaps so an explicit tool_input value is never
// overwritten). When no structured map is present, the shorthands become the
// map. The result is never nil.
func resolveToolInput(p rawPayload) map[string]interface{} {
	out := map[string]interface{}{}
	for k, v := range p.ToolInput {
		out[k] = v
	}
	if _, ok := out["command"]; !ok && p.Command != "" {
		out["command"] = p.Command
	}
	if _, ok := out["file_path"]; !ok {
		if fp := firstNonEmpty(p.FilePath, p.Path); fp != "" {
			out["file_path"] = fp
		}
	}
	return out
}

// firstNonEmpty returns the first non-empty string argument, or "".
func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

// firstSlice returns the first element of a string slice, or "".
func firstSlice(s []string) string {
	if len(s) > 0 {
		return s[0]
	}
	return ""
}

// isBlank reports whether raw is empty or contains only ASCII whitespace.
func isBlank(raw []byte) bool {
	for _, b := range raw {
		switch b {
		case ' ', '\t', '\n', '\r', '\v', '\f':
			continue
		default:
			return false
		}
	}
	return true
}
