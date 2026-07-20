---
name: maintenance
description: "File cleanup and archiving. Tidies up bloated Plans.md, session-log.md, old logs, and state files. Trigger: /maintenance, cleanup, archive, organize, split session-log. Do NOT load for: implementation, review, release, new feature development."
description-en: "File cleanup and archiving. Tidies up bloated Plans.md, session-log.md, old logs, and state files. Trigger: /maintenance, cleanup, archive, organize, split session-log. Do NOT load for: implementation, review, release, new feature development."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
argument-hint: "[plans|session-log|logs|state|all] [--dry-run]"
user-invocable: true
effort: low
---

# Maintenance

A single-purpose skill for tidying up cluttered files. Invoke it when
auto-cleanup-hook raises a warning, or as routine housekeeping.

> **Prerequisite**: Before destructive operations (archive moves, line deletions),
> confirm that important information in Plans.md / session-log.md has been promoted
> to the SSOT (decisions.md / patterns.md). If not yet synced, run `/memory sync` first.

## Quick Reference

| Subcommand | Target | Typical triggers |
|------------|--------|------------------|
| `maintenance plans` | Archive completed tasks from Plans.md | "tidy Plans.md", "move old tasks" |
| `maintenance session-log` | Split session-log.md by month | "split session-log", "the log is too long" |
| `maintenance logs` | Delete old files in `.claude/logs/` | "clean up logs", "delete logs older than 30 days" |
| `maintenance state` | Trim `agent-trace.jsonl` / `harness-usage.json` | "trace bloat", "compact state" |
| `maintenance all` | Run the four above in order | "tidy everything", "full cleanup" |

Adding `--dry-run` only lists what would be done without executing. Free-form
instructions (e.g. "also delete old archives", "keep only this session-log") are
accepted in Step 1 and reflected in the processing parameters from Step 2 onward.

## Execution Steps

1. **Parse the user instruction**: Extract the subcommand plus any free-form details (exclusions, destinations, day thresholds)
2. **SSOT sync check**: If `.claude/state/.ssot-synced-this-session` is absent,
   prompt for `/memory sync` (required only when touching Plans.md)
3. **Open the reference file**: Read `${CLAUDE_SKILL_DIR}/references/cleanup.md` and run the matching section
4. **Report Before/After**: Show line counts and deletion counts, then finish

## Subcommand Details

For per-target execution steps, thresholds, and archive destinations, see [cleanup.md](./references/cleanup.md).

## Integration with auto-cleanup-hook

The PostToolUse hook (`scripts/auto-cleanup-hook.sh` / Go version `auto_cleanup_hook.go`)
detects when Plans.md, session-log.md, or CLAUDE.md exceed their line limits and returns
feedback recommending that you archive old tasks via `/maintenance`.
When you see this warning, run the corresponding subcommand.

## Notes

- **Do not move in-progress tasks**: `cc:WIP`, `pm:pending` are excluded from archiving
- **Archive destination is fixed**: `.claude/memory/archive/` — confirm with the user
  before moving anything elsewhere
- **Backup**: Before editing a file over 200 lines, take a local backup with
  `cp <file> <file>.bak.$(date +%s)`
- **CLAUDE.md is warning-only**: Never edit it automatically. Only offer a split proposal

## Related Skills

- `memory` — SSOT promotion before tidying Plans.md (updating decisions.md / patterns.md)
- `harness-setup` — Routine maintenance right after setup can also be invoked via `harness-setup`
- `session-init` — Controls the maintenance-recommendation notice at session start
