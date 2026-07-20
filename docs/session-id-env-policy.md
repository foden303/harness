# Session ID Env Policy (Phase 62.2.4)

> **Status**: Active (2026-05-07)
> **Background**: In Claude Code `2.1.132`, `CLAUDE_CODE_SESSION_ID` is now passed to Bash
> subprocesses as an env var. Organize the paths for obtaining the session ID in Harness's
> hook handlers / shell wrappers / CLI helpers to prevent confusion.

## In One Line

There are **4** paths to obtain the session ID; use each for its own purpose.
For hook handlers, the correct source is **stdin JSON (`.session_id`)** — do not depend on the env var.
Use the env var (`CLAUDE_CODE_SESSION_ID`) only when you need to read the session ID from a Bash subprocess.

## As an Analogy

It is like not mixing up your "house key" and your "car key."
A hook handler gets the key handed directly by CC (stdin), so use that.
A Bash subprocess (a subshell launched with rg / jq / curl) is not called directly by CC,
so it has to take it from the "key holder" (env var).

## The 4 Paths

| # | Path | Source | Use |
|---|------|--------|-----|
| 1 | stdin JSON `.session_id` | hook input | **primary path for hook handlers** |
| 2 | `CLAUDE_CODE_SESSION_ID` env var | OS env | Bash subprocess, CLI helper |
| 3 | `.session_id` in `.claude/state/session.json` | local state | long-lived watchers such as session-monitor / session-broadcast |
| 4 | regex extract from `CLAUDE_TRANSCRIPT_PATH` | env var (regex) | **do not use (legacy)** |

## When to Use Which

### (1) Inside a hook handler → stdin JSON

```bash
SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // ""')"
```

Reason: hook handlers receive JSON input from CC. The stdin JSON is the SSOT.

Relying on the env var risks incorrectly inheriting the parent session's env when running
multiple sessions in parallel (because Bash subprocesses inherit the parent env).

### (2) Bash subprocess → `CLAUDE_CODE_SESSION_ID` env var (CC 2.1.132+)

```bash
# Example: when a session ID is needed inside a jq subprocess launched from a hook handler
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [ -z "${SESSION_ID}" ]; then
  echo "[warn] CLAUDE_CODE_SESSION_ID not set; running on CC 2.1.131 or older" >&2
  SESSION_ID="unknown"
fi
```

Reason: a Bash subprocess does not receive stdin directly from CC, so the env is the only path.
On CC `2.1.131` or older there is no env var, so an `unknown` fallback is needed.

### (3) Long-running watcher → `.claude/state/session.json`

```bash
SESSION_ID="$(jq -r '.session_id // "unknown"' "${PROJECT_ROOT}/.claude/state/session.json")"
```

Reason: session-monitor / session-broadcast and similar keep running after the session starts,
so the state file is the SSOT. They cannot read env / stdin.

### (4) regex extract from `CLAUDE_TRANSCRIPT_PATH` → do not use

Past example: `echo "$CLAUDE_TRANSCRIPT_PATH" | sed 's|.*/\([a-f0-9-]*\)\.json|\1|'`

Problems:
- The transcript path format may change across CC versions
- The fallback when the regex breaks is complex
- The `CLAUDE_CODE_SESSION_ID` env var is directly available (CC 2.1.132+)

**Not used in current Harness.** Do not adopt it in new implementations either.

## 3-State Test Naming Convention (per `.claude/rules/active-watching-test-policy.md`)

Test scripts that handle session ID retrieval cover all of the following states.

| State | Name | Expected behavior |
|-------|------|-------------------|
| Healthy | `TestSessionIdEnv_Healthy` | env var present → use it as-is |
| NotConfigured | `TestSessionIdEnv_NotConfigured` | no env → fall back to state file, do not warn |
| Corrupted | `TestSessionIdEnv_Corrupted` | neither env nor state → `unknown` fallback, emit a warning |

## Related Docs

- `.claude/rules/active-watching-test-policy.md` — 3-state test convention
- `docs/long-running-harness.md` — env inheritance in long-running sessions
- Claude Code 2.1.132 CHANGELOG: Added `CLAUDE_CODE_SESSION_ID` environment variable to Bash tool subprocess environment

## Acceptance Criteria (Phase 62.2.4 DoD)

- [x] The usage of the 4 paths is documented
- [x] It is stated that hook handlers use the stdin JSON path (not dependent on env)
- [x] The fallback for CC 2.1.131 or older is shown
- [x] Consistent with the 3-state test convention (`.claude/rules/active-watching-test-policy.md`)
- [x] It is stated that regex extract from `CLAUDE_TRANSCRIPT_PATH` is not used
