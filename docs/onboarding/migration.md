# Existing User Migration

Phase 73 keeps existing users on the same tool-first boundary as new users, but
migration is report-first. The default path is to inspect impact, preserve
backups, and avoid cleanup until a separate explicit confirmation gate exists.

## First Command

Run the report from a Harness checkout:

```bash
bin/harness doctor --migration-report
```

This command is non-destructive. It does not delete plugin caches, local skills,
symlinks, project state, or harness-mem data.

## What The Report Checks

| Area | Impact | Compatibility rule | Rollback / backup |
|---|---|---|---|
| Claude plugin cache | Stale cached plugin versions can keep Claude Code on older Harness behavior. | Use Claude Code plugin manager commands; do not hand-delete cache entries as part of the report. | `/plugin update harness` or uninstall/reinstall through the plugin manager. |
| Claude slash entries | Missing `harness-*` skill entries can make `/harness-plan` or `/harness-work` unavailable. | Missing entries are evidence of install drift, not proof that the host is unsupported. | Update or reinstall the plugin, then run `/harness-setup`. |
| harness-mem state | Memory continuity can span Claude Code sessions. | Do not delete the memory DB; the report does not read or delete DB contents. | Keep `~/.harness-mem/` and project `.harness-mem/state/`; use `harness mem doctor`, and only run purge with explicit confirmation. |

## Compatibility Contract

- Claude Code is the only `supported` route, and the only one that has been.
- Adapters for other CLIs were tracked pre-1.0 and removed; no migration path
  is owed to them because none was ever published as installable.
- `not_observed != absent`: missing local evidence means the report could not
  observe a route, not that the capability is impossible.

## Safe Migration Order

1. Run `bin/harness doctor --migration-report`.
2. If Claude plugin cache or slash entries are stale, update through Claude Code
   plugin commands first.
3. If harness-mem state is observed, preserve it; do not purge during adapter
   migration.

No destructive cleanup is part of Phase 73.1.9.
