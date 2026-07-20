# Harness Setup Reference: init

This file is part of `${CLAUDE_SKILL_DIR}/references/` for `harness-setup`.

## Subcommand details

### init — project initialization

Set up Harness in a new project.

**Generated files**:
```
project/
├── CLAUDE.md            # Project configuration
├── Plans.md             # Task management (empty template)
├── .claude/
│   ├── settings.json    # Claude Code settings
│   └── hooks.json       # Hook configuration (Go binary)
└── hooks/
    ├── pre-tool.sh      # Thin shim (→ core/src/index.ts)
    └── post-tool.sh     # Thin shim (→ core/src/index.ts)
```

**Flow**:
1. Detect the project type (Node.js/Python/Go/Rust/other)
2. Generate a minimal CLAUDE.md
3. Generate a Plans.md template
4. Place hooks.json
5. **Go binary verification**: confirm the binary is available with `harness version` (Node.js not required from v4.0)
6. **Plugin file sync**: sync files under `.claude-plugin/` to the latest with `harness sync`
7. **Health check**: pass all checks with `harness doctor`; propose fixes for any issues

### Go binary verification

```bash
# Confirm the binary exists and works
harness version
# e.g.: harness v4.0.0 (go1.22.0, darwin/arm64)
```

From v4.0, the Harness core engine moved to a Go binary.
Node.js is not required. Use the binary at `bin/harness` (or `harness` on PATH).

### Plugin file sync

```bash
# Sync files under .claude-plugin/ to the latest
harness sync

# Preview the sync only (no changes)
harness sync --dry-run
```

`harness sync` propagates changes from the skills/ SSOT to the configured skill mirror.
Always run it after init.

### Health check

```bash
# Run all checks
harness doctor
```

`harness doctor` verifies the following:

| Check | Detail |
|-------|--------|
| Binary | Whether `harness version` returns normally |
| Plugin config | Whether `.claude-plugin/plugin.json` has a valid format |
| hooks placement | Whether hooks exist at the correct paths |
| mirror sync | Whether skills/ and the mirror match |
| CLAUDE.md | Whether required sections exist |

If a problem is detected, it suggests a fix command.

