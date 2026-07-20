# Memory Policy

## Purpose

This document defines where Harness memory should live.

The short version:

- Shared project decisions and reusable patterns belong in `.claude/memory/`.
- Noisy per-session logs and runtime state belong in local state paths.

## Project Memory

Use `.claude/memory/` for durable project knowledge.

| Path | Role | Git policy |
|------|------|------------|
| `.claude/memory/decisions.md` | Important decisions and why they were made | Share when useful |
| `.claude/memory/patterns.md` | Reusable implementation and operation patterns | Share when useful |
| `.claude/memory/session-log.md` | Session handoff notes | Local by default |
| `.claude/memory/context.json` | Project context cache | Local by default |

## Runtime State

Use `.claude/state/` for machine-readable runtime state.

Examples:

- `.claude/state/session.json`
- `.claude/state/agent-trace.jsonl`
- `.claude/state/advisor/`
- `.claude/state/locks/`

These files are usually local. Commit them only when a specific workflow says they are stable documentation or test fixtures.

## Session IDs

Session logs should not assume one environment variable exists everywhere.

Resolution order:

1. Claude Code: `${CLAUDE_SESSION_ID}` when present.
2. Shared fallback: `.claude/state/session.json` field `.session_id`.
3. Last resort: a generated timestamp-based ID.

This keeps session logs traceable without hard-coding a single environment variable.
