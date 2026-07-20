package main

import (
	"encoding/json"
	"testing"

	"github.com/foden303/harness/go/internal/guardrail"
	"github.com/foden303/harness/go/internal/hookcodec"
	"github.com/foden303/harness/go/internal/policy"
	"github.com/foden303/harness/go/pkg/hookproto"
)

// TestHookCodecSmoke_ForcePushDenied is the Phase 91.4 DoD (d) smoke test: a
// `git push --force origin main` action, expressed in the tolerated stdin
// shapes, must — after the codec → guardrail.EvaluatePreTool →
// policy.FormatPreToolResult pipeline — produce a DENY decision, exit code 2,
// and a valid Claude deny JSON.
//
// It drives the functions directly — no os.Exit, no subprocess — so the policy
// engine (UNCHANGED) is exercised through the normalization layer.
func TestHookCodecSmoke_ForcePushDenied(t *testing.T) {
	cases := []struct {
		name     string
		hostHint string
		wantHost string
		stdin    string
	}{
		{
			name:     "claude",
			hostHint: "", // Claude default: no --host
			wantHost: hookcodec.HostClaude,
			stdin: `{
				"session_id":"sess-claude",
				"hook_event_name":"PreToolUse",
				"tool_name":"Bash",
				"tool_input":{"command":"git push --force origin main"},
				"cwd":"/repo"
			}`,
		},
		{
			// Shell tool_name variant: tool_name "Shell" + structured tool_input,
			// no top-level command shorthand. Mapped to Bash; resolves claude.
			name:     "shell-variant",
			hostHint: "",
			wantHost: hookcodec.HostClaude,
			stdin: `{
				"session_id":"sess-shell-live",
				"model":"composer-2.5",
				"tool_name":"Shell",
				"tool_input":{"command":"git push --force origin main"},
				"workspace_roots":["/proj"]
			}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			// 1. Normalize the host-native stdin into the canonical input.
			in, host, err := hookcodec.Normalize([]byte(tc.stdin), tc.hostHint)
			if err != nil {
				t.Fatalf("Normalize(%s): %v", tc.name, err)
			}
			if host != tc.wantHost {
				t.Errorf("resolved host = %q, want %q", host, tc.wantHost)
			}
			if in.ToolName != "Bash" {
				t.Errorf("ToolName = %q, want Bash", in.ToolName)
			}
			if in.ToolInput["command"] != "git push --force origin main" {
				t.Errorf("command = %v, want the force-push command", in.ToolInput["command"])
			}

			// 2. The UNCHANGED policy engine adjudicates.
			result := guardrail.EvaluatePreTool(in)
			if result.Decision != hookproto.DecisionDeny {
				t.Fatalf("decision = %q, want deny (R06 force-push block)", result.Decision)
			}

			// 3. Exit code must be the universal hard-block 2.
			_, exitCode := policy.FormatPreToolResult(result)
			if exitCode != 2 {
				t.Errorf("exit code = %d, want 2", exitCode)
			}

			// 4. The host's deny output must be valid JSON.
			denyJSON, err := hookcodec.DenyOutput(host, result.Reason)
			if err != nil {
				t.Fatalf("DenyOutput(%s): %v", host, err)
			}
			var any map[string]interface{}
			if err := json.Unmarshal(denyJSON, &any); err != nil {
				t.Errorf("deny output for %s is not valid JSON: %v\n%s", host, err, denyJSON)
			}

			// 5. Per-host deny shape sanity.
			assertDenyShape(t, host, denyJSON, result.Reason)
		})
	}
}

// TestHookCodecSmoke_ClaudeDenyByteParity guards the no-flag (Claude default)
// contract: hookcodec.DenyOutput("claude", reason) must be byte-for-byte
// identical to the legacy pre-91.4 deny output, which was
// json.Marshal(policy.PreToolToOutput(deny)). This is the DoD requirement that
// `harness hook pre-tool` with no --host stays behavior-compatible with today.
func TestHookCodecSmoke_ClaudeDenyByteParity(t *testing.T) {
	reason := "git push --force is not allowed. History-destroying operations are forbidden."

	legacyOut := policy.PreToolToOutput(hookproto.HookResult{
		Decision: hookproto.DecisionDeny,
		Reason:   reason,
	})
	legacyBytes, err := json.Marshal(legacyOut)
	if err != nil {
		t.Fatalf("marshal legacy output: %v", err)
	}

	newBytes, err := hookcodec.DenyOutput(hookcodec.HostClaude, reason)
	if err != nil {
		t.Fatalf("DenyOutput(claude): %v", err)
	}

	if string(legacyBytes) != string(newBytes) {
		t.Errorf("Claude deny output drifted from legacy bytes\n legacy: %s\n new:    %s", legacyBytes, newBytes)
	}
	// Empty host must also equal the Claude default.
	emptyBytes, err := hookcodec.DenyOutput("", reason)
	if err != nil {
		t.Fatalf("DenyOutput(\"\"): %v", err)
	}
	if string(emptyBytes) != string(legacyBytes) {
		t.Errorf("empty-host deny output != legacy bytes\n empty:  %s\n legacy: %s", emptyBytes, legacyBytes)
	}
}

// assertDenyShape checks the host-specific deny envelope fields.
func assertDenyShape(t *testing.T, host string, denyJSON []byte, reason string) {
	t.Helper()
	switch host {
	case hookcodec.HostClaude:
		var got struct {
			HookSpecificOutput struct {
				HookEventName            string `json:"hookEventName"`
				PermissionDecision       string `json:"permissionDecision"`
				PermissionDecisionReason string `json:"permissionDecisionReason"`
			} `json:"hookSpecificOutput"`
		}
		if err := json.Unmarshal(denyJSON, &got); err != nil {
			t.Fatalf("%s deny shape unmarshal: %v", host, err)
		}
		if got.HookSpecificOutput.PermissionDecision != "deny" {
			t.Errorf("%s permissionDecision = %q, want deny", host, got.HookSpecificOutput.PermissionDecision)
		}
		if got.HookSpecificOutput.HookEventName != "PreToolUse" {
			t.Errorf("%s hookEventName = %q, want PreToolUse", host, got.HookSpecificOutput.HookEventName)
		}
		if got.HookSpecificOutput.PermissionDecisionReason != reason {
			t.Errorf("%s reason mismatch: %q", host, got.HookSpecificOutput.PermissionDecisionReason)
		}
	default:
		t.Fatalf("unexpected host %q", host)
	}
}
