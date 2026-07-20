# Version Drift Detection

## Check Targets

The version in VERSION and .claude-plugin/plugin.json must always match.
When a mismatch is detected, propose running `./scripts/sync-version.sh` (do not run it automatically).

## Feature Table Freshness

Propose deleting "planned (not yet implemented)" / "to be implemented" items in
docs/CLAUDE-feature-table.md after 6 months have elapsed.

## Why this rule is needed

D2 (inaccurate information) recurs even after being fixed once.
Version mismatch and Feature Table rot are the most common drift patterns.
