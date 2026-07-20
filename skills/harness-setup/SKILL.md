---
name: harness-setup
description: "HAR: Project init, tool setup, agent config, memory setup, skill mirror sync. Trigger: setup, init, new project, CI setup, harness-mem, mirror. Do NOT load for: implementation, review, release, planning."
description-en: "HAR: Project init, tool setup, agent config, memory setup, skill mirror sync. Trigger: setup, init, new project, CI setup, harness-mem, mirror. Do NOT load for: implementation, review, release, planning."
kind: workflow
purpose: "Initialize and repair Harness project configuration"
trigger: "setup, init, new project, CI setup, harness-mem, mirror"
shape: workflow
role: generator
pair: harness-sync
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
argument-hint: "[init|ci|harness-mem|mirrors|agents|localize]"
user-invocable: true
effort: medium
---

# Harness Setup

Harness unified setup skill.
Consolidates the following legacy skills:

- `setup` — unified setup hub
- `harness-init` — project initialization
- `harness-update` — Harness updates
- `maintenance` — file cleanup and tidying

## Quick Reference

| Subcommand | Action | Details |
|------------|--------|---------|
| `/harness-setup init` | Initialize a new project (CLAUDE.md + Plans.md + hooks + sync + doctor) | `${CLAUDE_SKILL_DIR}/references/init.md` |
| `/harness-setup ci` | CI/CD pipeline setup | `${CLAUDE_SKILL_DIR}/references/ci.md` |
| `/harness-setup harness-mem` | harness-mem integration and memory setup | `${CLAUDE_SKILL_DIR}/references/harness-mem.md` |
| `/harness-setup mirrors` | Update skills/ → public mirror bundle | `${CLAUDE_SKILL_DIR}/references/mirrors-agents-localize.md` |
| `/harness-setup agents` | agents/ agent configuration | `${CLAUDE_SKILL_DIR}/references/mirrors-agents-localize.md` |
| `/harness-setup localize` | Localize CLAUDE.md rules | `${CLAUDE_SKILL_DIR}/references/mirrors-agents-localize.md` |
| marketplace / update | Plugin install, update, dependency policy | `${CLAUDE_SKILL_DIR}/references/marketplace.md` |
| maintenance | File cleanup and tidying | `${CLAUDE_SKILL_DIR}/references/maintenance.md` |

> **Built-in slash discovery (CC 2.1.108+)**:
> Built-in slash commands like `/init` are also discovered.
> Use `/harness-setup init` only when Harness-specific bootstrap is needed.

> **Claude Code setup guidance (CC 2.1.120+)**:
> MCP `alwaysLoad`, `${CLAUDE_EFFORT}`, `claude plugin prune`, `claude project purge`,
> `ANTHROPIC_BEDROCK_SERVICE_TIER`, `claude_code.skill_activated.invocation_trigger`,
> Windows PowerShell primary shell, and deferred tools for forked skills / subagents are
> governed by `docs/claude-code-setup-mcp-telemetry-provider.md` as the source of truth.

## Execution

1. Choose the Quick Reference row matching the user's goal.
2. Read the corresponding `${CLAUDE_SKILL_DIR}/references/*.md`.
3. Follow the steps in the reference file; for operations that support dry-run, run the dry-run first.
4. After setup, verify as needed with `harness doctor`, `bash scripts/sync-skill-mirrors.sh --check`, and `bash scripts/ci/check-consistency.sh`.

## Upstream Policy Anchors

- `docs/plugin-managed-settings-policy.md` — plugin managed settings policy; normal defaults must not inherit managed marketplace restrictions.

## Reference Index

- `${CLAUDE_SKILL_DIR}/references/init.md` — init, Go binary verification, plugin sync, doctor.
- `${CLAUDE_SKILL_DIR}/references/ci.md` — GitHub Actions CI setup.
- `${CLAUDE_SKILL_DIR}/references/harness-mem.md` — memory directory and template setup.
- `${CLAUDE_SKILL_DIR}/references/mirrors-agents-localize.md` — mirror sync, agent setup, localization.
- `${CLAUDE_SKILL_DIR}/references/marketplace.md` — plugin marketplace install/update and managed dependency policy.
- `${CLAUDE_SKILL_DIR}/references/maintenance.md` — cleanup commands and related skills.

## Related Skills

- `harness-sync` — Check alignment across config, Plans, and git state
- `harness-work` — Execute implementation tasks
- `harness-review` — Quality review
- `maintenance` — File cleanup (consolidated here)
