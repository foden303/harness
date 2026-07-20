# Harness v4 Go Rewrite — Specification

> The source of truth so the Phase 35 spec does not drift. Check here before implementing, and reconcile against it after implementing.

Last updated: 2026-04-06
CC verified version: 2.1.92

---

## 1. Scope Definition

### What changes

| Target | Before | After |
|------|--------|-------|
| Hook execution path | bash → node → TypeScript | Direct Go binary invocation |
| Config file management | 5-6 files synced manually | harness.toml → `harness sync` auto-generation |
| State management | TypeScript + better-sqlite3 | Go + pure-Go SQLite |
| Scripts | 127 .sh + 7 .js | Progressively absorbed into Go subcommands |

### What does not change (CC plugin protocol compliance)

| Target | Format | Reason |
|------|------|------|
| `plugin.json` | JSON | Required by CC |
| `hooks/hooks.json` | JSON | Required by CC |
| `settings.json` | JSON | Required by CC |
| `agents/*.md` | YAML frontmatter + Markdown | Required by CC. Body is Markdown, so TOML is unsuitable |
| `skills/*/SKILL.md` | YAML frontmatter + Markdown | Required by CC |
| `.mcp.json`, `.lsp.json` | JSON | Required by CC |
| `output-styles/` | Markdown | Required by CC |

### Incremental migration policy

"Zero-base rewrite" is a design philosophy, not an "atomic switch". Migration proceeds incrementally, hook by hook.

- Each hook has **exactly one canonical implementation** (Go or shell)
- No fallback is provided (the Node.js fallback was removed in Phase 35.0)
- Not-yet-migrated hooks keep shell as their canonical implementation
- `harness doctor --migration` detects mixed-mode and warns

---

## 2. Protocol Truth Table

Field-by-field classification based on the official CC hook spec.

### HookInput (stdin JSON)

| Field | Classification | CC version | Go type |
|-------|------|-------------|-------|
| `session_id` | documented | - | `string` |
| `transcript_path` | documented | - | `string` |
| `cwd` | documented | - | `string` |
| `permission_mode` | documented | - | `string` |
| `hook_event_name` | documented | - | `string` |
| `tool_name` | documented (required) | - | `string` |
| `tool_input` | documented (required) | - | `map[string]interface{}` |
| `plugin_root` | harness-private | - | `string` |

**Unknown-field policy**: ignore during JSON decoding (the default `json.Decoder` behavior). Do not strip. Do not hard fail.

### PreToolUse hookSpecificOutput

| Field | Classification | Output condition | Go type |
|-------|------|---------|-------|
| `hookEventName` | documented | always `"PreToolUse"` | `string` |
| `permissionDecision` | documented | always | `"allow"\|"deny"\|"ask"\|"defer"` |
| `permissionDecisionReason` | documented | on deny/ask | `string` |
| `updatedInput` | documented (v2.1.89+) | on input change | `json.RawMessage` |
| `additionalContext` | documented | on warn | `string` |

**Exit code**: deny → exit 2, otherwise → exit 0

### PostToolUse hookSpecificOutput

| Field | Classification | Output condition | Go type |
|-------|------|---------|-------|
| `hookEventName` | documented | always `"PostToolUse"` | `string` |
| `additionalContext` | documented | on warning | `string` |
| `updatedMCPToolOutput` | **experimental (undocumented)** | **not implemented** | - |

### PermissionRequest hookSpecificOutput

| Field | Classification | Go type |
|-------|------|-------|
| `hookSpecificOutput.hookEventName` | documented | `"PermissionRequest"` |
| `hookSpecificOutput.decision.behavior` | documented | `"allow"\|"deny"` |
| `hookSpecificOutput.decision.updatedInput` | documented (v2.1.89+) | `map[string]interface{}` |
| `hookSpecificOutput.decision.updatedPermissions` | documented | `[]interface{}` |

Last verified: 2026-04-06 (CC v2.1.92, code.claude.com/docs/en/hooks)

---

## 3. Hook Ownership Matrix

| Hook Event | Canonical | Phase | Notes |
|-----------|------|-------|------|
| **PreToolUse** (guard) | **Go** | 35.0 ✅ | bin/harness hook pre-tool |
| **PostToolUse** (guard) | **Go** | 35.0 ✅ | bin/harness hook post-tool |
| **PermissionRequest** | **Go** | 35.0 ✅ | bin/harness hook permission |
| SessionStart | shell | 35.3 | session-env-setup + memory-bridge + init |
| SessionEnd | shell | 35.3 | session-cleanup |
| UserPromptSubmit | shell | 35.3 | memory-bridge + policy + tracking |
| PostToolUse (non-guard) | shell | 35.3 | log-toolname, commit-cleanup, track-changes, etc. |
| Stop | shell | 35.3 | session-summary + memory-bridge + evaluator |
| SubagentStart/Stop | shell | 35.4 | subagent-tracker |
| TeammateIdle | shell | 35.4 | teammate-idle handler |
| TaskCompleted/Created | shell | 35.4 | task-completed + runtime-reactive |
| PreCompact/PostCompact | shell | 35.3 | pre-compact-save + post-compact |
| Elicitation/Result | shell | 35.3 | elicitation-handler |
| WorktreeCreate/Remove | shell | 35.6 | worktree lifecycle |
| Notification | shell | 35.3 | notification-handler |
| PermissionDenied | shell | 35.3 | permission-denied-handler |
| StopFailure | shell | 35.3 | stop-failure handler |
| InstructionsLoaded | shell | 35.3 | instructions-loaded |
| ConfigChange/CwdChanged/FileChanged | shell | 35.3 | runtime-reactive |

**Canary order**: PreToolUse (35.0✅) → PermissionRequest (35.0✅) → PostToolUse (35.0✅) → SessionStart → Stop → UserPromptSubmit → everything else

---

## 4. settings.json Actual Schema

The official docs state "only the `agent` key", but in practice the following keys are recognized by CC (verified against the existing `.claude-plugin/settings.json`):

```jsonc
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  // Default agent
  "agent": "string",
  // Environment variable injection
  "env": {
    "KEY": "value"
  },
  // Permission control
  "permissions": {
    "deny": ["Bash(sudo:*)", "mcp__codex__*", "Read(./.env)"],
    "ask": ["Bash(rm -r:*)", "Bash(git push -f:*)"]
  },
  // Sandbox settings
  "sandbox": {
    "failIfUnavailable": true,
    "network": {
      "deniedDomains": ["169.254.169.254", "metadata.google.internal"]
    },
    "filesystem": {
      "denyRead": [".env", "secrets/**", "**/*.pem"],
      "allowRead": [".env.example", "docs/**"]
    }
  }
}
```

---

## 5. harness.toml → CC File Mapping Table

| harness.toml section | Generates | CC key |
|------------------------|--------|--------|
| `[project]` name, version, description, author | `plugin.json` | name, version, description, author |
| `[hooks]` | `hooks/hooks.json` + `.claude-plugin/hooks.json` | hooks |
| `[safety.permissions]` deny, ask | `settings.json` | permissions.deny, permissions.ask |
| `[safety.sandbox]` | `settings.json` | sandbox |
| `[agent]` default | `settings.json` | agent |
| `[env]` | `settings.json` | env |
| `[telemetry]` | **harness-internal setting** (not generated) | N/A |
| `[state]` | **harness-internal setting** (not generated) | N/A |

### Rejected / Unsupported

`harness sync` raises an **explicit error** for the following keys:

- `userConfig` — does not exist in CC
- `channels` — does not exist in CC
- Unknown keys in `settings.json` — keys not present in the CC schema are not generated

---

## 6. SQLite Driver Selection

| Item | `modernc.org/sqlite` | `mattn/go-sqlite3` |
|------|---------------------|-------------------|
| CGO | **not required** (pure Go) | required |
| Cross-compile | self-contained via `GOOS=x go build` | requires a target C compiler |
| Binary size increase | +3-5MB | +1-2MB |
| WAL mode | ✅ | ✅ |
| File locking | POSIX (flock) | POSIX (flock) |
| Performance | 10-30% slower (pure Go) | native speed |
| Stability | high (Go translation of the official SQLite C code) | high (official SQLite C code directly) |

**Selected: `modernc.org/sqlite`**

Rationale:
- Cross-compilation is a prerequisite for Phase 35.7
- No CGO greatly simplifies builds and CI
- The performance gap is absorbed by a design that does not use SQLite on the hook hot path (Phase 35.0 already achieved 5ms without SQLite)
- `busy_timeout=5000` mitigates lock contention

---

## 7. CLI Command Specification

### `harness hook <event>`

```
stdin:  Hook JSON (sent by CC)
stdout: hookSpecificOutput JSON (interpreted by CC)
exit:   0 = allow/warn, 2 = deny/block
```

| Subcommand | Function |
|------------|------|
| `harness hook pre-tool` | PreToolUse guardrails (R01-R13) |
| `harness hook post-tool` | PostToolUse tampering detection + security checks |
| `harness hook permission` | PermissionRequest auto-approval |

### `harness sync`

```
stdin:  none
stdout: generation log
exit:   0 = success, 1 = harness.toml parse error or unsupported key
```

Reads harness.toml and generates:
- `hooks/hooks.json`
- `.claude-plugin/hooks.json` (identical content)
- `.claude-plugin/plugin.json`
- `.claude-plugin/settings.json`

### `harness init`

```
stdin:  none
stdout: generation log
exit:   0 = success
```

Generates a `harness.toml` template in the current directory.

### `harness validate [skills|agents|all]`

```
stdout: validation results
exit:   0 = all PASS, 1 = errors present
```

### `harness doctor [--migration]`

```
stdout: diagnostic results
exit:   0 = healthy, 1 = problems present
```

`--migration`: detect Go/shell mixed-mode and display migration status.

### `harness version`

```
stdout: version string
exit:   0
```

---

## 8. State Machine Definition

### Normal path

```
SPAWNING → RUNNING → REVIEWING → APPROVED → COMMITTED
```

### Abnormal path

```
SPAWNING → FAILED        (spawn failure)
RUNNING  → FAILED        (runtime error, exceeded 3 retries)
RUNNING  → CANCELLED     (user interrupt, Ctrl+C)
REVIEWING → FAILED       (review error)
REVIEWING → CANCELLED    (user interrupt)
RUNNING  → STALE         (auto-transition after 24h)
REVIEWING → STALE        (auto-transition after 24h)
FAILED   → RECOVERING    (recovery started)
RECOVERING → RUNNING     (recovery succeeded)
RECOVERING → ABORTED     (recovery failed, human intervention required)
```

### 4-stage recovery

| Stage | Trigger | Action |
|------|---------|----------|
| 1. Self-repair | first failure | error analysis → auto-fix → retry |
| 2. Peer repair | self-repair failed | delegate the task to another Worker |
| 3. Commander intervention | peer repair failed | escalate to the Lead session |
| 4. Halt | commander intervention failed | ABORTED state, notify user |

---

## 9. State Storage Contract

### Path priority

```
1. ${CLAUDE_PLUGIN_DATA}/state.db    (persistent on CC v2.1.78+)
2. ${PROJECT_ROOT}/.harness/state.db (fallback)
3. ${PROJECT_ROOT}/.claude/state/    (for shell scripts, read-only)
```

### Migration strategy

| Operation | Command | Description |
|------|---------|------|
| Export | `harness state export` | dump the current state.db to JSON |
| Import | `harness state import` | restore from JSON into a new state.db |
| Rollback | `HARNESS_STATE_PATH=old.db` | override the path via environment variable |

### Retention period

| Table | TTL | Cleanup |
|---------|-----|-------------|
| `work_states` | 24h | automatic (expires_at) |
| `sessions` | unlimited | manual |
| `signals` | 7d once consumed | automatic |
| `task_failures` | unlimited | manual |
| `assumptions` | unlimited | manual |

---

## 10. Guardrail Rule Specification

| ID | Tool | Condition | Action | Bypass |
|----|--------|------|----------|---------|
| R01 | Bash | `sudo` detected | deny | none |
| R02 | Write/Edit/MultiEdit | protected paths (.env, .git/, *.pem, *.key, id_rsa, etc.) | deny | none |
| R03 | Bash | `> .env`, `tee .git/`, etc. via redirection / `tee` | deny (only exact match of TOML ask-list `.env` / `.env.*` + reason → ask) | `[[safety.guardrail.protectedPathAskList]]` |
| R04 | Write/Edit/MultiEdit | absolute path outside the project root | ask | workMode |
| R05 | Bash | `rm -rf` / `rm --recursive` | ask | workMode |
| R06 | Bash | `git push --force` / `-f` | deny | none |
| R07 | Write/Edit/MultiEdit | direct write during codexMode | deny | none |
| R08 | Write/Edit/MultiEdit/Bash | write/mutate commands by a breezing reviewer | deny | none |
| R09 | Read | sensitive files (.env, id_rsa, *.pem, secrets/) | approve + warn | none |
| R10 | Bash | `--no-verify` / `--no-gpg-sign` | deny | none |
| R11 | Bash | `git reset --hard` on a protected branch | deny | none |
| R12 | Bash | direct push to main/master | ask (configurable to deny / allow) | `protected_branch_push` |
| R13 | Write/Edit/MultiEdit | package.json, Dockerfile, workflow, etc. | approve + warn | none |

R03 target extraction is redirection / `tee` based. In-place write detection such as `sed -i` is out of scope for v1.

Test IDs: `TestR01_*` through `TestR13_*` (go/internal/guard/rules_test.go)

---

## 11. CC Version Compatibility Matrix

| Feature | Minimum CC version | Notes |
|------|-------------------|------|
| Automatic `bin/` PATH addition | v2.1.91 | added to the Bash tool's PATH |
| `${CLAUDE_PLUGIN_DATA}` | v2.1.78 | persists across plugin updates |
| exit code 2 blocking | v2.1.90 | buggy before v2.1.89 |
| `permissionDecision: "defer"` | v2.1.89 | headless-mode pause |
| `updatedInput` | v2.1.89 | input rewriting |
| `additionalContext` | v2.1.89 | additional context for Claude |
| PreToolUse `allow` does not override settings.json `deny` | v2.1.77 | security hardening |
| `settings.json` permissions/sandbox | v2.1.77+ | verified in practice |

**Minimum recommended CC version: v2.1.91** (because bin/ PATH is required)

---

## 12. Package Boundaries

### hook-fastpath (within 5ms)

```
internal/guard/     — rule evaluation, tampering detection, security checks
internal/hook/      — stdin/stdout codec
pkg/protocol/       — type definitions
```

**Constraints**:
- No file I/O (SQLite reference only in BuildContext, optional)
- No network I/O
- No goroutine launches
- No external process launches

### worker-runtime (long-lived)

```
internal/state/       — SQLite store
internal/session/     — session lifecycle
internal/breezing/    — concurrent orchestration
internal/hookhandler/ — hook handlers (including OTel export, broadcast)
internal/lifecycle/   — session state tracking + recovery
internal/ci/          — CI integration utilities
pkg/config/           — config parser (harness.toml)
```

**Constraints**:
- goroutines managed via `context.Context`
- graceful shutdown required
- Do not import the `hook-fastpath` package (dependency in the reverse direction is allowed)

### API boundary

```
hook-fastpath ←── protocol (shared)
                       ↓
worker-runtime ←── protocol (shared)
```

`hook-fastpath` and `worker-runtime` do not import each other directly.
Shared types live only in `pkg/protocol/`.

---

## Decision: codex-companion.sh

**Policy**: **out of scope** for Go integration. Keep the shell wrapper.

Rationale:
- codex-companion.sh is a wrapper for invoking the Codex CLI (external process)
- The Codex CLI itself updates frequently and its API is not stable
- A shell wrapper follows Codex CLI changes more easily
- Consistent with the D2 policy in DESIGN.md

Go integration is limited to Harness-internal logic (guardrails, state management, config generation).
