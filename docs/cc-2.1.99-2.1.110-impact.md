# Claude Code 2.1.99 → 2.1.110 — Harness Impact Classification

> **Purpose**: Classify every major change from Claude Code 2.1.99 to 2.1.110
> into the 3 categories (A / B / C) defined in `.claude/rules/cc-update-policy.md`,
> in a form that can be traced to implementation tasks from Phase 44.2 onward.
>
> **Classification rules** (from cc-update-policy.md):
> - **A: Implemented** — a concrete change is needed on the Harness side (new hook / scripts / skills / agents / docs)
> - **B: Written only** — Feature Table changed only. **Prohibited**. Must not appear in this table
> - **C: CC auto-inherited** — CC core fix only. No Harness change needed. Marked "CC auto-inherited" in the Feature Table
>
> **Assumption**: The current Harness is v4.1.1, and the Feature Table is up to date through v2.1.98 (Monitor tool).
> The A items in this table are implemented in Phase 44.2-44.7; the C items are only Feature Table additions in Phase 44.11.

---

## 1. Category A: Implemented (Harness-side change required)

Items that involve a concrete Harness-side change in Phase 44. The corresponding phase is noted on each row.

| ver | Change | Affected area | Target Phase |
|-----|-------|---------|-----------|
| 2.1.101 | Settings resilience: an unknown hook event name no longer causes the entire `settings.json` to be ignored | Improved safety when adding new hooks to `.claude-plugin/settings.json` / `hooks.json` | 44.2 (used as a safeguard when adding PreCompact) |
| 2.1.101 | `permissions.deny` now overrides a `PreToolUse` hook `permissionDecision: "ask"` | deny chaining of Harness guardrails (R01-R13) | **44.3** (re-verify R01-R13) |
| 2.1.101 | Fixed a bug where a duplicate `name:` frontmatter across multiple detected plugins resolved a slash command to the wrong plugin | Audit whether existing `skills/**/SKILL.md` frontmatter uses unique names | **44.4.2** (verify name uniqueness during skill literalization) |
| 2.1.101 | Fixed an existing bug where skills did not honor `context: fork` and `agent` frontmatter | Re-verify Harness skills that use `context: fork` (canai-docs, etc.) | **44.7.1** (small-feature integration) |
| 2.1.101 | Fixed a bug where subagents did not inherit dynamically injected MCP servers | Dynamic MCP in Breezing, `harness-mem` inheritance | **44.7.1** |
| 2.1.101 | Fixed a bug where a sub-agent could not Read/Edit its own files inside an isolated worktree | Worker / Advisor with `isolation: worktree` | **44.7.1** (verification + smoke) |
| 2.1.105 | **New hook: `PreCompact`** — compaction can be stopped with `{"decision":"block"}` / exit 2 | Prevents unintended compaction interruption of long-running Workers | **44.2.1** (Go implementation + hooks.json registration) |
| 2.1.105 | **Plugin manifest: new top-level key `monitors`** — a background monitor auto-arms on session start / skill invoke | Persistent Harness mem health / drift monitoring / advisor state | **44.2.2** (add to plugin.json) |
| 2.1.105 | `EnterWorktree` gained a `path` parameter, allowing re-entry into an existing worktree | worktree reuse in `scripts/run-worker-*.sh` etc. | **44.7.1** |
| 2.1.105 | `/proactive` alias for `/loop` | harness-loop alias policy | **44.7.1** (docs addition) |
| 2.1.108 | **`ENABLE_PROMPT_CACHING_1H` env var** — 1-hour prompt cache TTL | Cost reduction for long Breezing / harness-loop sessions | **44.6.1** (opt-in script + docs) |
| 2.1.108 | `/recap` / `/undo` alias for `/rewind` | session-memory / commit safety | **44.7.1** |
| 2.1.108 | The model can call built-in slash commands (`/init`, `/review`, `/security-review`) from the Skill tool | Check for functional overlap with Harness `/harness-review` | **44.7.1** / **44.8.1** |
| 2.1.110 | `/tui` command + `tui` setting (fullscreen rendering) | Operations guide update (docs) | **44.7.1** (docs addition only, no Harness behavior change) |
| 2.1.110 | **Push notification tool** (with Remote Control + "Push when Claude decides" enabled) | Usable for long-run completion notifications in `harness-loop` | **44.7.1** (docs addition, record possible future adoption) |
| 2.1.110 | **When `PermissionRequest` hooks return `updatedInput`, `permissions.deny` rules are re-checked** | Verify consistency of the deny chain in guardrails R01-R13 | **44.3.1** (re-verification required) |
| 2.1.110 | `setMode:'bypassPermissions'` now respects `disableBypassPermissionsMode` | Maintain Harness bypass policy | **44.3.1** (docs addition) |
| 2.1.110 | **Fixed so that `PreToolUse` hook `additionalContext` is not discarded even when the tool call fails** | Guardrail deny-reason injection persists even after failure | **44.3.1** (add regression test) |
| 2.1.110 | Fixed so that skills with `disable-model-invocation: true` work with `/<skill>` mid-message invocation | Resolves a latent bug that had occurred in Harness `/harness-work`, `/harness-review`, etc. | **44.7.1** (smoke test) |

**A item count**: **19 items**
**Implementation allocation**: 44.2 (2), 44.3 (3), 44.4.2 (1), 44.6.1 (1), 44.7.1 (10), 44.8.1 (1) + 3 items consolidated within 44.3.1

---

## 2. Category C: CC auto-inherited (no Harness change needed)

Feature Table addition only. No Harness implementation change is needed, but usage guides and expectations are updated.

| ver | Change | Benefit realized on the Harness side |
|-----|-------|-------|
| 2.1.101 | Memory leak fix — a bug where dozens of historical message-lists were retained in the virtual scroller during long sessions | RSS stabilization during long Breezing runs |
| 2.1.101 | Fixed large-session context loss from a dead-end branch anchor in `--resume` / `--continue` | Improved resume reliability on harness-loop wake-up |
| 2.1.101 | Fixed a hardcoded 5-minute timeout to honor `API_TIMEOUT_MS` (local LLM / extended thinking) | Safety for the longer thinking of Opus 4.7 xhigh |
| 2.1.101 | Bedrock SigV4 authentication failure fix | Transparent improvement for users on Bedrock |
| 2.1.101 | Grep tool ENOENT → fallback to system `rg` | Grep reliability across all skills |
| 2.1.101 | Fixed a bug where `/btw` wrote the entire conversation to disk every time | Reduced context cost |
| 2.1.101 | `/plugin update` ENAMETOOLONG fix | Stabilizes plugin updates in `/harness-setup` |
| 2.1.101 | Stale cache fix for directory-source plugins | Stabilizes reloads during Harness dev |
| 2.1.101 | Fix for custom keybindings not loading on Bedrock / Vertex | Keybindings in multi-provider environments |
| 2.1.101 | Command injection vulnerability fix: POSIX `which` fallback (LSP binary detection) | Auto-inherited security |
| 2.1.105 | Fixed a bug where images were dropped in queued messages | Stabilizes multimodal input |
| 2.1.105 | Fixed a bug where leading-whitespace trim broke ASCII art / indented diagrams | Reliability of diagram and table output |
| 2.1.105 | Fixed `alt+enter` / `Ctrl+J` newline insertion | Editing experience |
| 2.1.105 | Fixed re-firing of one-shot scheduled tasks (missed file-watcher cleanup) | Reliability of scheduled operation |
| 2.1.105 | Fixed loss of Team/Enterprise inbound channel notifications | CC multiplayer feature |
| 2.1.105 | `/skills` menu scroll fix | UI |
| 2.1.107 | Improved extended-thinking indicator display (shows the hint sooner) | UX during Opus 4.7 xhigh |
| 2.1.108 | Fixed `/compact` failing with "context exceeded" on large conversations | Reliability of long sessions |
| 2.1.108 | Fixed DISABLE_TELEMETRY users not receiving the 1h cache | Required as a prerequisite for the 44.6.1 opt-in |
| 2.1.108 | Fixed the permission prompt on safety-classifier transcript overflow in Agent tool auto mode | Reliability when adopting Auto Mode |
| 2.1.108 | Fixed a bug where the Bash tool produced no output when `CLAUDE_ENV_FILE` had a trailing `#` comment line | Bash execution stability |
| 2.1.108 | Fixed a bug where `claude --resume <session-id>` lost the custom name/color from `/rename` | Session management |
| 2.1.108 | Fixed a bug where policy-managed plugins did not auto-update when run from a different project than the initial install | Enterprise/Teams distribution |
| 2.1.108 | Fixed a bug where diacritical marks (accents, etc.) were dropped when `language` was set | i18n |
| 2.1.109 | Extended-thinking indicator rotating progress hint | UX |
| 2.1.110 | Fixed a bug where MCP tool calls hung indefinitely during an SSE/HTTP server connection drop | MCP reliability (harness-mem, etc.) |
| 2.1.110 | Fixed multi-minute hang in non-streaming fallback retries | UX for long tasks |
| 2.1.110 | Fixed session cleanup to fully delete, including subagent transcripts | Disk savings |
| 2.1.110 | `/skills` menu scroll fix (fullscreen) | UI |
| 2.1.110 | Remote Control session re-login prompt fix (stale session) | Remote Control UX |

**C item count**: **30 items**

---

## 3. Category B: Written only (prohibited)

**Empty**. Every item in this document is classified as A or C. Following the "block the PR when a Category B item is detected" rule in `cc-update-policy.md`, no B items are included.

---

## 4. Phase 44 Implementation Trace Table

Lets you reverse-look-up which A item each task from Phase 44.2 onward corresponds to.

| Phase | A item (see table above) |
|-------|---|
| 44.2.1 (PreCompact hook) | 2.1.105: `PreCompact` hook |
| 44.2.2 (monitors manifest) | 2.1.105: `monitors` manifest key |
| 44.3.1 (re-verify guardrails R01-R13) | 2.1.101: `permissions.deny` overriding PreToolUse ask / 2.1.110: `updatedInput` re-check / 2.1.110: `additionalContext` persist / 2.1.110: `setMode:'bypassPermissions'` + `disableBypassPermissionsMode` |
| 44.4.2 (skill literalization) | 2.1.101: check the fallout of the duplicate `name:` frontmatter bug |
| 44.6.1 (1h prompt cache opt-in) | 2.1.108: `ENABLE_PROMPT_CACHING_1H` |
| 44.7.1 (small-feature integration) | 2.1.101: `context: fork` + agent / subagent MCP inheritance / worktree Read/Edit / 2.1.105: `EnterWorktree path` / `/proactive` / 2.1.108: `/recap` / `/undo` / built-in slash via Skill tool / 2.1.110: `/tui` / Push notification / `disable-model-invocation` mid-message fix |
| 44.8.1 (/ultrareview integration) | 2.1.108: as part of built-in slash invocation, consider calling `/ultrareview` from the Skill tool |
| 44.11.1 (Feature Table update) | all 19 A items + all 30 C items above |

---

## 5. Note: Auto-inherited security items (worth highlighting)

From 2.1.97 → 2.1.98, all Bash permission bypasses (backslash-escape flag / compound command / env-var prefix / `/dev/tcp` redirect) were closed, and 2.1.101 also fixed the command injection in the POSIX `which` fallback. These are all C inheritance, but because the prerequisites of the Harness guardrails R01-R13 (Bash-related deny) have been improved, it is worth re-confirming in 44.3.1 whether "the prerequisites have not changed."
