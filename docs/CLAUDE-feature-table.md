# Claude Code / Codex Feature Table (full upstream snapshot edition)

> **Overview**: A list of the major Claude Code / Codex features and upstream snapshots that Harness leverages and tracks.
> This is the full version of CLAUDE.md's Feature Table (with detailed descriptions).

## Feature list

| Feature | Leveraging skill | Purpose |
|------|-----------|------|
| **Phase 89 session coordination (file lease + register + broadcast revival)** | hooks, breezing, harness-work | `A: implemented`. Feeds `.go`/`.md`/`.sh` edit conflicts back to the model via `continueOnBlock` across multiple CC sessions on the same PC and same repo. `go/internal/hookhandler/session_lease.go` (sha256-hex-named lock under `git --git-common-dir` + `os.Link` create-only + (TTL AND active.json) stale detection + 24h auto-prune + worktree shared store), `session_register.go` (register/deregister in active.json on SessionStart/Stop + tri-state), `file_lease_hook.go` (PreToolUse silent acquire + PostToolUse `permissionDecision:"deny"` + `continueOnBlock:true` + 8-char holder prefix + sanitized path), `inbox_check.go` (structured fields only + 4096B cap + ANSI/NUL stripping + `userprompt-inject-policy` disclaimer), `session_auto_broadcast.go` (revived from 2026-02 dead code via `.go`/`.md`/`.sh` extension match using `filepath.Ext`, debug-visible with `*<ext>` label). Wired to PreToolUse/PostToolUse/SessionStart/Stop via `hooks/hooks.json` + `.claude-plugin/hooks.json` dual-sync. `continueOnBlock` is diagnostic feedback (not an R01-R13 guard rail, consistent with `hooks-2.1.139-plus.md` §3). Independent of harness-mem = same-PC only, not shared across separate clones. |
| **Phase 80 Claude Code 2.1.143-2.1.152 + Codex 0.131-0.134 upstream refresh** | upstream-update, hooks, skill-editing, setup, codex, harness-plan | `A: implemented / C: auto-inherited / P: tracked in Plans / Reject: unverified claim (B: 0)`. Connects `docs/upstream-update-snapshot-2026-05-27.md` + `docs/upstream-adoption-plan-2026-05-27.md` to Plans `80.1.1`-`80.1.6`. Claude: `disallowed-tools`, `/reload-skills`, `SessionStart.reloadSkills`, `MessageDisplay` opt-in policy, `/code-review` rename, `claude agents --json`, Auto mode consent removal (Harness default retained). Codex: `--profile` primary, curl/PowerShell installer docs, MCP environment/OAuth (defer), read-only MCP parallelism (inherit). |
| **Phase 69 Claude Code 2.1.133-2.1.142 follow-up adoption** | upstream-update, hooks, guardrails, agents, harness-plan, harness-work | `A: implemented / C: auto-inherited / P: tracked in Plans (B: 0)`. Decomposes `docs/upstream-update-snapshot-2026-05-15.md` into Tier 1 (5 items: explicit `worktree.baseRef` template / hooks `$CLAUDE_EFFORT` rule / `autoMode.hard_deny` baseline of 7 / hook `args` exec form + `continueOnBlock` + SessionStart command-only rules / hook `terminalSequence` opt-in implementation) + Tier 2 (5 items: policy that CC native `/goal` also follows the Plans.md SSOT / `claude agents` agent-view policy + usage conditions for 9 flags / Worker expectation for retaining background permission mode / positioning `claude plugin details` as CI auxiliary info / Phase 69 rule SSOT). Adds `.claude/rules/hooks-2.1.139-plus.md` and `docs/agent-view-policy.md`, adds `worktree.baseRef: "fresh"` / `autoMode.hard_deny` as baseline to `templates/claude/settings.security.json.template` (manual merge into `.claude-plugin/settings.json` is a release-operator task because of the self-write guardrail), and via `scripts/lib/terminal-notify.sh` has `webhook-notify.sh` and `notification-handler.sh` emit `terminalSequence` under the `HARNESS_TERMINAL_NOTIFY` opt-in. |
| **Phase 67 Codex 0.130.0 stable snapshot** | upstream-update, setup, codex, harness-review | `A: verification hardening / C: auto-inherited / P: tracked in Plans (B: 0)`. Connects `docs/upstream-update-snapshot-2026-05-10.md` to Plans `67.1.1`-`67.1.4`, classifying `rust-v0.130.0` stable's `codex remote-control`, plugin-bundled hooks, plugin sharing metadata, app-server Thread pagination APIs, Bedrock `aws login`, selected-environment `view_image`, live threads from latest config snapshot, turn diffs after `apply_patch`, ThreadStore summaries/resume/fork, `response.processed`, Windows sandbox runtime bin cache, `cargo install --locked`, OTel trace metadata, built-in MCPs, and `CODEX_HOME` environments TOML provider into A/C/P. |
| **Phase 62 Claude Code 2.1.112-2.1.132 follow-up adoption + Opus 4.7 follow-up** | upstream-update, harness-loop, breezing, harness-review, guardrails, hooks | `A: verification hardening / C: auto-inherited (B: 0)`. Connects `docs/upstream-update-snapshot-2026-05-07.md` to Plans `62.1.1`-`62.3.1`. Tier 1: two-layer subagent stall defense (CC 600s + elicitation-handler), `ENABLE_PROMPT_CACHING_1H` 1h cache opt-in for long-running, hooks `type: "mcp_tool"` adoption decision (= hold), `sandbox.network.deniedDomains` baseline expansion (template canonical 9 items), R06/R11/R12 wrapper bypass test (env/sudo/watch × 3 = 9 cases). Tier 2: `PostToolUse.updatedToolOutput` opt-in handler + audit, agent permissionMode reaffirmation (Phase 59.2.3 policy gate), `skill_activated.invocation_trigger` privacy-first telemetry, `CLAUDE_CODE_SESSION_ID` env policy (4 paths), `skillOverrides` 3-mode governance. |
| **Phase 61 Sandbagging-Aware Weak-Supervision Harness** | harness-review, harness-loop, harness-mem | Connects to `docs/sandbagging-aware-weak-supervision.md` and `docs/weak-supervision-elicitation-snapshot-2026-05-06.md`. Records faked successes, weak grading, and counterexamples via `weak-supervision-report.v1` / `elicitation-event.v1` / `.claude/state/elicitation/events.jsonl`, used for Advisor cues and Reviewer detection. Advisor stays on `PLAN/CORRECTION/STOP`, Reviewer stays on the final verdict. |
| **Issue #105 English default + Japanese opt-in CI gate** | setup, harness-work, CI | New distribution surfaces default to English while Japanese opt-in UX, bilingual skill metadata, setup rendering, and mirror consistency are locked by the i18n regression suite. |
| **Phase 58 Claude Code 2.1.120-2.1.126 / Codex 0.125.0-0.128.0 snapshot** | upstream-update, harness-review, setup, codex | `A: verification hardening / P: tracked in Plans`. Connects `docs/upstream-update-snapshot-2026-05-03.md` and `docs/upstream-followups-phase58-2026-05-03.md` to Plans `58.1.1`-`58.3.2`, classifying Claude Code `--dangerously-skip-permissions`, `PostToolUse.updatedToolOutput`, MCP `alwaysLoad`, `claude plugin prune`, `claude project purge`, Codex permission profiles, `codex exec --json` reasoning tokens, plugin-bundled hooks, `/goal`, MultiAgentV2, and `0.129.0-alpha.2` watch status into A/C/P, then splitting runtime implementation into follow-up tasks for protected path taxonomy / output governance / Codex profile migration. |
| **Phase 56 Claude Code 2.1.119 / Codex 0.124.0 snapshot** | upstream-update, harness-review, setup | `A: verification hardening`. Connects `docs/upstream-update-snapshot-2026-04-25.md` and `docs/upstream-followups-phase56-2026-04-25.md` to Plans `56.1.1`-`56.2.4`, classifying `--print` frontmatter parity, `PostToolUse.duration_ms`, status line effort/thinking, `prUrlTemplate`, Codex stable hooks, multi-environment app-server, and `0.125.0-alpha.2` watch status into A/C/P, and locking statusline tracking and docs-only safe defaults with tests. |
| **Task tool metrics** | parallel-workflows | Aggregates subagent tokens/tools/time |
| **`/debug` command** | troubleshoot | Diagnosing complex session problems |
| **PDF page ranges** | notebookLM, harness-review | Efficient handling of large documents |
| **Git log flags** | harness-review, CI, harness-release | Structured commit analysis |
| **OAuth authentication** | codex-review | Configuring MCP servers that don't support DCR |
| **68% memory optimization** | session-memory, session | Aggressive use of `--resume` |
| **Subagent MCP** | task-worker | MCP tool sharing during parallel execution |
| **Reduced Motion** | harness-ui | Accessibility settings |
| **TeammateIdle/TaskCompleted Hook** | breezing | Automating team monitoring |
| **Agent Memory (memory frontmatter)** | task-worker, code-reviewer | Persistent learning |
| **Fast mode (Opus 4.6)** | all skills | High-speed output mode |
| **Automatic memory recording** | session-memory | Automatic persistence of cross-session knowledge |
| **Skill budget scaling** | all skills | Auto-adjusts to 2% of the context window |
| **Task(agent_type) restriction** | agents/ | Restricting subagent types |
| **Plugin settings.json** | setup | Reducing init tokens / immediate security protection |
| **Worktree isolation** | breezing, parallel-workflows | Safe parallel writes to the same file |
| **Background agents** | generate-video | Asynchronous scene generation |
| **ConfigChange hook** | hooks | Configuration-change auditing |
| **last_assistant_message** | session-memory | Session quality assessment |
| **Sonnet 4.6 (1M context)** | all skills | Large-scale context processing |
| **Memory leak fixes (v2.1.50–v2.1.63)** | breezing, work | Improved stability of long-running team sessions |
| **`claude agents` CLI (v2.1.50)** | troubleshoot | Diagnosing/checking agent definitions |
| **WorktreeCreate/Remove hook (v2.1.50)** | breezing | Automatic Worktree lifecycle setup/cleanup (implemented) |
| **`claude remote-control` (v2.1.51)** | investigated / future support | Serving external builds and local environments |
| **`/simplify` (v2.1.63)** | work | Phase 3.5 Auto-Refinement: automatic code refinement after implementation |
| **`/batch` (v2.1.63)** | breezing | Delegating parallel migration of horizontally-spread tasks |
| **`code-simplifier` plugin** | work | Deep refactoring during `--deep-simplify` |
| **HTTP hooks (v2.1.63)** | hooks | Provides a JSON POST template. TaskCompleted notifications are enabled when `HARNESS_WEBHOOK_URL` is set |
| **Auto-memory worktree sharing (v2.1.63)** | breezing | Memory sharing between worktree agents |
| **`/clear` skill cache reset (v2.1.63)** | troubleshoot | Diagnosing cache problems during skill development |
| **`ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)** | setup | Option to disable claude.ai MCP servers |
| **Effort levels + ultrathink (v2.1.68)** | harness-work | Auto-injects ultrathink for complex tasks via multi-factor scoring |
| **Agent hooks (v2.1.68)** | hooks | LLM agent code quality guard via type: "agent" |
| **Opus 4/4.1 removal (v2.1.68)** | — | Removed from the first-party API. Auto-migrated to Opus 4.6 |
| **`${CLAUDE_SKILL_DIR}` variable (v2.1.69)** | all skills | Resolves reference paths inside a skill independent of the execution environment |
| **InstructionsLoaded hook (v2.1.69)** | hooks | Tracks the pre-session instructions-loaded event |
| **`agent_id` / `agent_type` added (v2.1.69)** | hooks, breezing | Stabilizes teammate identification / role determination |
| **`{"continue": false}` teammate response (v2.1.69)** | breezing | Enables automatic stop when all tasks are complete |
| **`/reload-plugins` (v2.1.69)** | all skills | Immediate reflection after editing skills/hooks |
| **`includeGitInstructions: false` (v2.1.69)** | work, breezing | Token reduction when git instructions are unnecessary |
| **`git-subdir` plugin source (v2.1.69)** | setup, release | Supports plugin sources managed in a subdirectory |
| **Auto Mode (RP Phase 1)** | breezing, work | CC native feature. Harness side only does PermissionDenied tracking. Decision logic not implemented. Current default is `bypassPermissions` |
| **Per-agent hooks (v2.1.69+)** | agents/ | Adds a `hooks` field to agent-definition frontmatter. Sets a PreToolUse guard on Worker and a Stop log on Reviewer |
| **Agent `isolation: worktree` (v2.1.50+)** | agents/worker | Adds `isolation: worktree` to the Worker agent definition. Automatic worktree separation during parallel writes |
| **Compaction image retention (v2.1.70)** | notebookLM, harness-review | Retains images in summary requests. Improves prompt-cache reuse |
| **Subagent final-report simplification (v2.1.70)** | breezing, harness-work | Reduces token consumption of subagent completion reports |
| **`--resume` skill-list re-injection removal (v2.1.70)** | session | Saves ~600 tokens on session resume |
| **Plugin hooks fix (v2.1.70)** | hooks | Stop/SessionEnd fire after /plugin, template collisions resolved, WorktreeCreate/Remove work correctly |
| **Additional teammate nesting prevention fix (v2.1.70)** | breezing | An additional nesting-prevention fix on top of the v2.1.69 change |
| **PostToolUseFailure hook (v2.1.70)** | hooks | New hook event that fires when a tool call fails |
| **`/loop` + Cron scheduling (v2.1.71)** | breezing, harness-work | `/loop 5m <prompt>` for periodic execution. Leveraged for automatic monitoring of task progress |
| **Background Agent output path fix (v2.1.71)** | breezing, parallel-workflows | Completion notifications include the output file path. Results are recoverable even after compaction |
| **`--print` team-agent hang fix (v2.1.71)** | CI integration | Fixes team-agent hangs in `--print` mode |
| **Plugin install parallel-execution fix (v2.1.71)** | breezing | Stabilizes plugin state across multiple instances |
| **Marketplace improvements (v2.1.71)** | setup | @ref parser fix, update merge conflict fix, MCP server deduplication, /plugin uninstall uses settings.local.json |
| **Subagent `background` field (v2.1.71+)** | breezing, parallel-workflows | Adds `background: true` to an agent definition. Always runs as a background task |
| **Subagent `local` memory scope (v2.1.71+)** | agents/ | `memory: local` saves to `.claude/agent-memory-local/`. Isolates sensitive learning not committed to VCS |
| **Agent Teams experimental flag (v2.1.71+)** | breezing | Enables Agent Teams via the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable. Officially documented |
| **`/agents` command (v2.1.71+)** | troubleshoot, setup | Interactive agent management UI. Create/edit/delete/list via GUI |
| **Desktop Scheduled Tasks (v2.1.71+)** | harness-work | CC native feature. No Harness-side default configuration (the CronCreate tool is available) |
| **`CronCreate/CronList/CronDelete` tools (v2.1.71+)** | breezing, harness-work | Internal tools for `/loop`. Create/manage periodic tasks within a session |
| **`CLAUDE_CODE_DISABLE_CRON` environment variable (v2.1.71+)** | setup | `=1` disables the Cron scheduler. For environments that restrict periodic execution by security policy |
| **`--agents` CLI flag (v2.1.71+)** | breezing, CI | Passes session-level agent definitions as JSON. Ephemeral agent configuration not saved to disk |
| **`ExitWorktree` tool (v2.1.72)** | breezing, harness-work | Tool to programmatically leave a worktree session |
| **Effort levels simplification (v2.1.72)** | harness-work | Removes `max`, three tiers `low/medium/high` + `○ ◐ ●` symbols. `/effort auto` resets to default |
| **Agent tool `model` parameter revived (v2.1.72)** | breezing | Per-invocation model override is available again |
| **`/plan` description argument (v2.1.72)** | harness-plan | Enter plan mode with a description, like `/plan fix the auth bug` |
| **Parallel tool-call fix (v2.1.72)** | breezing, harness-work | Read/WebFetch/Glob failures no longer cancel sibling calls (only Bash errors cascade) |
| **Worktree isolation fix (v2.1.72)** | breezing | cwd restoration on Task resume, background notifications include worktreePath |
| **`/clear` background-agent retention (v2.1.72)** | breezing | `/clear` stops only foreground tasks. Background agents survive |
| **Hooks fixes (v2.1.72)** | hooks | transcript_path fix, PostToolUse double-display fix, async hooks stdin fix, skill hooks double-fire fix |
| **HTML comment hiding (v2.1.72)** | all skills | CLAUDE.md `<!-- -->` is hidden on auto-injection. Still visible via the Read tool |
| **Bash auto-approval additions (v2.1.72)** | guardrails | `lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind` added to the allowlist |
| **Prompt cache fix (v2.1.72)** | all skills | Fixes cache invalidation in the SDK `query()`. Up to 12× reduction in input token cost |
| **Output Styles (v2.1.72+)** | all skills | Define custom output styles in `.claude/output-styles/`. `harness-ops` provides structured Plan/Work/Review output |
| **`permissionMode` in agent frontmatter (v2.1.72+)** | agents/ | Explicitly declare `permissionMode` in agent-definition YAML. No `mode` specification needed at spawn time |
| **Agent Teams official best practices (v2.1.72+)** | breezing | Reflects 5-6 tasks/teammate guideline, `teammateMode` setting, and plan-approval patterns into team-composition |
| **Sandboxing (`/sandbox`)** | breezing, harness-work | OS-level filesystem/network isolation. A complementary layer to `bypassPermissions` |
| **`opusplan` model alias** | breezing | Auto-switches to Opus for planning and Sonnet for execution. Ideal for the Lead's Plan → Execute flow |
| **`CLAUDE_CODE_SUBAGENT_MODEL` environment variable** | breezing, harness-work | Sets subagent models in bulk. Centralizes Worker/Reviewer model control |
| **`availableModels` setting** | setup | A restriction list of available models. Model governance for enterprise operations |
| **Checkpointing (`/rewind`)** | harness-work | Track/rewind/summarize session state. Supports safe exploration and experimentation |
| **Code Review (managed service)** | harness-review | Multi-agent PR review + `REVIEW.md`. Research Preview for Teams/Enterprise |
| **Status Line (`/statusline`)** | all skills | A status bar via a custom shell script. Continuously monitors context usage, cost, and git state |
| **1M Context Window (`sonnet[1m]`)** | harness-review, breezing | Leverages the 1-million-token context window for large-codebase analysis |
| **Per-model Prompt Caching Control** | all skills | Per-model cache control via `DISABLE_PROMPT_CACHING_*`. Debugging / cost optimization |
| **`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`** | harness-work | Disables Adaptive Reasoning to return to a fixed thinking budget. Predictable cost control |
| **Chrome Integration (`--chrome`, beta)** | harness-work, harness-review | UI testing, form filling, and console debugging via browser automation. Switch within a session with `/chrome` |
| **LSP server integration (`.lsp.json`)** | setup | CC native feature. No Harness-side `.lsp.json` default (configure individually with `/setup lsp`) |
| **`SubagentStart`/`SubagentStop` matcher (v2.1.72+)** | breezing, hooks | Monitor subagent lifecycle per agent type at the settings.json level. Track Worker/Reviewer/Scaffolder/Video Generator individually |
| **Agent Teams: Task Dependencies** | breezing | Automatic management of inter-task dependencies. Blocked tasks auto-unblock when dependencies complete. File locks prevent claiming contention |
| **`--teammate-mode` CLI flag (v2.1.72+)** | breezing | Switch `in-process`/`tmux` display mode per session. `claude --teammate-mode in-process` |
| **`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` (v2.1.72+)** | setup | `=1` disables all background-task functionality. For environments that restrict background execution by security policy |
| **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (v2.1.72+)** | breezing, harness-work | Adjusts the subagent auto-compaction threshold (default 95%). `50` for early compaction, improving stability of long-running Workers |
| **`cleanupPeriodDays` setting (v2.1.72+)** | setup | Automatic cleanup period for subagent transcripts (default 30 days) |
| **`/btw` side question (v2.1.72+)** | all skills | A short question while retaining the current context. No tool access, not kept in history. A lightweight alternative to spawning a subagent |
| **Plugin CLI commands (v2.1.72+)** | setup | `claude plugin install/uninstall/enable/disable/update` + `--scope` flag. Supports script-based automation |
| **Remote Control enhancements (v2.1.72+)** | investigated / future support | Enable within a session via `/remote-control` (`/rc`). `--name`, `--sandbox`, `--verbose` flags. `/mobile` shows a QR code. Auto-reconnect supported |
| **`skills` field in agent frontmatter (v2.1.72+)** | agents/ | Preloads skills into a subagent. Injects `harness-work`+`harness-review` into Worker, `harness-review` into Reviewer, `harness-setup`+`harness-plan` into Scaffolder (implemented) |
| **`modelOverrides` setting (v2.1.73)** | setup, breezing | Maps model-picker entries to custom-provider model IDs such as Bedrock ARNs |
| **`/output-style` deprecation (v2.1.73)** | all skills | Migrated to `/config`. Output-style selection integrated into the config menu |
| **Bedrock/Vertex Opus 4.6 default (v2.1.73)** | breezing | Cloud-provider default Opus updated from 4.1 → 4.6 |
| **`autoMemoryDirectory` setting (v2.1.74)** | session-memory, setup | Customizes the auto-memory save path. Supports project-specific memory isolation |
| **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)** | hooks | Makes the SessionEnd hook timeout configurable (previously a fixed 1.5s kill) |
| **Full model ID fix (v2.1.74)** | agents/, breezing | Full model IDs like `claude-opus-4-6` are now recognized in agent frontmatter / JSON config |
| **Streaming API memory leak fix (v2.1.74)** | breezing, harness-work | Fixes unbounded RSS growth of the streaming response buffer |
| **`--remote` / Cloud Sessions** | breezing, harness-work | Launch cloud sessions from the terminal with `--remote`. Asynchronous task execution |
| **`/teleport` (`/tp`)** | session | Pull a cloud session into a local terminal |
| **`CLAUDE_CODE_REMOTE` environment variable** | hooks, session-env-setup | Detects cloud vs. local execution. Used for conditional branching in hooks |
| **`CLAUDE_ENV_FILE` SessionStart persistence** | hooks, session-env-setup | Persists environment variables from a SessionStart hook to subsequent Bash commands |
| **Slack Integration (`@Claude`)** | — | Future support (assumes Teams/Enterprise). No Harness-side implementation |
| **Server-managed settings (public beta)** | setup | Bulk settings management via server delivery. For Teams/Enterprise |
| **Microsoft Foundry** | setup, breezing | Added as a new cloud provider |
| **`PreCompact` hook** | hooks | Save state before context compaction and warn about WIP tasks (implemented) |
| **`Notification` hook event** | hooks | Custom handler when a notification fires (implemented) |
| **`/context` command (v2.1.74)** | all skills | Visualizes context consumption and suggests optimizations |
| **`maxTurns` agent safety limit** | agents/ | Runaway prevention via turn cap. Worker: 100, Reviewer: 50, Scaffolder: 75 |
| **Output token limits 64k/128k (v2.1.77)** | all skills | Opus 4.6 / Sonnet 4.6 default 64k, max 128k tokens |
| **`allowRead` sandbox setting (v2.1.77)** | harness-review | Re-permit reads of specific paths within `denyRead` |
| **PreToolUse `allow` respects `deny` (v2.1.77)** | guardrails | Hook `allow` does not override settings.json `deny` |
| **Agent `resume` → `SendMessage` (v2.1.77)** | breezing | Agent tool `resume` removed, migrated to `SendMessage({to: agentId})` |
| **`/branch` (formerly `/fork`) (v2.1.77)** | session | `/fork` → `/branch` rename. Alias retained |
| **`claude plugin validate` enhancement (v2.1.77)** | setup | Adds frontmatter + hooks.json syntax validation |
| **`--resume` 45% faster (v2.1.77)** | session | Faster resume and reduced memory for fork-heavy sessions |
| **Stale worktree conflict fix (v2.1.77)** | breezing | Prevents accidental deletion of active worktrees |
| **`StopFailure` hook event (v2.1.78)** | hooks | Captures session-stop failures on API errors |
| **`${CLAUDE_PLUGIN_DATA}` variable (v2.1.78)** | hooks, setup | A state directory that persists across plugin updates |
| **Agent `effort`/`maxTurns`/`disallowedTools` frontmatter (v2.1.78)** | agents/ | Declarative control of plugin agents |
| **`deny: ["mcp__*"]` fix (v2.1.78)** | setup | Correctly block MCP tools with settings.json deny |
| **`ANTHROPIC_CUSTOM_MODEL_OPTION` (v2.1.78)** | setup | Custom model-picker entry |
| **`--worktree` skills/hooks loading fix (v2.1.78)** | breezing | Correctly loads skills/hooks when the worktree flag is set |
| **Skill `effort` frontmatter (v2.1.80)** | harness-work, harness-review, harness-plan, harness-release | Gives the 5-verb skills their own thinking budget, raising the initial-move quality of heavy flows |
| **Agent `initialPrompt` frontmatter (v2.1.83)** | agents/ | Stabilizes the first turn of Worker / Reviewer / Scaffolder per role |
| **`sandbox.failIfUnavailable` (v2.1.83)** | setup, guardrails | Prevents silently falling back to unsandboxed when sandbox startup fails |
| **`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` (v2.1.83)** | hooks, setup | Shrinks the credential-leak surface to hook / Bash / MCP stdio subprocesses |
| **`TaskCreated` / `CwdChanged` / `FileChanged` hooks (v2.1.83-2.1.84)** | hooks, session | Adds reactive state tracking and Plans / rule re-read reminders |
| **Rules / skills `paths:` YAML list (v2.1.84)** | setup, localize-rules | Holds multiple globs in a structured form, making rule scope readable and harder to break |
| **Hooks conditional `if` field (v2.1.85)** | hooks, guardrails | Narrows `PermissionRequest` to only safe Bash and edit operations, reducing unnecessary hook firing and false warnings |
| **Large session truncation fix (v2.1.78)** | session | Fixes truncation of sessions over 5MB |
| **`--console` auth flag (v2.1.79)** | setup | Anthropic Console API billing authentication |
| **Turn duration display (v2.1.79)** | all skills | Toggle turn execution-time display in `/config` |
| **`CLAUDE_CODE_PLUGIN_SEED_DIR` multi-support (v2.1.79)** | setup | Specify multiple seed directories |
| **SessionEnd hooks `/resume` fix (v2.1.79)** | hooks | Correctly fires SessionEnd on interactive session switch |
| **18MB startup memory reduction (v2.1.79)** | all skills | Reduces startup memory usage |
| **MCP tool description cap 2KB (v2.1.84)** | all skills | Prevents context bloat from huge OpenAPI-derived MCP schemas. CC auto-inherited |
| **`TaskCreated` hook blocking (v2.1.84)** | hooks | Hook fires with a synchronous block on TaskCreate. Runtime-reactive, leveraged for state tracking |
| **Idle-return prompt 75min (v2.1.84)** | session | Suggests `/clear` after being away 75+ minutes. Prevents token waste from stale sessions. CC auto-inherited |
| **`X-Claude-Code-Session-Id` header (v2.1.86)** | setup | Adds a session ID header to API requests. Usable for proxy-side aggregation. CC auto-inherited |
| **Cowork Dispatch fix (v2.1.87)** | breezing | Fixes message delivery in Cowork Dispatch. CC auto-inherited |
| **`PermissionDenied` hook event (v2.1.89)** | hooks, breezing | Fires when the auto-mode classifier denies. `{retry:true}` induces a retry. Implemented for Breezing Worker denial tracking / Lead notification |
| **`"defer"` permission decision (v2.1.89)** | hooks, breezing | Returning `"defer"` from PreToolUse pauses a headless session → re-evaluated on resume. A safety valve for Breezing |
| **`updatedInput` + `AskUserQuestion` (v2.1.89+)** | hooks | In headless environments, an external UI / explicit answer source collects question answers, canonicalizes only known synonyms to option labels, and returns `updatedInput.answers`. A: implemented (`ask-user-question-normalize`) |
| **Hook output >50K disk save (v2.1.89)** | hooks | Saves large hook output to disk + preview. Prevents context bloat |
| **Hooks `if` compound command fix (v2.1.89)** | hooks | Fixes compound commands like `ls && git push` or `FOO=bar git push` so they match `if` conditions. CC auto-inherited |
| **Autocompact thrash loop fix (v2.1.89)** | all skills | Emits an actionable error and stops on 3 consecutive compact→immediate-refill cycles. CC auto-inherited |
| **Nested CLAUDE.md re-injection fix (v2.1.89)** | all skills | Fixes a bug where CLAUDE.md was re-injected dozens of times in long sessions. CC auto-inherited |
| **Thinking summaries default off (v2.1.89)** | all skills | Stops default generation of thinking summaries. Restore with `showThinkingSummaries:true`. CC auto-inherited |
| **PreToolUse exit 2 JSON fix (v2.1.90)** | hooks, guardrails | Fixes block behavior with JSON stdout + exit 2. pre-tool.sh deny works more reliably |
| **PostToolUse format-on-save fix (v2.1.90)** | hooks | Fixes Edit/Write failures after a PostToolUse hook rewrites a file. CC auto-inherited |
| **`--resume` prompt-cache miss fix (v2.1.90)** | session | Fixes a regression since v2.1.69. Resume cache misses when using deferred tools/MCP/agents. CC auto-inherited |
| **SSE/transcript performance (v2.1.90)** | all skills | SSE frames O(n²)→O(n), transcript writes quadratic→linear. CC auto-inherited |
| **`/powerup` interactive lessons (v2.1.90)** | — | Animated demos for learning Claude Code features. CC auto-inherited |
| **MCP `maxResultSizeChars` 500K (v2.1.91)** | hooks, setup | Expands the max size of MCP tool results up to 500K via `_meta["anthropic/maxResultSizeChars"]`. Usable for large harness-mem results |
| **`disableSkillShellExecution` setting (v2.1.91)** | setup, guardrails | Disables shell execution within skills. A setting for high-security environments |
| **Plugin `bin/` directory (v2.1.91)** | setup | Plugins can bundle compiled binaries in a `bin/` directory. A candidate for future distribution-format expansion |
| **Transcript chain breaks fix (v2.1.91)** | session | Fixes transcript breaks on `--resume`. CC auto-inherited |
| **Subagent spawning fix (v2.1.92)** | breezing | Fixes "Could not determine pane count". Improves Breezing stability. CC auto-inherited |
| **`forceRemoteSettingsRefresh` (v2.1.92)** | — | Fail-closed remote settings for Teams/Enterprise. CC auto-inherited |
| **`/usage` usage / cost / stats view (v2.1.92, v2.1.118 refresh)** | all skills | Treats `/usage` as the entry point for usage, cost, and stats. Legacy `/cost` / `/stats` are CC-auto-inherited as shortcuts that open the related tab |
| **Linux `apply-seccomp` helper (v2.1.92)** | setup | Strengthens sandbox unix-socket blocking. CC auto-inherited |
| **Plugin `skills` field made explicit (v2.1.94)** | setup | Explicitly declare `"skills": ["./"]` in plugin.json. In CC 2.1.94 the skill invocation name is based on frontmatter `name`. A: implemented (plugin.json update) |
| **Monitor tool (v2.1.98)** | breezing/harness-work/ci/deploy/harness-review | Streaming monitoring of stdout for long-running processes. Tracks CI/deploy progress with lower latency and lower token consumption than polling. A: implemented (allowed-tools + operations guide + Feature Table) |

## Phase 44 supplementary table

This supplementary section collects only `2.1.99-2.1.111` and Opus 4.7 so they can be viewed together.

| Feature | Leveraging skill / area | Purpose | Value-add |
|------|-------------------|------|----------|
| **Versions with no public changelog (`2.1.99`, `2.1.100`, `2.1.102`, `2.1.103`, `2.1.104`, `2.1.106`)** | all skills | No explicit follow-up items. Baseline confirmation only | `C: CC auto-inherited` |
| **`/team-onboarding` and the `2.1.101`-series stabilization** | setup, session | Improved onboarding / resume UX | `C: CC auto-inherited` |
| **`PreCompact` hook (v2.1.105)** | hooks, breezing | The foundation of a design that blocks compaction while a long-running Worker executes | `A: explicit follow-up target` |
| **plugin `monitors` manifest (v2.1.105)** | hooks, setup, breezing | Auto-arm monitors on session start / skill invoke | `A: explicit follow-up target` |
| **thinking hint improvement (v2.1.107, v2.1.109)** | all skills | Improved UI hints during long thinking | `C: CC auto-inherited` |
| **`ENABLE_PROMPT_CACHING_1H` (v2.1.108)** | session, work, breezing | Makes a 1-hour prompt cache TTL operable as an opt-in | `A: explicit follow-up target` |
| **recap / built-in slash command discovery (v2.1.108)** | session, all skills | Improved resume quality and slash-command usage | `C: CC auto-inherited` |
| **permission deny re-evaluation fix (v2.1.110)** | hooks, guardrails | Reflects into docs and test perspectives the premise that deny is re-evaluated even after `updatedInput` and mode updates | `A: explicit follow-up target` |
| **UX improvements around `/tui`, focus, recap (v2.1.110)** | session | Improved screen display and remote-client experience | `C: CC auto-inherited` |
| **`xhigh` effort (v2.1.111)** | harness-review, advisor, docs | Adopts the intermediate strength between `high` and `max` as an official target | `A: explicit follow-up target` |
| **`/ultrareview` (v2.1.111)** | harness-review, docs | Clarifies the roles of cloud multi-agent review and `/harness-review` | `A: explicit follow-up target` |
| **Auto mode no longer requires `--enable-auto-mode` (v2.1.111)** | docs, guardrails | Updates the Auto Mode premise wording away from dependence on the old enable flag | `A: explicit follow-up target` |
| **`/effort` slider and model picker integration (v2.1.111)** | harness-review, docs | Makes effort easier to adjust mid-conversation | `A: explicit follow-up target` |
| **read-only bash permission prompt relaxation (v2.1.111)** | guardrails, docs | Updates the premise that prompt firing decreases for safe read-only commands | `C: CC auto-inherited` |

### Opus 4.7 section

| Feature | Leveraging skill / area | Purpose | Value-add |
|------|-------------------|------|----------|
| **literal instruction following** | agents, skills, docs | Reduces ambiguous expressions and makes instructions and stop conditions concrete | `A: explicit follow-up target` |
| **`xhigh` effort** | harness-review, advisor, docs | Raises thinking a notch only for heavy review / advisory | `A: explicit follow-up target` |
| **task budgets** | docs, future work | Sorts out conflicts with existing `max_consults` / cost controls first | `A: explicit follow-up target` |
| **tokenizer improvement** | all skills | Benefits from token-efficiency improvements | `C: CC auto-inherited` |
| **vision 2576px** | harness-review, docs | Updates the operational upper bound for high-resolution review | `A: explicit follow-up target` |
| **memory improvement** | session-memory, docs | Aligns the explanation of long-running execution and resume with the new premise | `A: explicit follow-up target` |
| **`/ultrareview`** | harness-review, docs | Documents the division of roles with `/harness-review` | `A: explicit follow-up target` |
| **Auto Mode expansion** | docs, guardrails | Drops the enable-flag premise and treats it as a permanent feature | `A: explicit follow-up target` |

| **`context: fork` host CLAUDE.md inheritance spec and auto-start avoidance pattern (Phase 46)** | harness-review | Resolves the issue where a `context: fork` skill runs in an isolated context but is overridden and stopped by the host CLAUDE.md session-start rules. Documents the host CLAUDE.md inheritance spec and auto-start avoidance pattern in `skill-editing.md` (Issue #84). A: implemented (SKILL.md Step 0 hardening + `REVIEW_AUTOSTART` marker contract) | `A: implemented` |

**Note**:
This supplement uses `A` / `C` / `P`, with `B` at `0`.
`A` means "an item Harness is responsible for explicitly following up on", `C` means "an item that inherits Claude Code / Codex core updates as-is", and `P` means "an item not directly implemented this time but tracked in Plans".

## Phase 51 supplementary table

This supplementary section classifies, from the primary sources for Claude Code `2.1.112-2.1.114` and Codex `0.121.0`, only the items to put on Harness.

| Feature | Leveraging skill / area | Purpose | Value-add |
|------|-------------------|------|----------|
| **AskUserQuestion `updatedInput.answers` bridge** | hooks, harness-plan, harness-release | Reads answers explicitly passed in `PreToolUse`, normalizes only known synonyms like `solo/team` or `scripted/exploratory` to option labels, and continues headless dialogue | `A: implemented` (`go/internal/hookhandler/ask_user_question_normalizer.go`, `hooks/hooks.json`, `tests/test-claude-upstream-integration.sh`) |
| **Claude Code 2.1.113 permission / sandbox hardening** | settings, guardrails | Sets `sandbox.network.deniedDomains`, and detects `find -exec` / `-delete` and macOS dangerous rm paths in the Harness guardrail as well | `A: implemented` (`.claude-plugin/settings.json`, `go/internal/guardrail/helpers.go`, `tests/test-claude-upstream-integration.sh`) |
| **Claude Code 2.1.114 permission dialog crash fix** | hooks, team execution | Fixes the permission-dialog crash for Agent Teams teammates | `C: CC auto-inherited` |
| **Claude/Codex upstream update Skills gate** | skills, review | Requires a version-by-version decomposition table before running an upstream update, and syncs the determination of PR-target `skills/` / `codex/.codex/skills/` and local-only `.agents/skills/` | `A: implemented` (`claude-codex-upstream-update`, `cc-update-review`) |
| **Codex 0.121.0 marketplace / MCP Apps / memory controls** | setup, future Codex workflow | Keeps plugin marketplace, MCP Apps tool calls, memory reset / cleanup, and sandbox metadata on Harness's Codex comparison axis | `P: tracked in Plans`. Prioritizes the Claude hardening implementation this time and splits this out to Plans |
| **Codex 0.121.0 secure devcontainer / bubblewrap** | setup, guardrails | Makes the secure devcontainer profile and macOS Unix socket allowlist a future sandbox-policy comparison target | `C: investigated on the Codex side / no Harness change` |
| **Skills mirror full audit** | skills, setup | Inventories `.agents/skills` Claude/Codex substitution drift, the Codex native tool model, memory/session paths, and media-generation metadata | `P: tracked in Plans` (`docs/skills-audit-2026-04-20.md`) |

**Note**:
In Phase 51 too, `B: table-only` is `0`. The large Codex 0.121.0 items are left in Plans as a "Codex comparison axis" rather than directly implemented this time, while Claude Code's `AskUserQuestion.updatedInput` and 2.1.113 hardening are implemented down to settings / Go / tests as `A`.

## Phase 52 supplementary table

This supplementary section classifies, from the primary sources for Claude Code `2.1.116` and Codex `0.122.0` / `0.123.0-alpha.2`, whether to implement directly in Harness or leave as auto-inheritance / tracked in Plans. Details are recorded in `docs/upstream-update-snapshot-2026-04-21.md`.

| Feature | Leveraging skill / area | Purpose | Value-add |
|------|-------------------|------|----------|
| **Claude Code 2.1.116 resume / MCP / plugin updater UX refresh** | session, setup, MCP | Cross-checks `/resume` speedup, MCP startup deferred loading, and plugin dependency auto-install against Harness's session / setup guidance | `C/P: auto-inherited + tracked in Plans`. Adds no Harness wrapper and leaves plugin dependency policy and MCP health watch as follow-up candidates |
| **Claude Code 2.1.116 dangerous-path safety / agent hooks refresh** | guardrails, agents | Cross-checks sandbox auto-allow dangerous-path safety and main-thread `--agent` hook firing against existing guardrail / agent policy | `C/P: auto-inherited + tracked in Plans`. Retains the R05 guardrail and leaves this to an agent frontmatter policy audit |
| **Codex 0.122.0 plugin / Plan Mode / permission model** | codex workflow, setup, sandbox | Classifies `/side`, fresh-context Plan Mode, plugin workflow, deny-read glob, and tool-discovery default-on as Codex mirror improvement candidates | `P: tracked in Plans`. Handled together with the Phase 51.2 Codex-native skill audit |
| **Codex 0.123.0-alpha.2 pre-release** | future compare | Does not speculatively implement a thin-release-body alpha; makes it a re-check target after stabilization | `P: tracked in Plans`. Does not speculatively implement from the compare |
| **Upstream update Skills merge hardening** | skills, review, tests | Makes `cc-update-review` diff-aware, makes `claude-codex-upstream-update` handle no-op adaptation, and adds a mirror drift test | `A: implemented` (`skills/cc-update-review`, `skills/claude-codex-upstream-update`, `tests/test-claude-upstream-integration.sh`) |

**Note**:
In Phase 52 too, `B: table-only` is `0`. UX that Claude / Codex cores naturally improve is `C`, and things that would become a double responsibility if layered onto Harness are `P`, connected to a follow-up Codex-native skill audit / plugin policy. Direct implementation is narrowed to preventing recurrence of review findings, with skill mirror drift and no-op adaptation locked by tests.

## Phase 53 supplementary table

This supplementary section classifies, from the primary sources for Claude Code `2.1.117-2.1.118` and Codex `0.123.0`, whether to implement directly in Harness or leave as auto-inheritance / tracked in Plans. Details are recorded in `docs/upstream-update-snapshot-2026-04-23.md`.

| Feature | Leveraging skill / area | Purpose | Value-add |
|------|-------------------|------|----------|
| **Claude Code `type: "mcp_tool"` hooks** | hooks, MCP diagnostics, tests | Validates a small read-only MCP health / resource diagnostic hook without adding more shell scripts | `A: implemented`. In 53.1.2, the manifest addition is a no-op, and the snapshot records the decision not to put it into distributed hooks until a permanent read-only diagnostic tool and a stable field spec are ready. Not calling write-type MCP tools is locked by `tests/test-claude-upstream-integration.sh` |
| **Claude Code `claude plugin tag`** | harness-release, plugin release | Creates a tag with plugin version validation after confirming sync of `VERSION` and `.claude-plugin/plugin.json` | `A: planned`. Added to the release flow / dry-run / test guidance in 53.1.3 |
| **Auto Mode `"$defaults"` extension** | permissions, sandbox, settings docs | Updates guidance toward a form that adds Harness-specific rules without replacing built-in defaults | `A: implemented`. In 53.1.4, records `"$defaults"` as an additive baseline and locks the reason it does not become a double responsibility with R05 / `deniedDomains` in the snapshot, template, and upstream integration test |
| **Plugin themes / managed settings / dependency auto-resolve** | setup, plugin policy, enterprise docs | Organizes `themes/`, `DISABLE_UPDATES`, `blockedMarketplaces`, `strictKnownMarketplaces`, and dependency hints for managed environments | `A: documented`. In 53.1.5, adds `docs/plugin-managed-settings-policy.md` and states the policy of not layering a Harness-specific resolver. The theme-bundling decision is left as `P` on the snapshot side |
| **Claude Code UX / runtime fixes** | session, agents, MCP, search, effort | Organizes `/usage` integration, `/resume` `/add-dir` support, `--agent` + `mcpServers`, stale session summary, native `bfs` / `ugrep`, and high effort default | `C/P: auto-inherited + tracked in Plans`. In 53.1.6, records in the snapshot the reason for not adding a wrapper, and leaves `--agent` + `mcpServers` and the external forked subagent flag as `P` for an agent audit |
| **Codex 0.123.0 provider / model metadata** | Codex setup, provider policy | Reflects the built-in `amazon-bedrock` provider, AWS profile support, and current `gpt-5.6` default metadata into Codex setup guidance | `A: documented`. In 53.2.1, adds `docs/codex-provider-setup-policy.md` and fixes the policy that the Harness-distributed config does not pin `model` / `model_provider`, and only Bedrock users add them to user / project config |
| **Codex 0.123.0 MCP diagnostics / plugin loading** | troubleshoot, setup, Codex plugin docs | Reflects `/mcp verbose`, diagnostics / resources / resource templates, and the `mcpServers` form and top-level server-map form of `.mcp.json` into setup guidance | `A: documented`. In 53.2.2, adds `docs/codex-mcp-diagnostics.md` and fixes the procedure of using `/mcp` normally and `/mcp verbose` only when in trouble, and the policy of not mixing it with Claude Code-side MCP guidance |
| **Codex 0.123.0 realtime handoff silence** | harness-loop, breezing, long-running | Organizes the frequency of interim reports on the premise that background agents receive transcript deltas and can explicitly stay silent when unnecessary | `A: documented`. In 53.2.3, makes `harness-loop` default to one final report per cycle and `breezing` to one progress feed per task completion, fixing advisor / reviewer drift as out of scope for silence |
| **Codex 0.123.0 sandbox / exec changes** | sandbox, execution policy | Follows `remote_sandbox_config` and `codex exec` shared flags | `A: documented`. In 53.2.4, adds `docs/codex-sandbox-execution-policy.md` and fixes the per-remote-environment sandbox requirement comparison and whether wrapper flag duplication can be reduced |
| **Codex 0.123.0 automatic bug fixes** | Codex long-running UX, session shell, review privacy | Records `/copy` rollback, manual shell follow-up queue, Unicode / dead-key, stale proxy env, VS Code WSL keyboard, and review prompt leak | `C: Codex auto-inherited`. In 53.2.5, states the reason for not adding a workaround |

**Note**:
In Phase 53 too, `B: table-only` is `0`. The Feature Table is kept as an entry point, and the official URLs and version-by-version rationale are consolidated in `docs/upstream-update-snapshot-2026-04-23.md`. `A` connects to concrete Phase 53 tasks, `C` is auto-inheritance of core fixes, and `P` is a future decision that is not speculatively implemented.

At Phase 53 closeout, the broad inventory of Codex mirror / path drift is left to the Phase 51.2 Codex-native skill audit TODO. Phase 53 closes only the concrete reflection of the upstream `0.123.0` diff and does not preempt the Phase 51.2.1-51.2.4 organization of tool model / memory path / mirror path / media metadata.

## Phase 69 supplementary table (Claude Code 2.1.133-2.1.142)

This supplementary section describes how the 10 versions of Claude Code `2.1.133-2.1.142` were classified into Harness implementation / auto-inheritance / hold. For the primary sources and version-by-version rationale, see `docs/upstream-update-snapshot-2026-05-15.md`.

| Feature | Leveraging skill / area | Purpose | Value-add |
|------|-------------------|------|----------|
| **Claude Code `worktree.baseRef` (2.1.133)** | settings, breezing, worker isolation | Explicitly sets the base of `--worktree` / `EnterWorktree` / agent-isolation worktrees to `origin/<default>` (`fresh`) or local `HEAD` (`head`) | `A: implemented` (`templates/claude/settings.security.json.template`). In Phase 69.1.1, the template makes the baseline `fresh` explicit, and a team that wants to bring in unpushed commits can opt into `head` at the project level. The plugin's own `.claude-plugin/settings.json` is manually merged by the release operator due to self-write deny |
| **Claude Code hook `$CLAUDE_EFFORT` env + `effort.level` JSON (2.1.133)** | hooks, observability | Lets a hook handler / Bash subprocess observe the current effort | `A: implemented` (`.claude/rules/hooks-2.1.139-plus.md`). In Phase 69.1.2, documents "observation only allowed, relaxing guard-rail effort is prohibited" |
| **Claude Code `settings.autoMode.hard_deny` (2.1.136)** | settings, guardrails, auto mode | Lets the Auto Mode classifier handle "always deny regardless of allow intent" | `A: implemented` (`templates/claude/settings.security.json.template`). In Phase 69.1.3, aligns the 7 template baseline items (`Bash(sudo:*)` / `Bash(rm -rf:*)` / `Bash(rm -fr:*)` / `Bash(git push -f:*)` / `Bash(git push --force:*)` / `Bash(git reset --hard:*)` / `mcp__codex__*`) with the Harness deny. The plugin's own `.claude-plugin/settings.json` is manually merged by the release operator due to self-write deny |
| **Claude Code `claude agents` agent view (2.1.139-2.1.142)** | agents, breezing, operator workflow | An operator entry point that monitors all CC sessions on one screen. The 9 flags `--cwd`, `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`, `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions` compose a dispatched background session | `A: implemented` (`docs/agent-view-policy.md`, `docs/team-composition.md`, `agents/worker.md`). In Phase 69.2.2, documents the separation from the teammate spawn workflow (breezing skill) and the usage conditions for each flag |
| **Claude Code native `/goal` command (2.1.139)** | harness-plan, harness-work, Codex `/goal` complement | Retains the completion condition across turns | `A: implemented` (`docs/codex-plugin-workflows-policy.md`). In Phase 69.2.1, integrates 3 rules with Codex `/goal`: "limited to a session continuation memo", "does not usurp the Plans.md SSOT", "does not put acceptance criteria only in `/goal`" |
| **Claude Code `claude plugin details <name>` (2.1.139)** | plugin observability, CI aid | Makes the plugin's component breakdown and projected per-session token cost visible | `A: implemented` (`docs/agent-view-policy.md`, `docs/upstream-update-snapshot-2026-05-15.md`). In Phase 69.2.4, positions it as auxiliary info for CI / doctor and documents the response steps for when a plugin exceeds the session budget threshold |
| **Claude Code hook `args: string[]` (exec form, 2.1.139)** | hooks, security, future-proof | Spawns a command directly without going through a shell | `A: implemented` (`.claude/rules/hooks-2.1.139-plus.md`). In Phase 69.1.4, makes a rule of "prefer exec form for path-placeholder-only, keep the existing `command` when shell control is needed" |
| **Claude Code hook `PostToolUse.continueOnBlock` (2.1.139)** | hooks, guardrails | Feeds the hook's rejection reason back to Claude and continues the turn | `A: implemented` (`.claude/rules/hooks-2.1.139-plus.md`). In Phase 69.1.4, makes a rule of "true only for diagnostic feedback, `false` required for R01-R13 / secret / protected config" |
| **Claude Code hook `terminalSequence` (2.1.141)** | hooks, local notification | Fires desktop notification / window title / bell without a controlling terminal | `A: implemented` (`scripts/lib/terminal-notify.sh`, `scripts/hook-handlers/webhook-notify.sh`, `scripts/hook-handlers/notification-handler.sh`). In Phase 69.1.5, implements the `HARNESS_TERMINAL_NOTIFY` (`0` / `bell` / `title` / `osc9` / `notify`) opt-in. Independent of the existing `HARNESS_WEBHOOK_URL` |
| **Claude Code background permission mode retention (2.1.141)** | agents, breezing | A teammate launched with `/bg` / `←←` / `claude agents` retains its launch-time mode | `A: implemented` (`agents/worker.md`, `docs/team-composition.md`). In Phase 69.2.3, documents the expectation that "Worker does not need permission mode re-injection, and even `bypassPermissions` does not override settings.json deny" |
| **Claude Code hook config error (SessionStart/Setup/SubagentStart are command-only, 2.1.142)** | hooks, validation | LLM-type hooks are rejected in bootstrap-stage hooks | `A: implemented` (`.claude/rules/hooks-2.1.139-plus.md`). Within the same rule as Phase 69.1.4, grep-ably states that "SessionStart/Setup/SubagentStart are limited to `type: "command"`" |
| **CC 2.1.142 fast mode Opus 4.7 default + `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE`** | model defaults | Fast mode always runs on Opus 4.7 | `C: CC auto-inherited`. No change needed since Harness already treats Opus 4.7 as the default |
| **CC 2.1.139 MCP stdio receives `CLAUDE_PROJECT_DIR`** | MCP setup | The MCP server can resolve the project dir | `C: CC auto-inherited` |
| **CC 2.1.139 `x-claude-code-agent-id` / `parent-agent-id` headers + OTEL attrs** | OTel | Improves subagent observability | `C: CC auto-inherited` |
| **CC 2.1.141 `claude agents --cwd`** | operator UX | Can scope the session list to a directory | `A: implemented` (`docs/agent-view-policy.md`). In Phase 69.2.2, documents per-project isolated operation |
| **CC 2.1.141 Rewind "Summarize up to here"** | session | Retains intermediate state during context compression | `C: CC auto-inherited`. Consistent with the `/undo` policy in `.claude/rules/commit-safety.md` |
| **CC 2.1.133/2.1.136-2.1.142 runtime bug fixes (parallel session credential race / MCP `/clear` persistence / OAuth refresh / extended thinking redaction / `--resume` underscore / WSL2 image paste / agent color palette / settings hot-reload symlink / spinner amber / numerous plugin/MCP/UX fixes)** | runtime | safety / stability | `C: CC auto-inherited`. Adds no Harness-side wrapper |

**Note**:
In Phase 69 too, `B: table-only` is `0`. The Feature Table is kept as an entry point, and the official URLs and version-by-version rationale are consolidated in `docs/upstream-update-snapshot-2026-05-15.md`. `A` is tied to actual file changes (settings / hooks / rules / docs / scripts), `C` is auto-inheritance of core fixes, and `P` is a future decision that is not speculatively implemented.

## Feature details

### Task tool metrics

Aggregates the number of tokens consumed, tool calls, and execution time of a subagent.
The `parallel-workflows` skill aggregates metrics of multiple subagents and uses them for cost analysis.

```
metrics: {tokens: 40000, tools: 7, duration: 67s}
```

### `/debug` command

A command for session diagnosis. Used to investigate the cause of complex errors or unexpected behavior.
The `troubleshoot` skill launches automatically and diagnoses the problem systematically.

### PDF page range specification

You can specify a page range when reading a large PDF (e.g., `pages: "1-5"`).
Leveraged for document handling in the `notebookLM` skill and large-spec reference in `harness-review`.

### Git log flags

Leverages `git log`'s structured options (`--format`, `--stat`, `--since`, etc.).
Streamlines release-note generation, commit analysis, and change tracking.

### OAuth authentication

OAuth authentication configuration for MCP servers that do not support DCR (Dynamic Client Registration).
Used for Codex CLI connections in the `codex-review` skill.

### 68% memory optimization

Reduced memory usage when resuming a session via the `--resume` flag.
Effective for continuing context in long working sessions.

### Subagent MCP

A subagent launched by the Task tool can share the parent session's MCP tools.
During parallel implementation in `task-worker`, each agent can use the same MCP toolset.

### Reduced Motion

An accessibility setting. An option to reduce motion/animation.
Considered when generating UI in the `harness-ui` skill.

### TeammateIdle/TaskCompleted Hook

Hooks that fire when a Breezing team member goes idle or when a task completes.
Handled by `scripts/hook-handlers/teammate-idle.sh` and `task-completed.sh`.

```json
"TeammateIdle": [{"hooks": [{"type": "command", "command": "...teammate-idle", "timeout": 10}]}],
"TaskCompleted": [{"hooks": [{"type": "command", "command": "...task-completed", "timeout": 10}]}]
```

### Agent Memory (memory frontmatter)

Enables persistent memory via the `memory: project` field in agent-definition YAML.
`task-worker` and `code-reviewer` learn past implementation patterns / failures and solutions across sessions.

### Fast mode (Opus 4.6)

A high-speed output mode toggled with the `/fast` command. Uses the same Opus 4.6 model.
Available in all skills. Effective for reducing wait time on long implementation tasks.

### Automatic memory recording

Automatically persists learned content to a memory file at session end.
Managed by the `session-memory` skill. Automatically restores the previous context in the next session.

### Skill budget scaling

The SKILL.md character budget auto-adjusts to 2% of the context window.
The recommended 500 lines is a guideline. The effective upper bound depends on the model's context-window size.

### Task(agent_type) restriction

Specify `subagent_type` on a Task tool call to restrict the subagent type.
Combined with `agents/` definitions, this guarantees that only the intended agent is launched.

### Plugin settings.json

Pre-define initialization-time settings in the plugin's `settings.json`.
Reduces init token consumption and applies the security policy from the moment a session starts.

### Worktree isolation

Uses `git worktree` to make parallel writes to the same file safe.
Prevents conflicts during parallel implementation by multiple agents in `breezing` and `parallel-workflows`.

### Background agents

Launches background agents asynchronously. Other work can continue without waiting for completion.
Used for parallel generation of multiple scenes in the `generate-video` skill.

### ConfigChange hook

A hook that fires when a config file (`settings.json`, etc.) is changed.
`scripts/hook-handlers/config-change.sh` records and audits the changes.

### last_assistant_message

A feature that lets you reference the last assistant message at session end.
The `session-memory` skill uses it for self-evaluation of session quality.

### Sonnet 4.6 (1M context)

The Sonnet 4.6 model with a context window of up to 1M tokens.
Handles analysis of large codebases and processing of long documents. Available in all skills.

> Note: In the 2.1.69 series, we operate on the assumption that legacy Sonnet 4.5 references are automatically migrated to Sonnet 4.6.

### Memory leak fixes (v2.1.50–v2.1.63)

CC 2.1.50 fixed memory leaks related to LSP diagnostic data, large tool outputs, file history, and shell execution.
Garbage collection of completed tasks was also implemented, greatly improving the stability of long-running team sessions like `/breezing`.
v2.1.63 additionally fixed leaks in MCP reconnection, git root cache, JSON parse cache, Teammate message retention, and shell command prefix cache.
The Harness side already applies its own countermeasures such as JSONL rotation (500→400 lines) and atomic updates.

### `claude agents` CLI (v2.1.50)

`claude agents list` displays a list of registered agents.
Used in the `troubleshoot` skill for diagnosing agent spawn failures.

```bash
claude agents list   # List of registered agents
```

### WorktreeCreate/WorktreeRemove hook (v2.1.50)

Lifecycle hooks that fire on worktree creation and removal.
Used for automatic setup and cleanup in `/breezing` parallel workflows.
Implemented in `scripts/hook-handlers/worktree-create.sh` and `worktree-remove.sh`.

### `claude remote-control` (v2.1.51)

A subcommand that enables serving between external build systems and the local environment.
Has potential future use for cross-session control of Breezing and CI integration.

### `/simplify` (v2.1.63)

An automatic post-implementation code refinement command added in CC 2.1.63.
Integrated as `/work`'s Phase 3.5 Auto-Refinement, it automatically simplifies and tidies code after implementation completes.
Combined with the `code-simplifier` plugin, the `--deep-simplify` option enables deeper refactoring as well.

### `/batch` (v2.1.63)

A command that delegates horizontal-scaling tasks (such as migrations that apply the same change across multiple files) in parallel.
Used together with `/breezing` to have the Breezing team perform bulk migrations in parallel.
Effective for streamlining repetitive work and reducing human error.

### `code-simplifier` plugin

An external plugin responsible for `/simplify`'s deep refactoring mode.
Launched when `--deep-simplify` is specified, it automatically decomposes complex logic, removes unnecessary abstractions, and improves naming.
Regular `/simplify` is lightweight, while `--deep-simplify` performs more thorough refactoring.

### HTTP hooks (v2.1.63)

A new hook type added in CC 2.1.63. In addition to the existing `command` / `prompt` types, an `http` type is now available.
It POSTs JSON to a specified URL and can integrate with external services (Slack, dashboards, metrics collection, etc.).
For details, see the "http Type" section in [.claude/rules/hooks-editing.md](../.claude/rules/hooks-editing.md).

### Auto-memory worktree sharing (v2.1.63)

In CC 2.1.63, Agent Memory is now shared across worktrees when `isolation: "worktree"` is used.
The parallel Implementers of `/breezing` can each work in separate worktrees while referencing and updating the same MEMORY.md.
This enables knowledge sharing among Implementers and prevents duplicate work on the same bug.

### `/clear` skill cache reset (v2.1.63)

A skill cache reset command added in CC 2.1.63.
`/clear` resolves the problem of operating on a stale cache after editing skill files (a frequent issue during skill development).
Already incorporated into the cache-problem diagnosis step of the `troubleshoot` skill.

### `ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)

An environment variable added in CC 2.1.63. Setting it to `false` disables the MCP servers provided by claude.ai.
Intended for environments that want to restrict connections to external MCP servers for security policy reasons.
Already added to the `setup` skill's environment initialization checklist.

### Agent hooks (v2.1.68)

A `type: "agent"` hook added in CC 2.1.68. By having an LLM agent make hook decisions, it can dynamically judge code quality issues that are hard to detect with regular expressions.
Harness adopts it in only 3 places and, for cost management, narrows the target with `model: "haiku"` and a `matcher`:

- **PreToolUse Write|Edit**: Guards against embedded secrets, TODO stubs, and security vulnerabilities
- **Stop**: WIP task residue guard (checks that no `cc:WIP` tasks remain in Plans.md)
- **PostToolUse Write|Edit**: Asynchronous code review (quality, naming, single responsibility)

Designed to be rollback-able to the `command` type if it proves insufficiently effective.

### Effort levels + ultrathink (v2.1.68)

In CC 2.1.68, Opus 4.6 changed the default to **medium effort**. The `ultrathink` keyword enables high effort (extended thinking) for a single turn only.
The `harness-work` skill computes a score via multi-factor scoring (number of changed files, target directory, keywords, failure history, explicit PM designation), and at a threshold of 3 or higher, automatically injects `ultrathink` at the top of the Worker spawn prompt.
For details, see the "Effort level control" section of `skills/harness-work/SKILL.md`.

### Opus 4/4.1 removal (v2.1.68)

In CC 2.1.68, Opus 4 and Opus 4.1 were removed from the first-party API. If Harness specifies the equivalent of `model: opus` for a target agent, it is automatically migrated to Opus 4.6.
The Worker/Reviewer agents use `model: sonnet`, so they are unaffected. Only the Lead (when using Opus) receives the change of medium effort becoming the default.

### `${CLAUDE_SKILL_DIR}` variable (v2.1.69)

CC 2.1.69 introduced `${CLAUDE_SKILL_DIR}`, a base path variable for skill execution.
In Harness, links that reference `references/*.md` from `SKILL.md` are unified to `${CLAUDE_SKILL_DIR}/references/...`, keeping the same references in mirror configurations (codex) as well.

### InstructionsLoaded hook (v2.1.69)

CC 2.1.69 added the `InstructionsLoaded` event. In Harness, we newly created
`scripts/hook-handlers/instructions-loaded.sh` and use it for lightweight tracking and pre-validation when instructions finish loading.

### `agent_id` / `agent_type` added (v2.1.69)

`agent_id` / `agent_type` were added to Teammate-related events.
The Harness guardrail was extended from a `session_id`-based premise to prioritizing `agent_id` (fallback: `session_id`), stabilizing role guards.

### `{"continue": false}` teammate response (v2.1.69)

It became possible to return `{"continue": false, "stopReason": "..."}` in `TeammateIdle` / `TaskCompleted`.
In Harness, we return the same response upon receiving a stop request and when all tasks are complete, making the breezing stop decision explicit.

### `/reload-plugins` (v2.1.69)

To apply skill/hook edits without restarting the session, `/reload-plugins` was added to the development flow.
The standard procedure is edit → `/reload-plugins` → re-run.

### `includeGitInstructions: false` (v2.1.69)

For tasks that don't need git instructions embedded at all times, `includeGitInstructions: false` can be applied to reduce token consumption.
In Harness, we recommend using it for lightweight breezing/work tasks (documentation updates, etc.).

### `git-subdir` plugin source (v2.1.69)

The `git-subdir` method for managing a plugin source in a monorepo subdirectory is now supported.
Harness currently does not force additional fields in `.claude-plugin/plugin.json`, and operates by explicitly specifying the `plugin source` at release time (prioritizing compatibility).

### Compaction image retention (v2.1.70)

In CC 2.1.70, the summary request now retains images during context compaction.
As a result, image context is preserved after compaction in sessions containing screenshots or diagrams.
Prompt cache reuse rates also improved, boosting efficiency across all image-handling skills.

### Subagent final report simplification (v2.1.70)

The final report at subagent completion was simplified, reducing token consumption.
When launching many subagents in `breezing` or `harness-work`, the cumulative token savings are significant.

### `--resume` skill list re-injection removed (v2.1.70)

When resuming a session with `--resume`, re-injection of the skill list was removed.
This saves about 600 tokens and lightens the resume flow in the `session` skill.

### Plugin hooks fixes (v2.1.70)

v2.1.70 fixed several Plugin hooks-related bugs:
- `Stop` / `SessionEnd` hooks now fire correctly even after running the `/plugin` command
- Conflicts between hooks with the same template were resolved
- Correct operation of `WorktreeCreate` / `WorktreeRemove` hooks was confirmed

### Additional Teammate nesting prevention fix (v2.1.70)

An additional fix was made to the Teammate nesting prevention already addressed in v2.1.69.
Prevention of the cascade problem where an agent infinitely spawns another agent was strengthened.

### PostToolUseFailure hook (v2.1.70)

CC 2.1.70 added the `PostToolUseFailure` event. A new hook event that fires when a tool call fails.
In Harness, it is used in the `hooks` skill and `error-recovery` for automatic escalation on consecutive failures (stop after 3 consecutive failures).

```json
"PostToolUseFailure": [{
  "hooks": [{
    "type": "command",
    "command": "...post-tool-failure.sh",
    "timeout": 10
  }]
}]
```

### `/loop` + Cron scheduling (v2.1.71)

CC 2.1.71 added the `/loop` command. Specifying an interval and a prompt like `/loop 5m <prompt>` enables Cron-style scheduling that runs a command periodically.
In `breezing`, `/loop 5m /sync-status` is used for periodic task-progress checks.
Unlike the existing `TeammateIdle` (passive, event-driven), it can proactively perform periodic monitoring.

### Background Agent output path fix (v2.1.71)

In CC 2.1.71, the completion notification for Background Agents now includes the output file path.
This makes it possible to safely retrieve background agent results even after compaction.
`run_in_background: true` in `breezing` and `parallel-workflows` becomes practical.

### `--print` team agent hang fix (v2.1.71)

The issue of team agents hanging in `--print` mode was fixed.
Team agent stability when running `claude --print` in CI pipelines improved.

### Plugin install parallel execution fix (v2.1.71)

A state race was fixed for when multiple Claude Code instances install plugins simultaneously.
Plugin loading stability improved when multiple Teammates launch at the same time in `breezing`.

### Marketplace improvements (v2.1.71)

CC 2.1.71 introduced several improvements around Marketplace:
- `@ref` parser fix: `owner/repo@vX.X.X` format reference resolution is now accurate
- merge conflict fix on update: plugin updates are more stable
- MCP server deduplication: prevents duplicate registration of the same MCP server
- `/plugin uninstall` now uses `settings.local.json`: accurate reflection to user-local settings

### Per-agent hooks (v2.1.69+)

CC 2.1.69 added a `hooks` field to agent-definition frontmatter.
Separate from the global hooks.json, agent-specific hooks can be defined.

Use in Harness:
- **Worker**: Applies the `pre-tool.sh` guardrail on Write/Edit via `PreToolUse`
- **Reviewer**: Logs review session completion via `Stop`

Hooks within an agent definition are only active during that agent's lifecycle and are automatically cleaned up on termination.

### Agent `isolation: worktree` (v2.1.50+)

Adding `isolation: worktree` to an agent definition's frontmatter causes
that agent to automatically create a git worktree at launch and work in an independent repository copy.
If there are no changes, the worktree is automatically cleaned up.

In Harness, `isolation: worktree` was added to the Worker agent.
Combined with `memory: project`, Agent Memory (MEMORY.md) is shared across worktrees,
allowing parallel Workers to reference and update the same learnings.

### Auto Mode rollout policy

Auto Mode is organized as a migration candidate for making Claude Code's team execution more conservative.
However, the shipped default is still `bypassPermissions`, and project templates and frontmatter retain only the permission modes listed in the official docs.

| Layer | Adopted value | Reason |
|---------|--------|------|
| project template (`permissions.defaultMode`) | `bypassPermissions` | because `autoMode` is not among the documented permission modes |
| agent frontmatter (`permissionMode`) | `bypassPermissions` | because declarative settings use only documented values |
| teammate execution path | `bypassPermissions` (current) | to match the shipped default with the actual permission inheritance |
| `--auto-mode` | opt-in marker | to try the rollout only when the parent session has a compatible permission mode |

Default command examples:

```bash
/breezing all
/execute --breezing all
```

### Subagent `background` field

Adding `background: true` to an agent definition's frontmatter causes that agent to always run as a background task.
Even without explicitly specifying `run_in_background: true`, it runs in the background every time it is launched via the Agent tool.

```yaml
---
name: long-running-analyzer
background: true
---
```

In Harness, it can be considered when spawning Workers in `breezing`, but currently the Lead explicitly controls `run_in_background`, so additional adoption is deferred to Phase 2 and beyond.

### Subagent `local` memory scope

`memory: local` is saved to `.claude/agent-memory-local/<name>/`, a path that should be added to `.gitignore`.
Differences from `project`:

| Scope | Path | VCS commit | Use case |
|---------|------|-------------|------------|
| `user` | `~/.claude/agent-memory/<name>/` | Excluded | Learnings shared across all projects |
| `project` | `.claude/agent-memory/<name>/` | Shareable | Team-shared project knowledge |
| `local` | `.claude/agent-memory-local/<name>/` | Not recommended | Personal / highly sensitive learnings |

In Harness, both Worker and Reviewer currently use `memory: project`. `local` is suited to recording personal debugging patterns, but the current setting is maintained to prioritize team sharing.

### Agent Teams experimental flag

Agent Teams is enabled as an experimental feature via the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable.
It can also be set via settings.json:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Because the Harness `breezing` skill assumes the Agent Teams feature,
a validation step is added at setup to confirm this environment variable is set.

### Desktop Scheduled Tasks

The Desktop app's Scheduled Tasks are saved to `~/.claude/scheduled-tasks/<task-name>/SKILL.md`.
`name` and `description` are defined in the YAML frontmatter, and the prompt is written in the body.

Schedule settings (frequency, time, folder) are managed from the Desktop app's UI.
Can be used to run `/harness-work` or `/harness-review` on a schedule.

### `/agents` command

An interactive management interface for agents. It allows the following operations:
- Listing all available agents (built-in, user, project, plugin)
- Guided or Claude-generated agent creation
- Editing the configuration and tool access of existing agents
- Deleting custom agents

Non-interactive listing from the CLI: `claude agents`

### `--agents` CLI flag

Passes agent definitions as JSON at session launch. A temporary configuration that is not saved to disk:

```bash
claude --agents '{
  "quick-reviewer": {
    "description": "Quick code review",
    "prompt": "Review for critical issues only",
    "tools": ["Read", "Grep", "Glob"],
    "model": "haiku"
  }
}'
```

Useful for temporary agent injection in CI/CD pipelines.

### `ExitWorktree` tool (v2.1.72)

CC 2.1.72 added the `ExitWorktree` tool. It programmatically exits a worktree session created with `EnterWorktree`.
Previously, the only option was to manually select from the prompt at worktree session end, but now an agent can automatically exit the worktree after completing implementation.

Use in Harness:
- After a `breezing` Worker finishes work in `isolation: worktree`, it explicitly closes the worktree with `ExitWorktree`
- Improves the reliability of worktree cleanup (can be combined with the existing behavior of automatic deletion when there are no changes)

### Effort levels simplification (v2.1.72)

CC 2.1.72 simplified effort levels to three tiers: `low/medium/high`. The `max` level was removed, and the display symbols were unified to `○ ◐ ●`. `/effort auto` resets to the default (medium).

Impact on Harness:
- High effort injection via the `ultrathink` keyword remains valid (no change)
- No change is needed to harness-work's scoring logic (the ultrathink → high effort mapping is maintained)
- References to `max` in the documentation are unified to `high`

### Agent tool `model` parameter revived (v2.1.72)

CC 2.1.72 revived the Agent tool's `model` parameter. You can launch a subagent with a model specified per invocation.
Separate from the `model` field in the agent definition, a temporary model can be specified at spawn time.

Room for use in Harness:
- Spawn lightweight tasks (documentation updates, format fixes, etc.) with `model: "haiku"` to reduce cost
- Spawn security reviews and architecture changes with `model: "opus"` to maximize quality
- Currently, both Worker/Reviewer are fixed at `model: sonnet`. An implementation where the Lead dynamically switches models based on task characteristics is deferred to Phase 2 and beyond

### `/plan` description argument (v2.1.72)

In CC 2.1.72, the `/plan` command now accepts an optional description argument.
Like `/plan fix the auth bug`, you can immediately enter plan mode with a description.

Use in Harness:
- Can be used complementarily with the `create` subcommand of the `harness-plan` skill
- Guided as a shortcut for when a user simply wants to enter plan mode

### Parallel tool call fix (v2.1.72)

CC 2.1.72 fixed an important bug with parallel tool calls.
Previously, if any of Read, WebFetch, or Glob failed, sibling calls running in parallel were also canceled.
After the fix, only Bash errors cascade, and failures of other tools are handled independently.

Impact on Harness:
- Improved stability when running file reads and web searches in parallel in `breezing` and `harness-work`
- Resolved the problem where a Read of a nonexistent file canceled other healthy Reads
- Improved reliability during the Worker agent's exploration phase

### Worktree isolation fixes (v2.1.72)

CC 2.1.72 fixed two bugs related to worktree isolation:

1. **cwd restoration on Task resume**: A task resumed with the `resume` parameter now correctly restores the worktree's working directory
2. **worktreePath in Background notifications**: The completion notification for a background task now includes a `worktreePath` field

Impact on Harness:
- Improved reliability when a `breezing` Worker works in `isolation: worktree` and the Lead retrieves the results
- The worktree path can now be obtained from the completion notification of a Worker spawned with `run_in_background: true`

### `/clear` background agent retention (v2.1.72)

CC 2.1.72 changed the behavior of `/clear`. It now stops only foreground tasks, leaving agents and Bash tasks running in the background unaffected.

Impact on Harness:
- Background Workers survive even if the user runs `/clear` during a `breezing` team run
- Even when the Lead tidies context with `/clear`, running tasks are not interrupted, improving safety

### Hooks fixes (v2.1.72)

CC 2.1.72 fixed several hook-related bugs:

1. **transcript_path**: `transcript_path` is now set correctly in `--resume` / `--fork` sessions
2. **Duplicate PostToolUse block reason**: Fixed an issue where the reason message was displayed twice when a PostToolUse hook blocked
3. **stdin for async hooks**: Async hooks now receive stdin correctly
4. **Duplicate skill hook firing**: Fixed an issue where skill hooks fired twice per event

Impact on Harness:
- The `pre-tool.sh` / `post-tool.sh` guardrail hooks now fire exactly once, improving log reliability
- `session-memory` transcript references now work correctly in `--resume` sessions too

### HTML comment hiding (v2.1.72)

CC 2.1.72 hides HTML comments (`<!-- ... -->`) inside CLAUDE.md files during auto-injection.
They remain visible when the file is read directly with the Read tool.

Impact on Harness:
- **No actual impact**: We consistently avoid placing important instructions or settings inside HTML comments

### Bash auto-approval additions (v2.1.72)

CC 2.1.72 added the following commands to the Bash auto-approval allowlist:
`lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind`

Impact on Harness:
- Workers can now run process checks (`pgrep`) and file searches (`fd`) without a permission prompt
- The guardrails `pre-tool.sh` continues to let these commands through (not blocked)

### Prompt cache fix (v2.1.72)

CC 2.1.72 fixed a prompt cache invalidation bug during SDK `query()` calls.
Input token cost is reduced by up to 12x.

Impact on Harness:
- Major cost reduction when spawning many subagents in `breezing` or `harness-work`
- Especially effective for repetitive API call patterns within the same session

### Output Styles (v2.1.72+)

CC's Output Styles feature lets you customize the system prompt itself.
It is a different layer from CLAUDE.md (added as a user message) or Skills (for specific tasks).

Harness provides `.claude/output-styles/harness-ops.md`:
- `keep-coding-instructions: true` — optimizes the operational flow while retaining coding instructions
- Structured progress report format (done / current position / next action)
- Tabular output for the Quality Gate
- Structured format for review verdicts
- Standard output format for escalation (the 3-strike rule)

```bash
# Enable
/output-style harness-ops
```

### `permissionMode` in agent frontmatter (v2.1.72+)

The official documentation now documents `permissionMode` as an official field of agent frontmatter.

Reflected in Harness:
- Added `permissionMode: bypassPermissions` to all three agents (Worker/Reviewer/Scaffolder)
- Achieves declarative permission management that does not depend on the `mode` specified at spawn time
- Auto Mode is organized as a rollout candidate; the current shipped default remains `bypassPermissions`

```yaml
# agents/worker.md frontmatter
permissionMode: bypassPermissions  # added
```

### Agent Teams official best practices (v2.1.72+)

Claude Code officially added `agent-teams.md` as a standalone document.
The following are reflected in Harness's `docs/team-composition.md`:

1. **Task granularity guideline**: recommended value of 5-6 tasks/teammate
2. **`teammateMode` setting**: official support for `"auto"` / `"in-process"` / `"tmux"`
3. **Plan Approval pattern**: the official pattern of requiring plan mode from Workers
4. **Quality Gate Hooks**: the exit 2 feedback pattern for `TeammateIdle`/`TaskCompleted`
5. **Team size**: recommended value of 3-5 teammates (consistent with Harness's 1-3 Workers + 1 Reviewer)

### Sandboxing (`/sandbox`)

An OS-level sandbox feature natively integrated into Claude Code. It uses Seatbelt on macOS and bubblewrap on Linux to restrict filesystem/network access of Bash commands.

**Two modes**:
- **Auto-allow mode**: Commands inside the sandbox are auto-approved. Access outside the constraints falls back to the normal permission flow
- **Regular permissions mode**: All commands require approval even inside the sandbox

**Utilization strategy in Harness**:
- Positioned as a **complementary layer** to `bypassPermissions` (not a replacement)
- Adds an OS-level safety boundary to Worker agents' Bash commands
- Explicitly restrict the range a Worker can write to via `sandbox.filesystem.allowWrite`
- Restrict external access to trusted domains via `sandbox.network` (exfiltration prevention)

**Phased rollout plan**:

| Phase | Worker permissions | Sandbox |
|---------|-----------|---------|
| Current | `bypassPermissions` + hooks guard | not applied |
| Validation phase | `bypassPermissions` + hooks + sandbox auto-allow | applied to Worker's Bash |
| After stabilization | sandbox auto-allow only (consider retiring `bypassPermissions`) | applied to all Bash |

```json
// settings.json (for the validation phase)
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.claude", "//tmp"]
    }
  }
}
```

> `@anthropic-ai/sandbox-runtime` is published as OSS and can also be used to sandbox MCP servers.

### `opusplan` model alias

A hybrid alias that automatically switches to Opus in plan mode and Sonnet in execution mode.

**Utilization in Harness**:
- Ideal for the Breezing Lead session: leverage Opus's reasoning power for the Plan phase (task decomposition, architecture decisions), and use Sonnet for cost-efficient execution coordination after Workers are spawned
- Enable with `claude --model opusplan` or `/model opusplan`

**Control via environment variables**:
```bash
# Customize the internal mapping of opusplan
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6    # for Plan
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5    # for execution
```

### `CLAUDE_CODE_SUBAGENT_MODEL` environment variable

An environment variable that specifies the model for subagents (Worker/Reviewer) in bulk.

**Utilization in Harness**:
- Currently: Worker/Reviewer fix `model: sonnet` in the agent definition
- Using this environment variable lets you switch the model without changing the agent definition
- Useful for cost control in CI environments (run tests with `CLAUDE_CODE_SUBAGENT_MODEL=haiku`)

```bash
# Run all subagents with haiku (CI cost reduction)
export CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001
```

### `availableModels` setting

A setting that restricts the models a user can select. When set in managed/policy settings, the restriction applies to `/model`, `--model`, and `ANTHROPIC_MODEL` alike.

**Utilization in Harness**:
- Model governance in enterprise environments: prevents Worker/Reviewer from using unintended models
- Combining `availableModels` + `model` lets you govern the model experience for all users

```json
// managed settings
{
  "model": "sonnet",
  "availableModels": ["sonnet", "haiku", "opusplan"]
}
```

### Checkpointing (`/rewind`)

A feature that automatically tracks file edits during a session and lets you rewind to any point.
A checkpoint is created automatically at each user prompt.

**How to use**:
- Open the rewind menu with `Esc + Esc` or `/rewind`
- Options: restore code / restore conversation / restore both / summarize from here

**Utilization in Harness**:
- When a problem is found during the self-review phase of `harness-work`, rewind to the pre-implementation state
- Use "summarize from here" to reclaim the context window of a lengthy debugging session
- Difference from `/compact`: checkpoints let you selectively specify the compression range

**Limitations**:
- File changes made by Bash commands are not tracked (`rm`, `mv`, `cp`, etc.)
- External manual changes are not tracked
- It is not a replacement for Git, but a session-level "local Undo"

### Code Review (managed service)

A multi-agent PR review service running on Anthropic infrastructure. Research Preview for Teams/Enterprise.

**Overview of operation**:
1. Auto-launches when a PR is created/updated
2. Multiple specialized agents analyze the diff and codebase in parallel
3. A verification step filters out false positives
4. After deduplication and severity ranking, findings are posted as inline comments

**Severity levels**:
| Marker | Level | Meaning |
|---------|--------|------|
| 🔴 | Normal | A bug that should be fixed before merge |
| 🟡 | Nit | A minor issue (not blocking) |
| 🟣 | Pre-existing | A bug that existed before this PR |

**`REVIEW.md`**: A review-specific guidance file placed at the repository root. Separate from `CLAUDE.md`, it defines rules applied only during review.

**Utilization in Harness**:
- Consider generating a `REVIEW.md` template as the Code Review support for the `harness-review` skill
- Harness's Worker self-review and managed Code Review are complementary (local + remote double check)
- Average cost $15-25/review. Note that the `on-push` trigger incurs cost per push

### Status Line (`/statusline`)

A customizable status bar displayed at the bottom of the Claude Code terminal. It passes JSON session data to a shell script and displays the output text.

**Available data**:
- `model.id`, `model.display_name` — the current model
- `context_window.used_percentage` — context usage rate
- `cost.total_cost_usd` — session cost
- `cost.total_duration_ms` — elapsed time
- `worktree.*` — worktree info
- `agent.name` — agent name
- `output_style.name` — output style name

**Utilization in Harness**:
- Provide a Harness-specific status line via `scripts/statusline-harness.sh`
- Always display model name, context usage rate, session cost, git branch, and Harness version
- Threshold display of context usage rate with ANSI colors (70% yellow, 90% red)

### 1M Context Window (`sonnet[1m]`)

A 1-million-token context window available on Opus 4.6 and Sonnet 4.6. Long-context pricing applies beyond 200K tokens.

**Utilization in Harness**:
- Useful for large-codebase analysis in `harness-review`
- Sessions in `breezing` that handle many files at once
- Enable with `/model sonnet[1m]`. Can be disabled with `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`

### Per-model Prompt Caching Control

A group of environment variables controlling prompt caching per model.

| Environment variable | Purpose |
|---------|------|
| `DISABLE_PROMPT_CACHING` | Disable caching for all models |
| `DISABLE_PROMPT_CACHING_HAIKU` | Disable for Haiku only |
| `DISABLE_PROMPT_CACHING_SONNET` | Disable for Sonnet only |
| `DISABLE_PROMPT_CACHING_OPUS` | Disable for Opus only |

**Utilization in Harness**:
- Disable the cache for a specific model during debugging to observe behavior
- Selective control when cache implementations differ across cloud providers (Bedrock/Vertex)

### `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`

An environment variable that disables Adaptive Reasoning on Opus 4.6 / Sonnet 4.6 and reverts to a fixed thinking budget controlled by `MAX_THINKING_TOKENS`.

**Utilization in Harness**:
- Useful in CI environments that need predictable token cost
- Not exclusive with `harness-work`'s effort scoring (both can be used, but it is usually more effective to keep adaptive thinking enabled and control via ultrathink)

### Chrome Integration (`--chrome`)

A beta feature that integrates with the Claude Code Chrome extension to run browser automation from the terminal.
Start a session with the `--chrome` flag, or enable it from within a session with `/chrome`.

**Key features**:
- Live debugging: read console errors and immediately fix the offending code
- UI testing: form validation, visual regression checks, user flow verification
- Data extraction: extract structured data from web pages and save locally
- GIF recording: record browser interaction sequences as GIFs

**Utilization in Harness**:
- Automatic verification after UI component implementation in `harness-work`
- Visual review of web applications in `harness-review`
- Enabling `/chrome` lets Workers run browser tests

**Constraints**: Google Chrome / Microsoft Edge only. Brave, Arc, etc. are not supported. WSL is not supported.

### LSP server integration (`.lsp.json`)

Integrates Language Server Protocol servers via Plugin to provide real-time code diagnostics.

**Available LSP plugins**:
| Plugin | Language Server | Install |
|-----------|----------------|------------|
| `pyright-lsp` | Pyright (Python) | `pip install pyright` |
| `typescript-lsp` | TypeScript Language Server | `npm install -g typescript-language-server typescript` |
| `rust-lsp` | rust-analyzer | see the rust-analyzer official guide |

**Provided features**:
- Instant diagnostics: display errors/warnings immediately after editing
- Code navigation: jump to definition, find references, hover info
- Type info: display symbol types and documentation

**Configuration example** (`.lsp.json`):
```json
{
  "typescript": {
    "command": "typescript-language-server",
    "args": ["--stdio"],
    "extensionToLanguage": {
      ".ts": "typescript",
      ".tsx": "typescriptreact"
    }
  }
}
```

### `SubagentStart`/`SubagentStop` matcher

A hook at the settings.json level that monitors the subagent lifecycle by agent type.
The official documentation now documents the pattern of specifying an agent name in the matcher.

**Harness implementation**:
- `SubagentStart`: individually track the launch of Worker/Reviewer/Scaffolder/Video Generator
- `SubagentStop`: individually record the completion of each agent
- Added the matcher to the existing `subagent-tracker` Node.js script

```json
"SubagentStart": [
  { "matcher": "worker", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] },
  { "matcher": "reviewer", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] }
]
```

### Agent Teams: Task Dependencies

Dependencies can be set on Agent Teams tasks. Completing a dependency task automatically unblocks the blocked task.

**Behavior**:
- Tasks have three states: `pending`, `in_progress`, `completed`
- A pending task with unresolved dependencies cannot be claimed
- Automatically unblocked when the dependency completes (no manual intervention needed)
- File locks prevent simultaneous claims by multiple teammates

**Utilization in Harness**:
- The Breezing Lead explicitly specifies dependencies during task decomposition
- Example: guarantees the order "implement API endpoint" → "write tests" → "update docs"

### `--teammate-mode` CLI flag

A flag that specifies the Agent Teams display mode per session.

```bash
claude --teammate-mode in-process  # all teammates in the same terminal
claude --teammate-mode tmux        # a separate pane for each teammate
```

Overrides the `teammateMode` setting in settings.json. `in-process` is recommended in the VS Code integrated terminal.

### `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`

An environment variable that disables all background task features with `=1`.

**Utilization in Harness**:
- For environments where security policy restricts background execution
- Note that Breezing's background Worker spawn is also disabled, so use with caution

### `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`

An environment variable that adjusts the subagent auto-compaction threshold (default 95%).

**Utilization in Harness**:
- Set to `50` to enable early compression. Improves the stability of long-running Workers
- Prevents context overflow when a Breezing Worker reads a large number of files

### `cleanupPeriodDays` setting

A setting that controls the auto-cleanup period for subagent transcripts (default 30 days).
Transcripts are saved to `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`.

### `/btw` side questions

A command for asking a short question while retaining the current context.
Because the answer does not remain in the main conversation history, it does not consume the context window.

**When to use vs. subagents**:
- `/btw`: questions answerable immediately in the current context (no tool access)
- subagents: independent investigation/implementation tasks (with tool access)

### Plugin CLI commands

Non-interactive management commands for plugins. Support automation via scripts.

```bash
claude plugin install <plugin> [--scope user|project|local]
claude plugin uninstall <plugin> [--scope user|project|local]
claude plugin enable <plugin> [--scope user|project|local]
claude plugin disable <plugin> [--scope user|project|local]
claude plugin update <plugin> [--scope user|project|local|managed]
```

### Remote Control enhancement

`/remote-control` (`/rc`) can now enable Remote Control from within a session.

**New features**:
- `--name "My Project"`: specify a session name
- `--sandbox` / `--no-sandbox`: enable/disable the sandbox
- `--verbose`: display detailed logs
- `/mobile`: display a QR code to quickly connect to the iOS/Android app
- Auto-reconnect: automatic recovery from a network drop (within 10 minutes)
- `/config` → "Enable Remote Control for all sessions" to keep it always enabled

### `skills` field in agent frontmatter

Adds a `skills` field to a subagent's frontmatter, preloading the full content of the skills at startup.
Since skills from the parent conversation are not inherited, they must be listed explicitly.

**Harness implementation status**:
- Worker: `skills: [harness-work, harness-review]` — preloads the implementation and self-review skills
- Reviewer: `skills: [harness-review]` — preloads the review skill
- Scaffolder: `skills: [harness-setup, harness-plan]` — preloads the setup and planning skills

> The inverse pattern of `skills` in a skill (`context: fork`). Rather than a skill controlling an agent, an agent loads skills.

### `modelOverrides` setting (v2.1.73)

A setting added in CC 2.1.73. It maps model picker (`/model` menu) entries to a custom provider's model ID.
Provider-specific identifiers such as a Bedrock ARN or a Vertex AI model ID can be specified.

**Harness usage**:
- When using Anthropic models via Bedrock/Vertex in an enterprise environment, use `modelOverrides` to map the model picker's display name to the actual provider model ID
- Worker/Reviewer's `model: sonnet` is automatically resolved to a provider-specific ARN
- Combined with `availableModels`, you can govern the model experience for the whole team

```json
// settings.json
{
  "modelOverrides": {
    "sonnet": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-5",
    "opus": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-opus-4-6-20250610-v1:0"
  }
}
```

### `/output-style` deprecation (v2.1.73)

In CC 2.1.73 the `/output-style` command was deprecated, and output style selection was integrated into the `/config` menu.
Existing usage such as `/output-style harness-ops` still works, but selection via `/config` is officially recommended.

**Impact on Harness**:
- Recommend updating documentation references to `/output-style harness-ops` to go through `/config`
- `.claude/output-styles/harness-ops.md` itself remains valid (no change to where the config file is placed)
- If any skill runs `/output-style`, consider switching it to `/config`

### Bedrock/Vertex Opus 4.6 default (v2.1.73)

In CC 2.1.73 the default Opus model on cloud providers (Amazon Bedrock / Google Vertex AI) was updated from 4.1 to 4.6.
On the first-party API, Opus 4.6 had been the default since v2.1.68; now it is unified across cloud providers as well.

**Impact on Harness**:
- Even in Bedrock/Vertex environments, the Lead (when using Opus) runs at the medium effort default
- The `opusplan` alias references Opus 4.6 in Bedrock/Vertex environments too
- Overriding via the `ANTHROPIC_DEFAULT_OPUS_MODEL` environment variable remains valid

### `autoMemoryDirectory` setting (v2.1.74)

A setting added in CC 2.1.74. It lets you customize the storage directory for auto-memory.
You can change it from the default location under `~/.claude/` to a project-specific path.

**Harness usage**:
- When using Harness across multiple projects, separate auto-memory per project
- In a CI environment, store memory in a temporary directory and clean it up at session end
- This is a different layer from Agent Memory (`memory: project`) (auto-memory is user-level learning)

```json
// settings.json (project level)
{
  "autoMemoryDirectory": ".claude/auto-memory"
}
```

### `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)

An environment variable added in CC 2.1.74. It lets you specify the `SessionEnd` hook timeout in milliseconds.
Previously it was killed at a fixed 1.5 seconds, so heavy cleanup processing was interrupted before completion.

**Harness usage**:
- When running `harness-mem` session recording or JSONL rotation in a `SessionEnd` hook, secure a sufficient timeout
- Recommended value: `5000` (5 seconds). Up to `10000` (10 seconds) if complex cleanup is required

```bash
export CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=5000
```

### Full model ID fix (v2.1.74)

In CC 2.1.74, full model IDs such as `claude-opus-4-6` and `claude-sonnet-4-6` (hyphen-separated form) are now correctly recognized in agent frontmatter and JSON config.
Previously only the aliases (`opus`, `sonnet`) worked reliably.

**Impact on Harness**:
- Full model IDs can now be specified in the `model` field of agent definitions (e.g., `model: claude-sonnet-4-6`)
- Full model IDs can also be used within the JSON of the `--agents` CLI flag
- Currently Harness uses aliases (`sonnet`, `opus`), so there is no immediate impact. Useful when a full ID must be specified in Bedrock/Vertex environments

```yaml
# agents/worker.md frontmatter (example using a full model ID)
model: claude-sonnet-4-6
```

### Streaming API memory leak fix (v2.1.74)

In CC 2.1.74, unbounded RSS (Resident Set Size) growth of the streaming API response buffer was fixed.
The problem where Node.js process memory usage grew without limit during long streaming sessions is resolved.

**Impact on Harness**:
- Improved stability in long `breezing` team sessions
- Stabilized memory consumption in long `harness-work` Worker sessions involving large amounts of file reads and writes
- An additional fix following the memory leak fix series of v2.1.50–v2.1.63 (LSP diagnostics, tool output, file history, etc.)
- Combined with Harness's own JSONL rotation measures (custom memory management) for double-layered stability

### `--remote` / Cloud Sessions

CC's `--remote` flag lets you launch a cloud session from the terminal. Tasks run on an Anthropic-managed isolated VM, and a PR can be created after completion.

**Harness usage**:
- Delegate large `breezing` tasks to the cloud to conserve local resources
- Launch multiple tasks in parallel with `--remote` (each task is an independent cloud session)
- Use `/teleport` to bring the cloud deliverables into local and connect to the subsequent `/harness-review`

```bash
# Run a task in the cloud
claude --remote "Fix the authentication bug in src/auth/login.ts"

# Bring it into local after completion
/teleport
```

### `/teleport` (`/tp`)

A command to bring a cloud session into the local terminal. Select a session interactively with `/teleport` or `/tp`, or specify it directly with `claude --teleport <session-id>`.

**Prerequisites**:
- The local git working directory must be clean
- Run from the same repository
- Be authenticated with the same Claude.ai account

### `CLAUDE_CODE_REMOTE` environment variable

Within a cloud session, `CLAUDE_CODE_REMOTE=true` is set. Harness's `session-env-setup.sh` persists this value as `HARNESS_IS_REMOTE`, which other hook handlers can use to decide to skip local-only processing.

```bash
# Example cloud detection inside a hook script
if [ "$HARNESS_IS_REMOTE" = "true" ]; then
  # Skip local-only processing in the cloud environment
  exit 0
fi
```

### `CLAUDE_ENV_FILE` SessionStart persistence

CC's `SessionStart` hook can persist environment variables to subsequent Bash commands by writing `KEY=VALUE` to the file pointed to by the `CLAUDE_ENV_FILE` environment variable.

Harness's `session-env-setup.sh` leverages this mechanism to make `HARNESS_VERSION`, `HARNESS_AGENT_TYPE`, `HARNESS_IS_REMOTE`, etc. available across the whole session.

### Slack Integration (`@Claude`)

Mentioning `@Claude` with a coding task in a Slack channel automatically creates a cloud session. Integration with a GitHub repository is a prerequisite.

**Relationship to Harness**:
- By setting Harness's HTTP hooks (`type: "http"`) to a Slack Webhook URL, you can get Slack notifications on task completion
- Because `.claude/settings.json` hooks also run within a cloud session, Harness's guardrails apply to Slack-initiated tasks too

### Server-managed settings (public beta)

A feature to deliver team-wide Claude Code settings from the Claude.ai admin console. For Teams/Enterprise.

**Harness usage**:
- Centrally manage team-wide `permissions.deny` rules
- Deliver Harness's hook settings via the server (though hook settings display a security confirmation dialog)
- Govern the team's model experience with the `availableModels` + `model` combination

### Microsoft Foundry

A new Azure-based cloud provider. Added as a third third-party provider following Bedrock / Vertex.
It can be mapped to a Foundry model ID via the `modelOverrides` setting.

### `PreCompact` hook

A hook event that fires just before context compaction runs. In Harness it is implemented in the following two layers:

1. **`pre-compact-save.js`**: persists session state (progress, metrics)
2. **agent hook**: checks whether any `cc:WIP` tasks remain and injects a warning message

```json
"PreCompact": [
  { "hooks": [
    { "type": "command", "command": "...pre-compact-save.js" },
    { "type": "agent", "prompt": "Check Plans.md for WIP tasks...", "model": "haiku" }
  ]}
]
```

### `Notification` hook event

A hook event that fires when Claude Code emits a notification. Documented in the plugin reference.
Can be used to forward notifications to external monitoring tools or dashboards.

### `--plugin-dir` spec change (v2.1.76, breaking)

**Change**: `--plugin-dir` now accepts only a single path. Multiple directories are specified by repeating the flag.

```bash
# Old (no longer supported)
claude --plugin-dir path1,path2

# New
claude --plugin-dir path1 --plugin-dir path2
```

**Impact on Harness**: No impact for the common configuration that uses only the Harness plugin.
The syntax change is only required when using multiple plugins simultaneously.

---

## Claude Code 2.1.76 new features

### MCP Elicitation support

**Overview**: A protocol by which an MCP server can request structured input from the user during task execution. It displays an interactive dialog through form fields or a browser URL.

**Harness usage**:
- Because Breezing's background Worker/Reviewer cannot interact with the UI, an auto-skip is implemented via the `Elicitation` hook
- Normal sessions pass through as-is (the user responds interactively)
- In addition to the legacy-compatible log `.claude/state/elicitation-events.jsonl`, the Go hook handler records `elicitation-event.v1` append-only to `.claude/state/elicitation/events.jsonl`
- Only when harness-mem is healthy does it best-effort forward to `/v1/events/record` as `event_type: "elicitation_event"`, silently falling back to the local ledger when unreachable

**Constraints**:
- Background agents cannot respond to elicitation (automatic handling via a hook is required)
- The MCP server side must support elicitation
- Claude-harness does not read the harness-mem DB directly

### `Elicitation`/`ElicitationResult` hooks

**Overview**: Two new hook events that can intercept before and after MCP Elicitation. `Elicitation` fires before the response is returned to the MCP server, and `ElicitationResult` fires after it is returned.

**Harness usage**:
- `Elicitation`: auto-skip decision during a Breezing session + logging + `capability_probe` event recording
- `ElicitationResult`: logging the result (`.claude/state/elicitation-events.jsonl`) + `eval_result` event recording
- Register handlers for both events in hooks.json

**Constraints**:
- Blocking (deny) in the `Elicitation` hook prevents input from reaching the MCP server
- Recommended timeout: Elicitation 10s / ElicitationResult 5s

### `PostCompact` hook

**Overview**: A new hook event that fires after context compaction completes. It pairs with the (existing) `PreCompact` hook.

**Harness usage**:
- Context re-injection after compaction (restoring WIP task state)
- Event recording in `.claude/state/compaction-events.jsonl`
- Improved state continuity in long sessions
- The symmetric structure of PreCompact (state save) → PostCompact (state restore)

**Constraints**:
- Recommended timeout: 15s
- On compaction failure (when the circuit breaker trips), PostCompact may not fire

### `-n`/`--name` CLI flag

**Overview**: A CLI flag to set a display name at session startup. Use it like `claude -n "auth-refactor"` and leverage it to identify sessions in the session list.

**Harness usage**:
- Automatically sets a name in the `breezing-{timestamp}` form for Breezing sessions
- Leverage it for filtering and tracking in the session list
- Makes it easy to identify a session during log analysis

**Code example**:
```bash
claude -n "breezing-$(date +%Y%m%d-%H%M%S)"
```

### `worktree.sparsePaths` setting

**Overview**: A setting that, when using `claude --worktree` in a large monorepo, checks out only the necessary directories via git sparse-checkout. It significantly improves worktree creation performance.

**Harness usage**:
- Shortens Breezing's parallel Worker startup time (large repositories)
- Configure in `.claude/settings.json`:
```json
{
  "worktree": {
    "sparsePaths": ["src/", "tests/", "package.json"]
  }
}
```

**Constraints**:
- Files in paths not sparse-checked-out are inaccessible to the Worker
- All directories with dependencies must be included in sparsePaths

### `/effort` slash command

**Overview**: A slash command to switch the effort level (low/medium/high) during a session. `/effort auto` resets it to the default.

**Harness usage**:
- Works with harness-work's multi-factor scoring, enabling effort control according to task complexity
- For complex tasks, `/effort high` (enabling ultrathink) can be set manually
- For simple tasks, `/effort low` suppresses token consumption

### `--worktree` startup speedup

**Overview**: Shortens `--worktree` startup time by reading git refs directly and skipping the redundant `git fetch` when the remote branch is available.

**Harness usage**:
- Breezing's Worker startup overhead is automatically reduced
- Particularly beneficial when launching many Workers simultaneously

### Background agent partial result retention

**Overview**: Even when a background agent is killed, its partial results are saved to the conversation context.

**Harness usage**:
- When a Breezing Worker is interrupted by a timeout or manual stop, part of its work is conveyed to the Lead
- Reassignment leveraging the Worker's partial deliverables becomes possible
- Reduces wasted "redo" effort

### Stale worktree auto-cleanup

**Overview**: Stale worktrees left behind by an interrupted parallel run are automatically cleaned up.

**Harness usage**:
- Complements manual cleanup via `worktree-remove.sh`
- Automatic recovery even after a Breezing session crash
- Prevents wasted disk space consumption

### Auto-compaction circuit breaker

**Overview**: When auto-compaction fails consecutively, a circuit breaker that stops after 3 attempts was introduced. It prevents token waste from infinite retries.

**Harness usage**:
- Matches the design philosophy of Harness's "3-attempt rule" (the 3-attempt limit on CI failures)
- Prevents unexpected cost increases in long Breezing sessions
- When the circuit breaker trips, it escalates in cooperation with the PostToolUseFailure hook

### Deferred Tools schema fix

**Overview**: Fixes an issue where tools loaded via `ToolSearch` lost their input schema after compaction, causing array and numeric parameters to be rejected with a type error.

**Harness usage**:
- Improved stability of ToolSearch-loaded tools in long sessions
- MCP tools work correctly even after Breezing's compaction

### `/context` command (v2.1.74)

**Overview**: Analyzes context window consumption and identifies the tools and memory that are pressuring the context. It displays actionable optimization suggestions (disconnecting unnecessary MCP servers, tidying up bloated memory, etc.).

**Harness usage**:
- Root-cause identification of "why does compaction happen so often" in long Breezing sessions
- Context optimization in environments with many hooks or MCP servers connected
- Just running `/context` during a session yields an analysis result immediately

**Constraints**:
- Available only during a session (not supported in batch mode)
- Unavailable inside subagents

### `maxTurns` agent safety limit

**Overview**: A frontmatter field that limits a subagent's maximum number of turns. When the configured turn count is reached, the agent automatically stops and returns its result. A safety mechanism recommended in the official CC documentation.

**Harness usage**:
- Worker: `maxTurns: 100` — for complex implementation tasks. Provides ample headroom while preventing runaway
- Reviewer: `maxTurns: 50` — specialized for Read-only analysis. If it does not complete in 50 turns, there is a problem
- Scaffolder: `maxTurns: 75` — the intermediate complexity of scaffolding and state updates

**Design decisions**:
- When the limit is reached, the Lead can collect the partial result and decide
- Combined with `bypassPermissions`, it functions as a safety valve in a runaway situation

### `Notification` hook implementation

**Overview**: A hook event that fires when Claude Code emits a notification. It intercepts events such as `permission_prompt` (permission confirmation), `idle_prompt` (idle notification), and `auth_success` (authentication success).

**Harness usage**:
- Logs all notification events to `.claude/state/notification-events.jsonl` via `notification-handler.sh`
- Tracks `permission_prompt` occurring in a Breezing background Worker (for post-hoc analysis)
- It had been documented in hooks-editing.md since v3.10.3, but the implementation in hooks.json is now complete

**Log format**:
```json
{"event":"notification","notification_type":"permission_prompt","session_id":"...","agent_type":"worker","timestamp":"2026-03-15T..."}
```

### Output token limits 64k/128k (v2.1.77)

In CC 2.1.77 the default maximum output tokens for Opus 4.6 and Sonnet 4.6 were raised to 64k, and the ceiling was extended to 128k tokens.

**Impact on Harness**:
- Long implementation code and large-scale refactoring output is less likely to be truncated
- Improved reliability when a Worker agent outputs a large number of file changes at once
- Because 128k output leads to increased cost, cost management also requires attention

### `allowRead` sandbox setting (v2.1.77)

You can block broad ranges with `sandbox.filesystem.denyRead` while re-allowing reads of specific paths via `allowRead`.

**Harness usage**:
- In the Reviewer agent's sandbox, denyRead `/etc/` while allowRead only specific config files
- Provide restricted read access to sensitive directories during security reviews

### PreToolUse `allow` respects `deny` (v2.1.77)

In CC 2.1.77, even when a PreToolUse hook returns `"allow"`, the `deny` permission rules in settings.json still apply. Previously a hook's `allow` overrode a global `deny`.

**Harness impact**:
- The guardrails security model is strengthened
- Setting `deny: ["mcp__codex__*"]` in settings.json blocks reliably regardless of the PreToolUse hook's decision
- In addition to the hook-based MCP block in `.claude/rules/codex-cli-only.md`, settings.json deny becomes the recommended pattern

### Agent `resume` → `SendMessage` (v2.1.77)

In CC 2.1.77 the Agent tool's `resume` parameter was removed. To resume a stopped agent, use `SendMessage({to: agentId})`. `SendMessage` automatically resumes a stopped agent in the background.

**Harness impact**:
- The `breezing` skill's Lead uses `SendMessage` when communicating with Workers/Reviewers
- `SendMessage` is documented as the official communication method in `team-composition.md` Lead Phase B

### `/branch` (formerly `/fork`) (v2.1.77)

In CC 2.1.77 the `/fork` command was renamed to `/branch`. `/fork` continues to work as an alias.

### `claude plugin validate` enhancement (v2.1.77)

In CC 2.1.77, `claude plugin validate` now validates the YAML frontmatter of skills, agents, and commands, plus the syntax of hooks.json.

**Harness usage**:
- Add `claude plugin validate` to the CI pipeline to catch frontmatter errors early
- Usable as a complement to `tests/validate-plugin.sh`

### `StopFailure` hook event (v2.1.78)

In CC 2.1.78 the `StopFailure` event was added. It fires when a session stop fails due to an API error (rate limit 429, auth failure 401, etc.).

**Harness usage**:
- The `stop-failure.sh` handler logs error information to `.claude/state/stop-failures.jsonl`
- Used for post-hoc analysis when a Breezing Worker fails to stop due to rate limiting
- Implemented as a lightweight handler with a 10-second timeout (no recovery processing needed)

### Hooks conditional `if` field (v2.1.85)

In CC 2.1.85 you can attach an `if` condition to a hook definition to finely narrow down "for which inputs should the hook run." It uses permission rule syntax, so you can specify the tool name and input pattern together, e.g. `Bash(git status*)`.

**Harness usage**:
- Split `PermissionRequest` into two lanes: `Edit|Write|MultiEdit` are always evaluated, while `Bash` pre-filters only safe-command candidates via `if`
- Keep `hooks/permission.sh`'s own safety judgment while reducing the number of unnecessary Bash permission hook invocations
- Include `MultiEdit` in the matcher too, closing on the hooks side the auto-approval gap that the core guardrail already handled

**UX improvement**:
- Before: Bash permission checks ran the hook broadly, incurring startup cost even in cases that were ultimately passed through
- After: the hook runs only for safe-read / test-type Bash, reducing response noise and wasted evaluation while maintaining auto-approval precision

### `${CLAUDE_PLUGIN_DATA}` variable (v2.1.78)

In CC 2.1.78 the `${CLAUDE_PLUGIN_DATA}` directory variable was added. It can be used as state storage that persists across plugin updates.

**Harness usage potential**:
- Currently uses `${CLAUDE_PLUGIN_ROOT}/.claude/state/`, which may be wiped on plugin updates
- Long-term, consider migrating persistent data such as metrics and notification logs to `${CLAUDE_PLUGIN_DATA}`
- Migration pattern: `STATE_DIR="${CLAUDE_PLUGIN_DATA:-${CLAUDE_PLUGIN_ROOT}/.claude/state}"`

### Agent frontmatter: `effort`/`maxTurns`/`disallowedTools` (v2.1.78)

In CC 2.1.78, `effort`, `maxTurns`, and `disallowedTools` gained official support in plugin agent definition frontmatter.

**Harness current state**:
- `maxTurns`: already implemented in v3.10.4 (Worker: 100, Reviewer: 50, Scaffolder: 75)
- `disallowedTools`: already implemented as `[Agent]` for Worker and `[Write, Edit, Bash, Agent]` for Reviewer
- `effort`: unused. Add an `effort` field to Worker/Reviewer definitions to declaratively control the default thinking level

### `deny: ["mcp__*"]` fix (v2.1.78)

In CC 2.1.78 the `deny` permission rules in settings.json were fixed to work correctly against MCP server tools.

**Harness usage**:
- The Codex MCP block recommended in `.claude/rules/codex-cli-only.md` can be migrated from hook-based to settings.json `deny`
- `"permissions": { "deny": ["mcp__codex__*"] }` is the clean pattern

### `--console` auth flag (v2.1.79)

In CC 2.1.79 the `claude auth login --console` flag was added, supporting authentication with Anthropic Console API billing.

### SessionEnd hooks `/resume` fix (v2.1.79)

In CC 2.1.79 the `SessionEnd` hook now fires correctly when switching sessions interactively via `/resume`. Previously SessionEnd did not fire on session switch, so in some cases cleanup processing was not executed.

### `PermissionDenied` hook event (v2.1.89)

In CC 2.1.89 the `PermissionDenied` hook now fires when the auto mode classifier rejects a command. Returning `{retry: true}` tells the model that a retry is possible. Rejected commands also appear in `/permissions` → the Recent tab.

**Harness usage**:
- Newly implemented `permission-denied-handler.sh` records rejection events as telemetry to `permission-denied.jsonl`
- When a Breezing Worker is rejected, it notifies the Lead via `systemMessage` and prompts consideration of an alternative approach
- Uses the `agent_id` / `agent_type` fields to track which agent was rejected for what

**UX improvement**:
- Before: auto mode rejections were notification-only and left no record, making it easy for the same rejection to recur
- After: rejection patterns accumulate, and in Breezing the Lead can recognize and respond immediately

### `"defer"` permission decision (v2.1.89)

In CC 2.1.89 a PreToolUse hook can now return a `"defer"` permission decision. In a headless session (`-p` mode), if a hook returns defer the session pauses, and on resume via `claude -p --resume` the hook is re-evaluated.

**Harness usage potential**:
- A safety valve for when a Breezing Worker encounters a hard-to-judge operation, such as a write to production or a request to an external service
- Add a "defer condition" to the `pre-tool.sh` guardrail so certain patterns pause the Worker → Lead judges
- For now this is documentation of the feature only. Concrete defer rules will be designed after operational patterns accumulate

### Hook output >50K disk save (v2.1.89)

In CC 2.1.89, when hook output exceeds 50K characters, it is saved to disk and referenced as a file path plus preview, rather than injected directly into context.

**Harness impact**:
- Hooks that may return large output (quality-pack, ci-status-checker, etc.) are designed with this behavior in mind
- Current Harness hooks have lightweight output, so the direct impact is small, but it is documented as a design constraint for future extensions

### PreToolUse exit 2 JSON fix (v2.1.90)

In CC 2.1.90 the block behavior was fixed for when a PreToolUse hook outputs JSON to stdout and exits with code 2. Previously there was a bug where blocking did not work correctly with this pattern.

**Harness impact**:
- `pre-tool.sh` uses the JSON + exit 2 pattern on deny, so from v2.1.90 onward the guardrail's deny works more reliably
- If existing guardrails had cases where "a deny was issued but the tool still ran," this bug may have been the cause

### Harness impact of calling built-in slash commands from the Skill tool (v2.1.108)

From CC 2.1.108 onward, the model can invoke built-in slash commands such as `/init`, `/review`, and `/security-review`
through the `Skill` tool. This enables Harness skills to call CC's built-in features
from the inside, but care is needed regarding role overlap with Harness's own `/harness-review`.
Specifically, when you invoke `/review` via the `Skill` tool, Harness's guardrails (R01-R13) are
not applied and a CC-native review runs. In the Harness review flow,
routing through `/harness-review` or `codex-companion.sh review` maintains guardrail protection and
normalization into the `review-result.v1` format. Skill tool invocation of built-in slash commands
is limited to lightweight inline reviews and initialization, and not used for reviews requiring a quality gate.

## v2.1.99-v2.1.110 + Opus 4.7 detail section (Phase 44.11.1)

> This section conforms to the 3-category classification (A/B/C) in `.claude/rules/cc-update-policy.md`.
> B classification is **0 items**. A = implemented, C = CC auto-inherited.

### PreCompact hook 3-way decision API (v2.1.99)

**Value-add**: `A: implemented` (hooks/hooks.json PreCompact entry, confirmed in Phase 44.13)

In CC 2.1.99 the PreCompact hook now supports a 3-way decision API of `"block"` / `"allow"` / `"defer"`.
Previously there were only the two choices `block` / `allow`, with no "decide later" option.

**Harness usage**:
- The pattern where a Breezing Worker `"block"`s compaction while in cc:WIP state and `"allow"`s it after WIP completes can now be implemented safely
- The PreCompact handler in `hooks/hooks.json` detects cc:WIP in Plans.md via `bin/harness pre-compact` and returns block
- `"defer"` is planned for conditional deferral in headless environments (currently the 2-way block/allow is used)

**UX improvement**:
- Before: to prevent compaction during WIP the only option was `block`, so long-running Workers suffered from continued unnecessary compaction suppression
- After: `defer` can signal "not now, but re-evaluate after resume," so compaction runs appropriately the moment the Worker completes

### ENABLE_PROMPT_CACHING_1H opt-in (v2.1.108)

**Value-add**: `A: implemented` (`scripts/enable-1h-cache.sh`, implemented in Phase 44.6.1)

In CC 2.1.108 a 1-hour prompt cache TTL via the `ENABLE_PROMPT_CACHING_1H=1` environment variable was added.
With the default 5-minute TTL, sessions over 30 minutes suffered frequent cache misses and increased cost.

**Harness usage**:
- Running `scripts/enable-1h-cache.sh` idempotently appends `ENABLE_PROMPT_CACHING_1H=1` to `env.local`
- Documented as a pre-start recommendation in `skills/breezing/SKILL.md` and `skills/harness-loop/SKILL.md`
- Added a selection-criteria table (use 1h cache if a session exceeds 30 minutes) to `docs/long-running-harness.md`

**UX improvement**:
- Before: long-running Breezing sessions saw increased cache misses, and the same CLAUDE.md and hooks.json were billed repeatedly
- After: the 1h TTL greatly improves cache hit rate. It reduces the cost of long-running tasks

### /undo (rewind alias) (v2.1.108)

**Value-add**: `A: implemented` (`.claude/rules/commit-safety.md`, implemented in Phase 44.7.1)

In CC 2.1.108 `/undo` was added as an alias for `/rewind`. It undoes the most recent tool call within a session.

**Harness usage**:
- `.claude/rules/commit-safety.md` documents `/undo`'s behavior definition, usage constraints, and prohibited patterns
- Documents the conditions prohibiting Worker / Reviewer from autonomously running `/undo` (use `git revert` to undo after a git commit)
- Prevents the risk of mistakenly wiping committed changes with `/undo`

**UX improvement**:
- Before: the distinction between `/rewind` and `/undo` was ambiguous, creating a risk of misuse by agents
- After: Harness rules clearly separate "`/undo` = undo of session-internal file changes" from "after commit, use `git revert`"

### PermissionRequest updatedInput / additionalContext (v2.1.110)

**Value-add**: `A: implemented` (`go/internal/guardrail/cc2110_regression_test.go`, implemented in Phase 44.3.1)

In CC 2.1.110 the `updatedInput` and `additionalContext` fields were added and refined for the PermissionRequest hook.
`updatedInput` passes the input CC re-evaluated, and with `setMode: dontAsk` the deny rules are re-applied even after a mode change.

**Harness usage**:
- Added 3 groups of regression tests to `go/internal/guardrail/cc2110_regression_test.go`
  - `updatedInput` + `setMode` → verifies deny rules (R01, R02, R06) still apply after re-evaluation
  - Confirms `additionalContext` is preserved through a JSON round-trip (R09 warning path)
  - Strengthened detection of Bash bypass vectors (`;`, `&&`, `||`, subshells, etc.)
- Extended `helpers.go`'s `hasSudo()` to also handle contexts containing shell metacharacters

**UX improvement**:
- Before: a theoretical loophole existed where, after CC updated the input, the guardrail's deny was not re-evaluated
- After: all R01-R13 rules are re-applied even after `updatedInput`, guaranteeing guardrail completeness

### /recap and built-in slash command discovery (v2.1.108)

**Value-add**: `C: CC auto-inherited` (no Harness-side change needed)

In CC 2.1.108 the `/recap` command was added, letting you summarize and review session content before resuming.
Skill-tool invocation of built-in slash commands was also realized in the same version.

**Harness usage**:
- `/recap` is documented in `skills/session-memory/SKILL.md` as a step to review session memory during long `--resume`
- Automatically usable as a CC core feature. No Harness-side implementation change needed

### EnterWorktree path argument / stale worktree auto-cleanup (v2.1.105)

**Value-add**: `A: implemented` (`scripts/reenter-worktree.sh`, implemented in Phase 44.7.1)

In CC 2.1.105 the worktree path is now passed as an argument to the `EnterWorktree` hook.
Previously you had to identify the worktree path yourself within the script.

**Harness usage**:
- `scripts/reenter-worktree.sh` implements a worktree re-entry helper that leverages the EnterWorktree path argument
- A safe re-entry flow including worktree registration confirmation and `worktree-info.json` cross-check
- Guarantees a Breezing Worker can re-enter the correct worktree after a pause

**UX improvement**:
- Before: Worker worktree re-entry required environment-dependent worktree path identification and was unstable
- After: receives the path directly from the hook and, by cross-checking `worktree-info.json`, reliably re-enters the correct context

---

## Opus 4.7 detail section (Phase 44.11.1)

> This section details the integration status of Opus 4.7-specific features into Harness.
> Value-add classification: A = implemented, C = CC auto-inherited. B classification is 0 items.

### 1. Literal Instruction Following

**Value-add**: `A: implemented` (`.claude/rules/opus-4-7-prompt-audit.md`, implemented in Phase 44.4.1 + 44.4.2)

Opus 4.7 greatly improved its ability to "execute instructions literally." Rather than filling in ambiguous phrasing to infer intent, it executes only what was instructed.

**Harness usage**:
- Newly created `.claude/rules/opus-4-7-prompt-audit.md`. Defines quality standards for agent prompts
  - Requires action instructions to include one of: an execution command name / file path / JSON schema name / numeric threshold
  - Count controls must be written numerically, e.g. `up to 3 times`
  - Ambiguous terms like `as needed` / `as appropriate` require an immediately following condition supplement
- Brought the prompts of `agents/worker.md`, `agents/reviewer.md`, `agents/advisor.md` into conformance with the audit standard

**UX improvement**:
- Before: ambiguous phrasing in agent prompts led to model misinterpretation and unintended behavior
- After: prompts that pass the audit standard are interpreted literally by the model, guaranteeing consistent behavior

### 2. xhigh Effort

**Value-add**: `A: implemented` (`agents/reviewer.md`, `agents/advisor.md`, `docs/effort-level-policy.md`, implemented in Phase 44.5.1)

Opus 4.7 added the `xhigh` effort level (acceptable as CC v2.1.111 frontmatter).
It has higher thinking intensity than `high` and suits complex reviews and design decisions.

**Harness usage**:
- `agents/reviewer.md`: changed `effort: medium` → `effort: xhigh` (improves review depth)
- `agents/advisor.md`: changed `effort: high` → `effort: xhigh` (improves judgment accuracy)
- `docs/effort-level-policy.md`: prepared a correspondence matrix between CC frontmatter effort and Anthropic API effort
- Kept the mechanism in the `harness-work` skill's multi-factor scoring that injects `ultrathink` into the Worker

**UX improvement**:
- Before: the Reviewer ran at medium effort, and reviews of complex architecture changes were sometimes shallow
- After: xhigh effort improves the Reviewer's thinking quality and raises the detection rate of critical/major findings

### 3. Task Budgets (adoption deferred)

**Value-add**: `C: adoption deferred` (`docs/task-budgets-research.md`, researched in Phase 44.10.1)

Anthropic Task Budgets (public beta) is a feature that limits token and tool-call counts per task.

**Harness usage**:
- Recorded the spec summary and conflict analysis with existing Harness mechanisms in `docs/task-budgets-research.md`
- Deferred adoption in this Phase because the feature overlaps with the existing `maxTurns` (Worker: 100, Reviewer: 50) and `MAX_REVIEWS`
- Documented the re-evaluation trigger condition for GA promotion (when the integration design with Harness's own controls is settled)

**Reasons for deferral**:
- Harness already manages Worker execution limits via `maxTurns` and `MAX_REVIEWS`
- Dual management with Task Budgets risks increasing configuration complexity
- Judged it better to wait for the stable API after GA rather than adopt at the public beta stage

### 4. Tokenizer improvements

**Value-add**: `C: CC auto-inherited` (no Harness-side change needed)

Opus 4.7's new tokenizer reduces the token count of the same prompt. The effect is especially large for mixed Japanese/code content.

**Harness impact**:
- Token consumption of CLAUDE.md, skill files, and agent prompts is automatically reduced
- The effective character count of the skill budget (2% of the context window) increases
- No Harness-side change needed. The benefit accrues automatically with the model update

### 5. Vision 2576px support

**Value-add**: `A: implemented` (`docs/opus-4-7-vision-usage.md`, `skills/harness-review/references/vision-high-res-flow.md`, implemented in Phase 44.9.1)

In Opus 4.7 the image short-edge limit was raised to 2576px. Review quality for PDFs, design diagrams, and UI screenshots improved.

**Harness usage**:
- `docs/opus-4-7-vision-usage.md`: newly created operations guide for high-resolution review (3 scenarios: PDF review / design diagram analysis / UI screenshots)
- `skills/harness-review/references/vision-high-res-flow.md`: prepared the operational flow for the 2576px limit (resize decision, splitting strategy for multi-page PDFs)
- Built an automatic limit check into `/harness-review` for attached images

**UX improvement**:
- Before: high-resolution screenshots were auto-resized with quality degradation, and fine UI issues were sometimes overlooked
- After: reviewable at full size up to 2576px. Can detect pixel-level UI problems and fine labels in design diagrams

### 6. Memory feature expansion

**Value-add**: `C: CC auto-inherited` (the auto-memory system already exists. No Harness-side change needed)

Opus 4.7's Memory feature expansion (improved accuracy of automatic memory recording, improved compression quality of long-term memory) integrates automatically with Harness's existing Agent Memory foundation.

**Harness usage**:
- Agent-specific memory via `memory: project` frontmatter continues to function
- CC's improved auto-memory accuracy automatically improves the learning quality of Worker / Reviewer / Scaffolder
- Compatibility with existing entries under `.claude/agent-memory/` is maintained

### 7. /ultrareview (keep-both policy)

**Value-add**: `A: implemented` (`docs/ultrareview-policy.md`, `skills/harness-review/SKILL.md`, implemented in Phase 44.8.1)

In CC v2.1.111 `/ultrareview` was added as a built-in operator entrypoint. It runs a cloud multi-agent review.

**Harness usage (Policy B: keep both)**:
- `docs/ultrareview-policy.md`: established the policy that `/ultrareview` is limited to ad-hoc review and not built into the Harness automation flow
- Harness review automation keeps `review-result.v1`-contract-based `codex-companion.sh review` (preferred) + reviewer agent (fallback)
- Added a role-division section to `skills/harness-review/SKILL.md`

**UX improvement**:
- Before: the appearance of `/ultrareview` made its role vs. Harness's `/harness-review` ambiguous
- After: clearly separated as `/ultrareview` = for human ad-hoc review / `/harness-review` = for the automation flow

### 8. Auto Mode expansion

**Value-add**: `C: treated as opt-in` (the `--auto-mode` flag description in `skills/breezing/SKILL.md`)

In CC v2.1.111 Auto Mode became usable even without the `--enable-auto-mode` flag.

**Harness usage**:
- The `--auto-mode` option in `skills/breezing/SKILL.md` keeps its description as an opt-in flag that "explicitly signals the Harness-side Auto Mode rollout"
- Auto Mode expansion in CC core is inherited automatically, but take care not to mix it with Harness's `bypassPermissions`-based implementation
- Keep the design where `--auto-mode` as an operator entrypoint is chosen by the caller. Do not write an `autoMode` value on the agent definition side

**UX improvement**:
- Before: Auto Mode required the `--enable-auto-mode` flag, and its combination with Breezing was complex
- After: Auto Mode became permanent in CC core, but Harness continues to treat `--auto-mode` as an explicit opt-in, maintaining predictable behavior

## Phase 65 (cognitive-load 3 surface) — 2026-05-09 to 2026-05-10

| Feature | Skill / Component | Purpose | Value-add |
|---------|-------------------|---------|---------|
| Plan Brief HTML (1st surface) | `harness-plan-brief` | Before starting work, confirm approval with the client on Claude's understanding, options, risks, acceptance conditions, and confidence in a single HTML page | A: implemented (Phase 65.1) |
| Acceptance Demo HTML (2nd surface) | `harness-accept` | ship/wait/reject decision at handoff + acceptance-condition verification + display of past problem patterns | A: implemented (Phase 65.2) |
| Progress Tracker HTML (3rd surface) | `harness-progress` | progress % + WIP/TODO/done list + 5 kinds of drift alert + PostToolUse auto-regeneration (60s rate limit) | A: implemented (Phase 65.4) |
| Dictionary Redaction | `redact-by-dictionary.sh` + `render-html.sh --with-redaction` | defense against proper-noun leakage via Layer 1 server privacy + Layer 2a language-agnostic dictionary (Japanese NER + katakana final-scan removed for English-only product) | A: implemented (Phase 65.3) |
| Cross-Project Group | `cross-project-groups.yaml` + `load-cross-project-groups.sh` | opt-in group definition for cross-project search (default OFF) | A: implemented (Phase 65.3.1) |
| Cross-Project Audit Log | `cross-project-audit-log.sh` | one line of JSON Lines per cross-project search (privacy: query_hash only) | A: implemented (Phase 65.3.6) |
| Audit-trail UI | common addition to 3 HTML templates | "🔍 basis for this artifact" section at the end of each surface (search scope / referenced IDs / redaction count / log link) | A: implemented (Phase 65.5.2) |
| user_request_hash join | sha256 fields of `personal-preference.v1` + `acceptance-decision.v1` | enables graph-joining Plan Brief ↔ Acceptance by the same hash | A: implemented (Phase 65.1.4 / 65.2.3) |

**UX improvement**:
- Before: you couldn't see progress or decision rationale without reading Plans.md (200 lines) + git log. For a non-engineer client it was a complete black box
- After: opening a single HTML page in the browser lets you judge in 3 seconds "what is planned to be built (Plan Brief) / where we are now (Progress) / whether it can be accepted (Acceptance)"
- Even with cross-project search enabled, the 3-layer redaction prevents leakage of other projects' proper nouns (fail-safe)
- Details: [cognitive-load-surfaces.md](./cognitive-load-surfaces.md) / [cross-project-safety.md](./cross-project-safety.md)

### Orchestration Visibility (Phase 90)

| Feature | Skill / area used | Purpose | Value-add |
|------|-----------------|------|---------|
| Delegation Ledger | `orchestration-ledger.sh` + `codex-companion.sh` | records 8 items per delegation such as backend / counts to `orchestration-ledger.jsonl` (no prompt/secrets, status excluded from counting) | A: implemented (Phase 90.1.1) |
| Lifetime Accumulator | `orchestration-rollup.sh` + `go/internal/orchestration` | idempotently rolls up into the cumulative total via 2 paths, on completion + SessionEnd (`orchestration-totals.json`, record-only) | A: implemented (Phase 90.1.2) |
| Scorecard Aggregator | `orchestration-scorecard.sh` | merges session mix + lifetime and aggregates as tri-state (used/available/not-configured). claude = host | A: implemented (Phase 90.1.3) |
| HTML Scorecard | `templates/html/orchestration.html.template` + `render-html.sh` | shareable single HTML page starring the cumulative total (standalone, no JS) | A: implemented (Phase 90.1.4) |
| Completion Summary + Skill | `harness-orchestration` + `task_completed.go` | a one-time terminal summary on full completion (Go all-done) + on-demand HTML skill | A: implemented (Phase 90.1.5) |

**UX improvement**:
- Before: delegation was invisible at runtime, so you couldn't tell "whether Codex was really used, or everything fell back to Claude"
- After: via record → cumulative total → scorecard, you can show "how much orchestration was used in this session/project" (the cumulative total is the star number)

## Related documents

- [CLAUDE.md](../CLAUDE.md) - development guide (summary version of the Feature Table)
- [CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - skill catalog
- [CLAUDE-commands.md](./CLAUDE-commands.md) - command reference
- [ARCHITECTURE.md](./ARCHITECTURE.md) - architecture overview
