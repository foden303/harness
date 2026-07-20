# Harness Go Rewrite — Architecture Design

> Zero-base rewrite. No backward compatibility. All accumulated knowledge applied.

## Why Go

| Requirement | Go | Rust | Current (bash+TS) |
|------|-----|------|---------------|
| Cold start | 1-2ms | 0.5-1ms | 40-60ms |
| Cross-compile | `GOOS=x go build` | toolchain management | N/A (interpreter) |
| JSON handling | stdlib `encoding/json` | serde (verbose) | jq + node |
| HTTP client | stdlib `net/http` | reqwest (dep) | curl spawn |
| Development speed | seconds | minutes | immediate but fragile |
| Binary size | 5-10MB | 2-5MB | ~200KB scripts |
| Dependencies | stdlib + 1-2 (uuid) | many crates | node + jq + bash |
| Self-referential dev | compile in 2s | compile in 30s+ | edit & run |

**Conclusion**: Harness is a tool that "launches several times per second, reads JSON, and returns a decision". Go's stdlib-centric approach plus fast compilation is the best fit.

### Permitted external dependencies

- `github.com/google/uuid` — OTel trace ID generation. stdlib has no UUID v4
- `github.com/mattn/go-isatty` — TTY detection (optional: substitutable with `os.Stdin.Stat()`)
- **Nothing else is allowed.** Both the MCP protocol and the OTel format are implemented in-house using stdlib `encoding/json` + `net/http`

## Directory Structure

```
harness-go/
├── cmd/
│   └── harness/
│       └── main.go              # Single entry: stdin → route → stdout
│
├── internal/
│   ├── guardrail/               # Guardrail engine (hot path, PreToolUse/PostToolUse/Permission)
│   │   ├── rules.go             # Declarative rule table (R01-R13+) + evaluation loop
│   │   ├── helpers.go           # Protected path detection, rm -rf, git push --force, etc.
│   │   ├── pre_tool.go          # PreToolUse: context build + deny/allow/defer
│   │   ├── post_tool.go         # PostToolUse: security risk detection + advisory checks
│   │   ├── permission.go        # PermissionRequest: conditional eval
│   │   └── tampering.go         # Test/config tampering detection (T01-T12)
│   │
│   ├── session/                 # Session lifecycle + agent tracking
│   │   ├── start.go             # SessionStart: env + memory bridge + init (parallel)
│   │   ├── stop.go              # Stop: summary, memory save, WIP check
│   │   ├── compact.go           # PreCompact save + PostCompact WIP restore
│   │   ├── agent.go             # SubagentStart/Stop tracking + trace
│   │   └── state.go             # State file + JSONL append with rotation
│   │
│   ├── event/                   # Remaining hook events + dispatcher
│   │   ├── dispatcher.go        # stdin → parse → route → execute → stdout
│   │   ├── prompt.go            # UserPromptSubmit: policy injection, tracking
│   │   ├── task.go              # TaskCreated/Completed + webhook trigger
│   │   ├── denied.go            # PermissionDenied: telemetry + retry
│   │   └── misc.go              # Notification, ConfigChange, Elicitation, StopFailure
│   │
│   ├── plans/                   # Plans.md operations + effort scoring
│   │   ├── parser.go            # Parse Plans.md tables (5-column format)
│   │   ├── marker.go            # Status marker read/update
│   │   └── effort.go            # Task complexity scoring
│   │
│   ├── hook/                    # Hook I/O codec (stdin parse, stdout marshal)
│   │   └── codec.go             # ReadInput / WriteResult helpers
│   │
│   ├── hookhandler/             # Go ports of shell hook handlers (40+ handlers)
│   │   ├── emit_agent_trace.go  # OTel span export (sync HTTP POST, 3s timeout, JSONL fallback)
│   │   ├── session_auto_broadcast.go  # Inter-session file-based broadcast
│   │   ├── memory_bridge.go     # Memory bridge (JSONL logging + harness-mem HTTP POST)
│   │   ├── task_completed.go    # TaskCompleted lifecycle + escalation + timeline
│   │   ├── auto_test_runner.go  # Auto test execution on Write/Edit
│   │   ├── ci_status_checker.go # CI status polling
│   │   └── ...                  # 30+ additional handlers (see go/internal/hookhandler/)
│   │
│   ├── breezing/                # Parallel task orchestration (worktree isolation)
│   │   ├── orchestrator.go      # Semaphore-controlled parallel execution
│   │   ├── worktree.go          # Git worktree create/remove
│   │   └── deps.go              # Task dependency resolution
│   │
│   ├── ci/                      # CI integration utilities
│   │   └── ci.go                # CI provider detection + status check
│   │
│   ├── lifecycle/               # Session lifecycle tracking + recovery
│   │   ├── tracker.go           # Session state machine
│   │   ├── state.go             # Work state persistence
│   │   └── recovery.go          # 4-stage recovery logic
│   │
│   └── state/                   # SQLite state store
│       ├── schema.go            # DB schema definition
│       └── store.go             # HarnessStore CRUD operations
│
├── pkg/
│   ├── hookproto/               # Hook protocol types (public API)
│   │   └── types.go             # HookInput, HookResult, Decision constants, output structs
│   │
│   └── config/                  # Configuration (harness.toml parsing)
│       └── toml.go              # HarnessConfig + TelemetryConfig (webhook_url, otel_endpoint)
│
├── skills/                   # Skills (Markdown, unchanged)
├── agents/                   # Agents (Markdown, unchanged)
├── .claude-plugin/
│   ├── plugin.json
│   ├── hooks.json               # Simplified: all → bin/harness hook <event>
│   └── settings.json
│
├── bin/                         # Build output (gitignored)
│   ├── harness-darwin-arm64
│   ├── harness-darwin-amd64
│   ├── harness-linux-amd64
│   └── harness-windows-amd64.exe
│
├── Makefile
├── go.mod
└── go.sum
```

**internal packages: 9** (guardrail, session, event, hook, hookhandler, breezing, ci, lifecycle, state). `pkg/` holds hookproto + config.
Notification features (OTel span export, broadcast) are integrated into `hookhandler/`. There is no standalone notify package; the design was changed so each handler sends directly.
Webhook POST is not implemented (only the config definition exists; planned for the future).
review (security/dual) is completed via skill-side prompt instructions, so it is excluded from the Go binary.

## Core Design: Single Binary, Subcommand Routing

```
# === Hook events (covers all 20 events; corresponds to every command hook in the current hooks.json) ===
bin/harness hook pretool            # PreToolUse
bin/harness hook pretool --browser  # PreToolUse (browser MCP tools)
bin/harness hook posttool           # PostToolUse
bin/harness hook permission         # PermissionRequest
bin/harness hook session-start      # SessionStart (startup + resume)
bin/harness hook session-end        # SessionEnd
bin/harness hook stop               # Stop
bin/harness hook pre-compact        # PreCompact
bin/harness hook post-compact       # PostCompact
bin/harness hook task-completed     # TaskCompleted
bin/harness hook task-created       # TaskCreated (runtime-reactive)
bin/harness hook permission-denied  # PermissionDenied
bin/harness hook teammate-idle      # TeammateIdle
bin/harness hook notification       # Notification
bin/harness hook config-change      # ConfigChange
bin/harness hook elicitation        # Elicitation
bin/harness hook elicitation-result # ElicitationResult
bin/harness hook stop-failure       # StopFailure
bin/harness hook user-prompt        # UserPromptSubmit
bin/harness hook todo-sync          # PostToolUse/TodoWrite → Plans.md sync
bin/harness hook subagent-start     # SubagentStart
bin/harness hook subagent-stop      # SubagentStop
bin/harness hook setup              # Setup (init / init-only / maintenance)
bin/harness hook instructions-loaded # InstructionsLoaded
bin/harness hook worktree-create    # WorktreeCreate
bin/harness hook worktree-remove    # WorktreeRemove
bin/harness hook cwd-changed        # CwdChanged (runtime-reactive)
bin/harness hook file-changed       # FileChanged (runtime-reactive)
bin/harness hook post-tool-failure  # PostToolUseFailure

# === Utilities ===
bin/harness effort <task-desc>      # Effort scoring
bin/harness plans sync              # Plans.md sync
bin/harness plans update <id> <status>  # Marker update
bin/harness version                 # Version info
```

**40+ shell scripts → 1 binary, ~28 subcommands. Covers every command hook in the current hooks.json without omission.**
**The MCP subcommand is removed (D3: keep it a separate process).**

## hooks.json (Simplified)

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write|Edit|MultiEdit|Bash|Read",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook pretool",
        "timeout": 10
      }]
    }, {
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "agent",
        "prompt": "Review the following code change for quality issues. Check if the change: (1) introduces hardcoded secrets or credentials, (2) leaves TODO/FIXME stubs without implementation, (3) has obvious security vulnerabilities (SQL injection, XSS, command injection). If any issue is found, return JSON with permissionDecision: 'deny' and permissionDecisionReason explaining the issue. If the change looks acceptable, return nothing (exit 0). Input: $ARGUMENTS",
        "model": "haiku",
        "timeout": 30
      }]
    }, {
      "matcher": "mcp__chrome-devtools__.*|mcp__playwright__.*|mcp__plugin_playwright_playwright__.*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook pretool --browser",
        "timeout": 5
      }]
    }],
    "PermissionRequest": [{
      "matcher": "Edit|Write|MultiEdit",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook permission",
        "timeout": 10
      }]
    }, {
      "matcher": "Bash",
      "if": "Bash(git status*)|Bash(git diff*)|Bash(git log*)|Bash(git branch*)|Bash(git rev-parse*)|Bash(git show*)|Bash(git ls-files*)|Bash(npm test*)|Bash(npm run test*)|Bash(npm run lint*)|Bash(npm run typecheck*)|Bash(npm run build*)|Bash(npm run validate*)|Bash(npm lint*)|Bash(npm typecheck*)|Bash(npm build*)|Bash(pnpm test*)|Bash(pnpm run test*)|Bash(pnpm run lint*)|Bash(pnpm run typecheck*)|Bash(pnpm run build*)|Bash(pnpm run validate*)|Bash(pnpm lint*)|Bash(pnpm typecheck*)|Bash(pnpm build*)|Bash(yarn test*)|Bash(yarn run test*)|Bash(yarn run lint*)|Bash(yarn run typecheck*)|Bash(yarn run build*)|Bash(yarn run validate*)|Bash(yarn lint*)|Bash(yarn typecheck*)|Bash(yarn build*)|Bash(pytest*)|Bash(python -m pytest*)|Bash(go test*)|Bash(cargo test*)",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook permission",
        "timeout": 10
      }]
    }],
    "PostToolUse": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook posttool",
        "timeout": 10
      }]
    }, {
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "agent",
        "prompt": "Perform a lightweight code review on the file that was just written/edited. Check for: (1) hardcoded secrets or API keys, (2) TODO/FIXME stubs left without implementation, (3) obvious security issues. This is a non-blocking advisory check. If issues found, include them in systemMessage. Input: $ARGUMENTS",
        "model": "haiku",
        "timeout": 30
      }]
    }, {
      "matcher": "Write|Edit|Task",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness worker auto-test",
        "timeout": 120,
        "async": true
      }]
    }, {
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness worker ci-check",
        "timeout": 30,
        "async": true
      }]
    }, {
      "matcher": "TodoWrite",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook todo-sync",
        "timeout": 30
      }]
    }],
    "SessionStart": [{
      "matcher": "startup|resume",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook session-start",
        "timeout": 15,
        "once": true
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook stop",
        "timeout": 20
      }, {
        "type": "agent",
        "prompt": "Check if there are incomplete tasks before allowing session to stop. Read the Plans.md file and look for tasks with status 'cc:WIP'. If any WIP tasks exist, return JSON: {\"decision\": \"block\", \"reason\": \"WIP tasks remain: [list task numbers]. Consider completing them or marking as blocked before stopping.\"}. If no WIP tasks, return nothing (allow stop). Input: $ARGUMENTS",
        "model": "haiku",
        "timeout": 30
      }]
    }],
    "PreCompact": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook pre-compact",
        "timeout": 15
      }, {
        "type": "agent",
        "prompt": "Check Plans.md for tasks with status 'cc:WIP' before the context window is compacted. If any WIP tasks exist, include a warning in systemMessage: 'Warning: Compacting context with WIP tasks in progress: [list task IDs and titles]. Key context about these tasks may be lost after compaction. Consider completing or checkpointing them first.' If no WIP tasks, return nothing. Input: $ARGUMENTS",
        "model": "haiku",
        "timeout": 30
      }]
    }],
    "PostCompact": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook post-compact",
        "timeout": 10
      }]
    }],
    "TaskCompleted": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook task-completed",
        "timeout": 10
      }]
    }],
    "TaskCreated": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook task-created",
        "timeout": 5
      }]
    }],
    "PermissionDenied": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook permission-denied",
        "timeout": 5
      }]
    }],
    "SubagentStart": [{
      "matcher": "worker|reviewer|video-scene-generator",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook subagent-start",
        "timeout": 5
      }]
    }],
    "SubagentStop": [{
      "matcher": "worker|reviewer|video-scene-generator",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook subagent-stop",
        "timeout": 5
      }]
    }],
    "TeammateIdle": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook teammate-idle",
        "timeout": 10
      }]
    }],
    "ConfigChange": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook config-change",
        "timeout": 10
      }]
    }],
    "UserPromptSubmit": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook user-prompt",
        "timeout": 10
      }]
    }],
    "Notification": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook notification",
        "timeout": 5
      }]
    }],
    "StopFailure": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook stop-failure",
        "timeout": 5
      }]
    }],
    "SessionEnd": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook session-end",
        "timeout": 15
      }]
    }],
    "Setup": [{
      "matcher": "init|init-only",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook setup --mode init",
        "timeout": 60,
        "once": true
      }]
    }, {
      "matcher": "maintenance",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook setup --mode maintenance",
        "timeout": 60,
        "once": true
      }]
    }],
    "InstructionsLoaded": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook instructions-loaded",
        "timeout": 10
      }]
    }],
    "WorktreeCreate": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook worktree-create",
        "timeout": 10
      }]
    }],
    "WorktreeRemove": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook worktree-remove",
        "timeout": 10
      }]
    }],
    "CwdChanged": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook cwd-changed",
        "timeout": 10
      }]
    }],
    "FileChanged": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook file-changed",
        "timeout": 10
      }]
    }],
    "Elicitation": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook elicitation",
        "timeout": 10
      }]
    }],
    "ElicitationResult": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook elicitation-result",
        "timeout": 5
      }]
    }],
    "PostToolUseFailure": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook post-tool-failure",
        "timeout": 10
      }]
    }]
  }
}
```

**Covers every command hook event in the current hooks.json.** agent hooks (type: "agent") remain as-is within PreToolUse/PostToolUse/Stop/PreCompact.

### Built-in Memory Bridge

`hookhandler/memory_bridge.go` handles five event targets.
The JSONL log is always written, and when the harness-mem daemon is running it integrates via HTTP POST.

**Event flow**:

| hook target | harness-mem endpoint | event_type |
|------------|---------------------|------------|
| session-start | POST /v1/events/record | session_start |
| user-prompt | POST /v1/events/record | user_prompt |
| post-tool-use | POST /v1/events/record | tool_use |
| stop | POST /v1/sessions/finalize | (finalize) |
| codex-notify | POST /v1/events/record | checkpoint |

**Behavior when harness-mem is not installed**: the HTTP POST fails immediately with `connection refused`,
logs to stderr, and returns approve. Only the JSONL log is recorded.
The added latency is only the few milliseconds of the connection refusal.

**Configuration**:
- `HARNESS_MEM_HOST` (default: 127.0.0.1)
- `HARNESS_MEM_PORT` (default: 37888)
- `HARNESS_MEM_ADMIN_TOKEN` (optional: attached as the Bearer header)

## Guardrail Engine Design

```go
// internal/guardrail/rules.go

type Rule struct {
    ID          string                         // R01, R02, ...
    Name        string                         // Human-readable name
    Events      []string                       // Which hook events this applies to
    Match       func(input *hookproto.Input) bool
    Evaluate    func(input *hookproto.Input) *Decision
    Severity    Severity                       // block, warn, info
}

type Decision struct {
    Action  Action  // allow, deny, defer, warn
    Reason  string
    Details map[string]any
}

var Rules = []Rule{
    {
        ID:       "R01",
        Name:     "no-hardcoded-secrets",
        Events:   []string{"pretool"},
        Severity: Block,
        Match: func(in *hookproto.Input) bool {
            return in.Tool == "Write" || in.Tool == "Edit"
        },
        Evaluate: func(in *hookproto.Input) *Decision {
            if containsSecret(in.Content) {
                return &Decision{Action: Deny, Reason: "Hardcoded secret detected"}
            }
            return nil // pass
        },
    },
    {
        ID:       "R02",
        Name:     "no-test-tampering",
        Events:   []string{"pretool"},
        Severity: Block,
        Match: func(in *hookproto.Input) bool {
            return (in.Tool == "Write" || in.Tool == "Edit") && isTestFile(in.FilePath)
        },
        Evaluate: func(in *hookproto.Input) *Decision {
            if detectsTampering(in.Content) {
                return &Decision{Action: Deny, Reason: "Test tampering detected: skip/only/assertion removal"}
            }
            return nil
        },
    },
    // ... R03-R13+
}
```

**Declarative rule table.** Adding a rule is just adding one struct. Readability is orders of magnitude better than a shell if/else chain.

## State Management

```go
// Design policy: State directory resolution (applied in each handler)

func stateDir() string {
    if d := os.Getenv("CLAUDE_PLUGIN_DATA"); d != "" {
        hash := projectHash(projectRoot())
        return filepath.Join(d, "projects", hash)
    }
    return filepath.Join(projectRoot(), ".claude", "state")
}

// Design policy: Symlink safety (verify before file I/O)
func safeAppend(path string, data []byte) error {
    if isSymlink(path) || isSymlink(filepath.Dir(path)) {
        return ErrSymlinkRefused
    }
    // ...
}
```

**Security checks (symlink refusal, directory verification) apply to all handlers as a design policy.**
Currently each handler performs path resolution and file I/O individually.
Consolidation into a shared utility is a future refactoring candidate.

## Security Design

| Threat | Mitigation | Implementation location |
|------|------|---------|
| **Symlink traversal** | symlink check before file I/O. symlinks are refused immediately | Design policy. `os.Lstat` performed individually in each handler |
| **Path traversal (../)** | `filepath.Clean` + `filepath.Rel` to refuse writes outside the state dir | Design policy. applied individually in each handler |
| **Secret leak (logs)** | mask URLs, tokens, and API keys when logging | Design policy (planned for consolidation when webhook is implemented) |
| **Command injection** | the guardrail hot path (pretool/posttool/permission) uses no shell or exec.Command and is fully internal. The worker subcommands (auto-test, ci-check) run the project's test/CI commands via exec.Command (equivalent to the current shell version) | guardrail/* is internal processing. hookhandler/auto_test_runner.go, hookhandler/ci_status_checker.go are allowed to use exec.Command |
| **TOCTOU** | operate directly without a file-existence check → error handling | operate directly in each handler → apply the error handling pattern |
| **Unbounded growth** | JSONL rotation (over 500 lines → truncated to 400 lines) | hookhandler/emit_agent_trace.go (rotation via MaxFileSize) |
| **Secret in hook output** | sanitize when including user input in a PreToolUse deny reason | guardrail/pre_tool.go |
| **Memory injection** | required-field and length checks before the harness-mem POST (K-1.2) | hookhandler/memory_bridge.go `validateBridgeInput` |

### SafeResult fail-open design decision

`hook.SafeResult` returns `approve` on engine errors such as stdin parse errors (fail-open).
This superficially contradicts S-1.5 "default to the safe side", but it is an intentional design decision.

**Rationale**: in the CC protocol a hook is "a layer that supplementarily inspects tool usage", and
halting the user's session because of a failure in the hook itself is more harmful than continuing
without guardrails. The deny decision is made deterministically by regex matching against the `GuardRule`
table, and SafeResult is reached only "when rule evaluation itself was impossible".

**Position of the guard**: the deny decision is reliably blocked with exit code 2.
SafeResult is "an infrastructure failure at the stage before rule evaluation" — not a case of
"skipping the safety decision" but "not obtaining the input for the safety decision".

## Delivery Model: Notification in a Short-Lived Process

The Go binary is a short-lived process that launches on demand and exits immediately. async goroutines disappear when the process ends.

**Current implementation status**:

| Notification channel | Status | Implementation location |
|------------|------|---------|
| OTel span export | **implemented** (sync, 3s timeout) | `hookhandler/emit_agent_trace.go` |
| Inter-session broadcast | **implemented** (file-based) | `hookhandler/session_auto_broadcast.go` |
| Webhook POST | **not implemented** (planned for the future) | — |

**OTel span export flow** (emit-agent-trace handler):

```
bin/harness hook PostToolUse (agent trace)
  → append the trace record to agent-trace.jsonl
  → if OTEL_EXPORTER_OTLP_ENDPOINT is set:
    → HTTP POST (sync, 3s timeout, Content-Type: application/json)
    → failures are logged to stderr only. no retry
  → stdout JSON response
  → exit
```

- OTel sending is sync with timeout (3s). it waits for completion within the process
- send failures are logged to stderr only. no retry (a new event is sent on the next hook launch)
- JSONL is always written (a fallback and local record for when OTel sending fails)

**Webhook POST** has a field definition in the config struct (the `[telemetry]` section of
`harness.toml`), but the send logic is not implemented. Once the need is confirmed, the plan is
to add a sync POST to the relevant handler within `hookhandler/`.

**Handling long-running hooks (PostToolUse)**:

The current `auto-test-runner` (120s, async) and `ci-status-checker` (30s, async) do not
fit within a short-lived process. These are treated as **separate workers**:

```json
// Place the Go binary and the separate workers in parallel in hooks.json
"PostToolUse": [{
  "matcher": "Write|Edit|MultiEdit|Bash",
  "hooks": [{
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook posttool",
    "timeout": 10
  }]
}, {
  "matcher": "Write|Edit|Task",
  "hooks": [{
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness worker auto-test",
    "timeout": 120,
    "async": true
  }]
}, {
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness worker ci-check",
    "timeout": 30,
    "async": true
  }]
}]
```

`bin/harness worker <name>` is a subcommand for long-running execution.
`bin/harness hook posttool` handles only the fast decision (10s), and heavy work is offloaded to a worker.

## Handling Agent Hooks (type: "agent")

**Decision: keep them in hooks.json. The Go binary is not involved.**

agent hooks are a mechanism where CC launches an LLM and delegates the decision to it. The Go binary replaces only `type: "command"` hooks.

```json
// agent hooks remain as-is in hooks.json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook pretool",
      "timeout": 10
    },
    {
      "type": "agent",
      "prompt": "Review the code change for quality issues...",
      "model": "haiku",
      "timeout": 30
    }
  ]
}
```

The Go binary (command) returns a fast guardrail decision, and the agent hook (LLM) then performs a quality check asynchronously afterward. Separation of concerns.

## Handling the MCP Server

**Decision: a separate process. Not built into the Go binary. Integrated via the HTTP API.**

Rationale:
- harness-mem is a SQLite-based persistent store. SQLite without CGO in Go has many constraints
- The MCP server is a resident process; hook handlers are short-lived processes. Their lifecycles differ
- The Go binary POSTs directly to the harness-mem HTTP API in `hookhandler/memory_bridge.go`

```
bin/harness hook session-start → memory_bridge.go → JSONL log + POST /v1/events/record
bin/harness hook user-prompt   → memory_bridge.go → JSONL log + POST /v1/events/record
bin/harness hook post-tool-use → memory_bridge.go → JSONL log + POST /v1/events/record
bin/harness hook stop          → memory_bridge.go → JSONL log + POST /v1/sessions/finalize
bin/harness hook codex-notify  → memory_bridge.go → JSONL log + POST /v1/events/record
```

If harness-mem is not running, it falls back immediately on connection refused (JSONL only).
If a pure-Go MCP server is needed in the future, it will be implemented as a separate binary using `modernc.org/sqlite` (CGO-free).

## Performance Comparison (Estimated)

| Operation | Current (bash+node) | Go rewrite | Speedup |
|-----------|-------------------|------------|---------|
| PreToolUse guardrail | 40-60ms | 2-3ms | **20x** |
| PostToolUse logging | 20-30ms | 1-2ms | **15x** |
| SessionStart init | 500-800ms (4 hooks) | 10-15ms (1 call) | **50x** |
| TaskCompleted + webhook | 100-150ms | 3-5ms | **30x** |
| OTel span export | 100-200ms | 2-3ms (async) | **50x** |
| Plans.md parse | 50-100ms (bash+jq) | 1-2ms | **50x** |
| Total per tool call | 60-90ms overhead | 3-5ms overhead | **20x** |

**Breezing 1000 tool calls: 60-90 seconds → 3-5 seconds**

### Worst Case Analysis (PreToolUse)

```
stdin JSON read:     0.1ms  (io.ReadAll, unbounded — large Write/Edit payloads safe)
json.Unmarshal:      0.3ms  (encoding/json, typed struct)
Rule matching loop:  0.5ms  (13 rules × Match func, short-circuit on first deny)
State dir access:    0.5ms  (single os.Stat for CLAUDE_PLUGIN_DATA resolution)
JSONL append:        0.3ms  (safefile.Append, includes Lstat check)
json.Marshal output: 0.1ms  (<200B response)
─────────────────────────────
Worst case total:    1.8ms
```

SessionStart (parallel goroutines):
```
env setup:           2ms   ┐
rules load:          1ms   ├── parallel → max(2, 1) = 2ms
memory bridge file:  3ms   │  (sequential after env)
─────────────────────────────
Worst case total:    5ms
```

## What Stays Markdown

| Component | Format | Reason |
|-----------|--------|--------|
| skills/*.md | Markdown | CC reads them as prompts. No compilation needed |
| agents/*.md | Markdown | CC reads them as prompts |
| .claude/rules/*.md | Markdown | CC reads them as rules |
| CLAUDE.md | Markdown | CC reads it as instructions |
| Plans.md | Markdown | Go parses it, but humans read it too |
| CHANGELOG.md | Markdown | release notes |

## What Disappears

| Current | Go Rewrite | Reason |
|---------|------------|--------|
| 40+ shell scripts in scripts/ | 0 | all integrated into the Go binary |
| core/src/ TypeScript | 0 | replaced by Go internal/ |
| node_modules/ | 0 | Go is self-contained with stdlib |
| scripts/run-hook.sh routing | 0 | Go subcommand routing |
| jq dependency | 0 | Go encoding/json |
| scripts/path-utils.sh | 0 | path resolution embedded in each handler |
| scripts/sync-plugin-cache.sh | updated to a Go version | copies hooks.json + bin/* into .claude-plugin/. The dual management is retained (test compatibility) |

## Build & Distribution

```makefile
# Makefile

PLATFORMS := darwin/arm64 darwin/amd64 linux/amd64 linux/arm64 windows/amd64

.PHONY: build
build:
	go build -o bin/harness ./cmd/harness

.PHONY: release
release:
	$(foreach platform,$(PLATFORMS),\
		GOOS=$(word 1,$(subst /, ,$(platform))) \
		GOARCH=$(word 2,$(subst /, ,$(platform))) \
		go build -ldflags="-s -w" \
		-o bin/harness-$(subst /,-,$(platform))$(if $(findstring windows,$(platform)),.exe) ./cmd/harness ;)

.PHONY: test
test:
	go test ./...

.PHONY: lint
lint:
	golangci-lint run
```

## Migration Path

This is a **zero-base rewrite**, not a migration. Both versions coexist:

- `main` branch: Current bash+TS version (production)
- `feat/harness-go-rewrite` branch: Go version (development)

Switch is atomic: replace `hooks/hooks.json` + `.claude-plugin/hooks.json` + `.claude-plugin/` metadata + `bin/` in one commit.
The dual management of `hooks/hooks.json` and `.claude-plugin/hooks.json` is retained (test-hooks-sync.sh compatibility).

## Design Decisions (formerly Open Questions)

| # | Question | Decision | Rationale |
|---|------|------|------|
| D1 | agent hooks (type: "agent") | **Keep them in hooks.json. Go handles only command hooks** | LLM judgment is CC's responsibility. Go focuses on fast rule evaluation |
| D2 | Codex companion | **Keep the current shell wrapper** | The companion is a proxy for codex-plugin-cc. The ROI of porting to Go is low |
| D3 | Memory MCP | **A separate process. Not built into Go** | SQLite CGO issues, lifecycle mismatch. Continue using the Node version |
| D4 | Plugin bin/ auto-selection | **Use CC's bin/ feature** | CC v2.1.91+ selects the binary per platform. Just match the naming convention in the Makefile |
| D5 | Package structure | **internal 9 + pkg 2** (guardrail, session, event, hook, hookhandler, breezing, ci, lifecycle, state / hookproto, config) | Notifications integrated into hookhandler. Split by feature while keeping dependencies one-directional |
| D6 | review (security/dual) | **Excluded from the Go binary. Completed via skill prompt instructions** | review decisions are made by the LLM. Go does not need to own it |
| D7 | External dependencies | **Only uuid permitted. Everything else is stdlib** | MCP/OTel are also implemented in-house with encoding/json + net/http |

## Binary Size Estimate (Revised)

```
Go stdlib minimal:     1.5MB
+ net/http:           +0.5MB
+ encoding/json:       (included)
+ google/uuid:        +0.1MB
+ ldflags -s -w:      -30%
─────────────────────────────
Expected:              ~2.5MB (darwin/arm64)
```

Total for 5 platforms: ~12MB (the entire bin/ directory)