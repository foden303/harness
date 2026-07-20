# Harness Setup Reference: harness-mem

This file is part of `${CLAUDE_SKILL_DIR}/references/` for `harness-setup`.

### harness-mem — memory setup

Configure Unified Harness Memory.

```bash
# Create memory directories
mkdir -p .claude/agent-memory/harness-worker
mkdir -p .claude/agent-memory/harness-reviewer

# Place the MEMORY.md template
cat > .claude/agent-memory/harness-worker/MEMORY.md << 'EOF'
# Worker Agent Memory

## Project Context
[project overview]

## Patterns
[learned patterns]
EOF
```

