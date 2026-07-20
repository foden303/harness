# Team Mode and Issue Bridge

Keep `Plans.md` as the source of truth, and use GitHub Issue integration only in the opt-in team mode.

## When to Use Which

- In solo development, do not use the issue bridge
- In team mode, create one tracking issue, and generate sub-issue payloads per task under it as a dry-run
- The issue bridge does not update Plans.md
- It is complete as a dry-run only and does not make actual updates to GitHub

## Conversion Rules

`scripts/plans-issue-bridge.sh` expands each task in Plans.md into the following form:

- tracking issue
  - a parent issue for aggregation
  - puts the list of phases and the list of tasks in the body
- sub-issue
  - an individual payload per task
  - keeps `task id`, `DoD`, `Depends`, and `Status` in the body

## Example

```bash
scripts/plans-issue-bridge.sh --team-mode --plans Plans.md
```

Specifying `--format markdown` switches to a human-readable dry-run.

## Why This Is Nice

- You can keep Plans.md as the source of truth as-is
- You can build issue-based visibility for team work only
- It does not add extra weight to solo development
