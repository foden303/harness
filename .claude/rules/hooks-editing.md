---
description: Rules for editing hook configuration (hooks.json)
paths: "**/hooks.json"
---

# Hooks Editing Rules

Rules applied when editing `hooks.json` files.

## Important: Dual hooks.json Sync (Required)

**Two hooks.json files exist and must always be in sync:**

```
hooks/hooks.json           ← Source file (for development)
.claude-plugin/hooks.json  ← For plugin distribution (sync required)
```

### Editing Flow

1. Edit `hooks/hooks.json`
2. Apply the same changes to `.claude-plugin/hooks.json`
3. Sync cache with `./scripts/sync-plugin-cache.sh`

```bash
# Always run after changes
./scripts/sync-plugin-cache.sh
```

## Hook Types

4 types are available: `command` (general purpose), `http` (external integration), `prompt` (single LLM decision), and `agent` (LLM agent decision). The latter two support all events as of v2.1.63+.

> **CC v2.1.69+**: The `InstructionsLoaded` event, the `agent_id` / `agent_type` fields, and the `{"continue": false, "stopReason": "..."}` response were added.
>
> **CC v2.1.76+**: The `Elicitation`, `ElicitationResult`, and `PostCompact` events were added.
> Because MCP Elicitation cannot do UI interaction in a background agent, automatic handling via a hook is required.
> PostCompact pairs with PreCompact and is used for context re-injection after compaction.
>
> **CC v2.1.77+**: Even if a PreToolUse hook returns `"allow"`, the `deny` rules in settings.json now take precedence.
> Even if a hook allows, a deny setting rejects the action. Be mindful of this precedence when designing guardrails.
>
> **CC v2.1.78+**: The `StopFailure` event was added. It fires when session stop fails due to an API error
> (rate limit, authentication failure, etc.). Used for error logging and recovery processing.
>
> **CC v2.1.89+**: The `PermissionDenied` event was added. It fires when the auto mode classifier rejects a command.
> Returning `{retry: true}` tells the model that a retry is possible. Used for tracking Breezing Worker denials.
>
> **CC v2.1.89+**: `"defer"` was added to the `permissionDecision` of the PreToolUse hook.
> In a headless session (`-p` mode), if the hook returns `"defer"` the session pauses, and
> the hook is re-evaluated when resumed with `claude -p --resume`. It can serve as a safety valve when a Breezing Worker encounters an operation that is hard to judge.
>
> **CC v2.1.89+**: Combining PreToolUse's `updatedInput` with `AskUserQuestion`,
> a headless session can collect the question in an external UI and inject the answer together with `permissionDecision: "allow"`.
>
> **CC v2.1.89+**: If hook output exceeds 50K characters, it is saved to disk and injected into context as a file path plus preview.
> Assume this behavior when designing a hook that returns large output.
>
> **CC v2.1.90+**: The blocking behavior when a PreToolUse hook prints JSON to stdout and exits with exit code 2 was fixed.
> Previously there was a bug where blocking did not work correctly with this pattern. Because Harness's pre-tool.sh uses the exit 2 pattern,
> guardrail deny works more reliably from v2.1.90 onward.

### command Type (General Purpose)

Available for all events:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" script-name",
  "timeout": 30
}
```

### prompt Type

**Official Support**: Available for all hook events (v2.1.63+)

```json
{
  "type": "prompt",
  "prompt": "Evaluation instructions...\n\n[IMPORTANT] Always respond in this JSON format:\n{\"ok\": true} or {\"ok\": false, \"reason\": \"reason\"}",
  "timeout": 30
}
```

**Response Schema (Required)**:
```json
{"ok": true}                          // Allow action
{"ok": false, "reason": "explanation"}  // Block action
```

⚠️ **Note**: If you don't explicitly instruct JSON format in the prompt, the LLM may return natural language and cause a `JSON validation failed` error

### agent Type (v2.1.63+)

A new hook form that delegates the hook decision to an LLM agent. It can analyze code using the Read, Grep, and Glob tools to decide allow/deny.

```json
{
  "type": "agent",
  "prompt": "Check if the code change introduces security vulnerabilities. $ARGUMENTS",
  "model": "haiku",
  "timeout": 60
}
```

#### agent hook-specific fields

| Field | Required | Description |
|-----------|------|------|
| `prompt` | Yes | The prompt sent to the agent. Reference the hook input JSON via `$ARGUMENTS` |
| `model` | No | The model to use (default: fast model). `haiku` recommended for cost management |

#### Main differences from a command hook

| Item | command hook | agent hook |
|------|-------------|-----------|
| Decision method | rule-based (regex / conditionals) | LLM understands context and decides |
| Tools | shell commands | Read, Grep, Glob (no side effects) |
| Cost | low (process launch only) | high (LLM inference token consumption) |
| Use case | deterministic rules | context-dependent quality judgment |
| Async | supports `async: true` | not supported |

#### Cost management guidelines

- Narrow the target to the minimum with matcher (e.g. `Write|Edit` only)
- Suppress cost with `model: "haiku"`
- Recommended per-call token cap: 2,000
- When monthly cost is exceeded, consider rolling back to the command type

### http Type (v2.1.63+)

A new hook form that POSTs JSON to a URL. Used for integration with external services.

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "timeout": 30,
  "headers": {
    "Authorization": "Bearer $MY_TOKEN"
  },
  "allowedEnvVars": ["MY_TOKEN"]
}
```

#### HTTP hook-specific fields

| Field | Required | Description |
|-----------|------|------|
| `url` | Yes | The POST target URL |
| `headers` | No | Additional HTTP headers. Environment variables can be expanded via `$VAR` / `${VAR}` |
| `allowedEnvVars` | No | List of environment variable names allowed to expand in `headers`. Not expanded if unspecified |

#### Response specification

| Response | Behavior |
|-----------|------|
| `2xx` + empty body | success, continue |
| `2xx` + JSON body | success; the JSON is parsed with the same schema as a command hook |
| `non-2xx` / timeout | non-blocking error, continue execution |

#### Main differences from a command hook

| Item | command hook | http hook |
|------|-------------|-----------|
| Input | stdin (JSON) | POST body (JSON) |
| Success criterion | exit code 0 | 2xx status |
| Blocking | exit 2 | 2xx + JSON with `permissionDecision: "deny"` |
| Async execution | supports `async: true` | not supported |
| `/hooks` menu | can be added | not possible (direct JSON edit only) |
| Environment variables | auto-expanded in the shell environment | requires an explicit list in `allowedEnvVars` |

#### Sample templates

**Slack notification**:
```json
{
  "type": "http",
  "url": "https://hooks.slack.com/services/T00/B00/xxx",
  "timeout": 10
}
```

**Metrics collection**:
```json
{
  "type": "http",
  "url": "http://localhost:9090/metrics/hook",
  "timeout": 5,
  "headers": { "X-Source": "harness" }
}
```

**External dashboard update**:
```json
{
  "type": "http",
  "url": "https://dashboard.example.com/api/events",
  "timeout": 15,
  "headers": { "Authorization": "Bearer $DASHBOARD_TOKEN" },
  "allowedEnvVars": ["DASHBOARD_TOKEN"]
}
```

### Recommended Pattern

Execute command type via `run-script.js`:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" {script-name}",
  "timeout": 30
}
```

## Timeout Setting Guidelines

> **Claude Code v2.1.3+**: Maximum timeout for tool hooks extended from 60 seconds → 10 minutes

### Guidelines by Processing Nature

| Hook Type | Recommended Timeout | Notes |
|-----------|-------------------|-------|
| Lightweight check (guard) | 5-10s | File existence checks, etc. |
| Normal processing (cleanup) | 30-60s | File operations, git operations |
| Heavy processing (test) | 60-120s | Test execution, builds |
| External API integration | 60-180s | Remote API reviews, etc. |
| agent hook (LLM decision) | 30-60s | Depends on model and prompt size. 30s for haiku, 60s for sonnet |
| http hook (external integration) | 5-15s | 5s for a local server, 15s for an external service. Non-blocking on timeout |

**Note**: Set timeouts according to processing nature. Don't make them unnecessarily long.

#### agent hook measured guidelines (haiku model)

| Prompt size | Expected latency | Recommended timeout |
|------------|-------------|------------|
| ~500 tokens | 3-8s | 15s |
| ~1,000 tokens | 5-15s | 30s |
| ~2,000 tokens | 10-25s | 45s |
| over 2,000 tokens | not recommended | — |

Cost estimate (haiku): ~$0.01-0.05/day for a session of 100 calls/day. Under $1-2/month is the normal range.

### Recommended Values by Event Type

| Hook Type | Recommended | Reason |
|-----------|-------------|--------|
| InstructionsLoaded | 5-10s | Lightweight validation of initial context only |
| SessionStart | 30s | Initialization may take time |
| SubagentStart/Stop | 10s | Tracking only, lightweight processing |
| TeammateIdle / TaskCompleted | 10-20s | Team progress and stop decision (`continue:false` if needed) |
| PreToolUse | 30s | Guard processing, file validation |
| PostToolUse | 5-30s | Depends on processing content |
| Stop | 20s | Ensure completion of termination processing |
| SessionEnd | 30s | Session termination processing. Controllable via `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` |
| UserPromptSubmit | 10-30s | Policy injection, tracking |
| Elicitation | 10s | Intercepts MCP elicitation. Auto-skipped in Breezing |
| ElicitationResult | 5s | Result logging only, lightweight processing |
| PostCompact | 15s | Context re-injection. Includes restoring WIP task state |
| PermissionDenied | 10s | Recording/notifying auto mode denial. Lightweight processing (v2.1.89+) |
| StopFailure | 10s | API error logging only. No recovery processing needed (v2.1.78+) |
| ConfigChange | 10s | Audit record of settings changes |

### Special Considerations for Stop Hooks

Stop hooks execute at session termination, so:
- Too short timeouts may interrupt processing
- 20 seconds or more recommended (D14 decision)

### Special Considerations for SessionEnd Hooks

**CC v2.1.74+**: The timeout of SessionEnd hooks became controllable via the `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` environment variable.
Previously it was killed at a fixed 1.5 seconds regardless of the `hook.timeout` setting.

```bash
# Harness recommendation: set 45 seconds for session-cleanup (timeout: 30s)
export CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=45000
```

- To ensure Harness's `session-cleanup` hook (timeout: 30s specified in hooks.json) completes reliably, 45 seconds or more is recommended
- If the environment variable is not set, the CC default value applies (v2.1.74+ respects the hook.timeout setting)

## Hook Structure

### Event Types

```json
{
  "hooks": {
    "PreToolUse": [],      // Before tool execution
    "PostToolUse": [],     // After tool execution
    "InstructionsLoaded": [], // Instruction load completed (v2.1.69+)
    "SessionStart": [],    // At session start
    "Stop": [],            // At session end
    "SubagentStart": [],   // Subagent start
    "SubagentStop": [],    // Subagent end
    "TeammateIdle": [],    // Teammate idle event (team mode)
    "TaskCompleted": [],   // Teammate task completion event (team mode)
    "WorktreeCreate": [],  // Worktree lifecycle start
    "WorktreeRemove": [],  // Worktree lifecycle end
    "UserPromptSubmit": [],// On user input
    "PermissionRequest": [], // On permission request
    "PreCompact": [],      // Before context compaction
    "PostCompact": [],     // After context compaction (v2.1.76+)
    "Elicitation": [],     // MCP elicitation request (v2.1.76+)
    "ElicitationResult": [], // MCP elicitation result (v2.1.76+)
    "Notification": [],    // On notification dispatch
    "PermissionDenied": [], // Auto mode permission denial (v2.1.89+)
    "StopFailure": [],     // API error during session stop (v2.1.78+)
    "ConfigChange": []     // Settings change event
  }
}
```

### Teammate Event Fields (v2.1.69+)

For `TeammateIdle` / `TaskCompleted` / related events, prefer the following fields:

- `agent_id` (recommended key)
- `agent_type` (worker/reviewer, etc.)
- `session_id` (backward-compatibility key)

Rather than assuming only `session_id`, an implementation that references `agent_id` first and falls back is recommended.

### Stop Response Pattern (v2.1.69+)

When you want to stop processing on a team event, return the following form:

```json
{"continue": false, "stopReason": "all_tasks_completed"}
```

To continue as before, you may return `{"decision":"approve"}`.

### matcher Patterns

```json
// Match specific tool
{ "matcher": "Write|Edit|Bash" }

// Match all
{ "matcher": "*" }

// Multiple tools
{ "matcher": "Skill|Task|SlashCommand" }
```

### once Option

Execute only once per session:

```json
{
  "type": "command",
  "command": "...",
  "timeout": 30,
  "once": true  // Recommended for SessionStart
}
```

## Prohibited

- ❌ Editing only one hooks.json
- ❌ Not instructing `{ok, reason}` schema for prompt type
- ❌ Hooks without timeout
- ❌ Absolute paths other than `${CLAUDE_PLUGIN_ROOT}`
- ❌ Commits without running sync-plugin-cache.sh

## Related Decisions

- **D14**: Hook timeout optimization
- **D15**: Stop hook prompt type official spec compliance (`{ok, reason}` schema)

Details: [.claude/memory/decisions.md](../memory/decisions.md)
