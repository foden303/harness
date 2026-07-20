package hookcodec

import (
	"encoding/json"
	"fmt"

	"github.com/foden303/harness/go/pkg/hookproto"
)

// DenyOutput returns the stdout JSON bytes a deny decision expects. Exit code 2
// is the universal blocker; the JSON carries the human reason.
//
//   - claude → PreToolUse hookSpecificOutput with permissionDecision:"deny"
//     (the exact bytes the pre-91.4 Claude path emitted, via policy.PreToolToOutput).
//
// Claude is the only host; an unknown host name is an error so the caller can
// fail open deliberately rather than silently emitting the wrong shape.
func DenyOutput(host, reason string) ([]byte, error) {
	switch host {
	case HostClaude, "":
		// Claude default: byte-identical to the existing pre-tool deny path.
		out := hookproto.PreToolOutput{
			HookSpecificOutput: hookproto.PreToolHookSpecific{
				HookEventName:            "PreToolUse",
				PermissionDecision:       "deny",
				PermissionDecisionReason: reason,
			},
		}
		return json.Marshal(out)
	default:
		return nil, fmt.Errorf("hookcodec: unknown host %q (expected claude)", host)
	}
}
