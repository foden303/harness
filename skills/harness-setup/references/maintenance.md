# Harness Setup Reference: maintenance

This file is part of `${CLAUDE_SKILL_DIR}/references/` for `harness-setup`.

## Maintenance — file cleanup

Periodic maintenance tasks:

| Task | Command |
|------|---------|
| Delete old logs | `find .claude/logs -mtime +30 -delete` |
| Compact Plans.md | Move completed tasks to the archive section |
| Delete old traces | `tail -1000 .claude/state/agent-trace.jsonl > /tmp/trace && mv /tmp/trace .claude/state/agent-trace.jsonl` |

## Related Skills

- `harness-plan` — Create a project plan after setup
- `harness-work` — Execute tasks after setup
- `harness-review` — Review the setup configuration
