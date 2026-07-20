# Local Harness Environment Cleanup

Last updated: 2026-05-28

Scope: reduce duplicate Harness skills/plugins in Claude Code without
destructive cleanup by default.

## Why Duplicates Happen

Duplicates arise when more than one Harness route exposes the same skill names:
the Claude plugin cache, old plugin versions, and a local `--plugin-dir .`
checkout can all stack.

Clean Mode reduces duplicates by keeping one Harness route active and
archiving obvious duplicate routes after user confirmation.

## Profiles

| Profile | When to use | Harness behavior |
|---------|-------------|------------------|
| `clean` (default) | You want one Harness route and fewer duplicate entries | Diagnose all origins; recommend archive/disable of non-primary routes |
| `compatibility` | You intentionally keep more than one Harness route active (e.g. both the marketplace plugin and a local `--plugin-dir .` checkout) | Warn about duplicates; recommend explicit invocation (`/harness:harness-plan`) |

## Recommended Primary Routes

| Host | Primary route | Avoid mixing with |
|------|---------------|-------------------|
| Claude Code | `harness@harness-marketplace` plugin | `--plugin-dir .` while marketplace plugin is also enabled |

## Dry-Run Diagnosis

Run:

```bash
bash scripts/diagnose-harness-skill-duplication.sh
bash scripts/diagnose-harness-skill-duplication.sh --profile clean
bash scripts/diagnose-harness-skill-duplication.sh --json
```

The script is **dry-run only**. It never deletes files or edits config.

## Manual Cleanup Checklist (after diagnosis)

1. **Inventory**: note every `harness-*`, `breezing`, and `memory` skill path.
2. **Claude cache**: keep one installed version; archive old
   `~/.claude/plugins/cache/harness-marketplace/harness/*`
   directories that are not your active version.

## Rollback

Before any manual archive:

```bash
ARCHIVE_ROOT="$HOME/.harness-skill-cleanup-archive/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE_ROOT"
# move, do not delete
mv ~/.claude/plugins/cache/harness-marketplace/harness/<old-version> "$ARCHIVE_ROOT/"  # example only
```

Restore by moving directories back from the archive root.

## Verification

After cleanup:

```bash
bash scripts/diagnose-harness-skill-duplication.sh --profile clean
bash tests/test-host-plugin-dist.sh
```

## Related Docs

- `docs/distribution-scope.md`
- `spec.md` Host Distribution Contract and Clean/Compatibility profiles
