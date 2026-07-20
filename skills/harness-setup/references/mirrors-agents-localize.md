# Harness Setup Reference: mirrors-agents-localize

This file is part of `${CLAUDE_SKILL_DIR}/references/` for `harness-setup`.

### mirrors — public skill bundle sync

On Windows with `core.symlinks=false`, repository symlinks become regular files, and `harness-*` skills can disappear from the command list. The public bundle is synced as a real-directory mirror.

```bash
./scripts/sync-skill-mirrors.sh
./scripts/sync-skill-mirrors.sh --check
```

Sync targets:

- `skills/`

### agents — agent configuration

Configure the three-agent structure under agents/.

```
agents/
├── worker.md      # Implementation (task-worker + error-recovery)
└── reviewer.md    # Review (code-reviewer + plan-critic)
```

### localize — rule localization

Adapt the rules in `.claude/rules/` to the current project.

```bash
# List rules
ls .claude/rules/

# Add project-specific rules
cat >> .claude/rules/project-rules.md << 'EOF'
# Project-Specific Rules
[project-specific rules]
EOF
```

