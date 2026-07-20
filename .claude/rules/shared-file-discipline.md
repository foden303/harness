# Shared File Discipline

Harness's **convention for editing shared files during parallel worktree execution**.
Introduced in Phase 92.1.3. Whereas Worktree Root Discipline (`spec.md`) defines "where to place the worktree,"
this convention defines "what may be written inside the worktree."

## Why This Rule Is Needed

During the parallel preparation of Phase 92.1.1, it became apparent that when 2 workers try to append to `CHANGELOG.md`
at the same time, there is a risk of a cherry-pick conflict. The Lead instructed both workers to not touch CHANGELOG,
and switched to appending the 2 entries together at integration time.

Similarly, when multiple workers edit `Plans.md` / `spec.md` simultaneously,
a conflict near the same lines occurs at cherry-pick time even if it is append-only.
Bumping `VERSION` inside a worktree breaks the 3-point sync with the trunk (VERSION / plugin.json / harness.toml).
Regenerating `bin/harness` or mirrors (e.g. `.agents/skills/`) per worktree becomes
a breeding ground for binary conflicts and mirror drift.

Specify these 3 invariants in the Lead / Worker sprint contract
so they are not renegotiated on every parallel run.

## The 3 Invariants

### Invariant 1: Shared append files are owner-assigned append-only blocks

When parallel workers edit `Plans.md` / `CHANGELOG.md` / `spec.md` simultaneously, a cherry-pick conflict occurs.

- During parallel execution, assign **one owner** to each file; other workers do not touch it
- Files with no owner are **edited by the Lead at integration time** (workers do not touch them)
- The owner writes only an **append-only block** (rewriting/deleting existing lines is prohibited even for the owner, except during Lead integration)

**Why**: concurrent edits to the same file are hard to resolve even with rerere.
Narrowing to a single owner lets the conflict surface be fixed in advance via the sprint contract.

### Invariant 2: Do not bump `VERSION` inside a worktree

A version bump is a **release-only operation**, performed only by `./scripts/sync-version.sh bump` on the trunk.
The 3-point sync of VERSION / `.claude-plugin/plugin.json` / `harness.toml` happens only at release time.

**Why**: an in-worktree bump leaves the 3 files inconsistent after the trunk merge.
Normal PRs do not touch VERSION and instead append to CHANGELOG `[Unreleased]` (see `github-release.md`).

### Invariant 3: Regenerate generated artifacts once on the trunk

Generated artifacts such as the `bin/harness` binary and mirrors (e.g. `.agents/skills/`)
are not regenerated per worktree, but **once, on the trunk after integration**.

**Why**: per-worktree regeneration is a breeding ground for binary conflicts and mirror drift.
Running it once on the trunk after the Lead's cherry-pick keeps the SSOT of the generated artifacts on the trunk.

## owner-assign Example

When running Phase 92.1.2 (reap script) and 92.1.3 (docs convention) in parallel:

| Target | owner | Notes |
|------|-------|------|
| `CHANGELOG.md` | none | Neither worker touches it; the Lead appends the 2 entries together at integration time |
| `docs/team-composition.md` / `spec.md` | 92.1.3 owner | 92.1.2 does not touch it |
| `.claude/rules/shared-file-discipline.md` | 92.1.3 owner | The source of truth for this convention |
| `scripts/` / `tests/` | 92.1.2 | No conflict if only creating new files (new files need no owner concept) |

The Lead specifies the table above in the sprint contract (at task decomposition time) and reflects it in the "must not touch" section of the worker prompt.

## Related Files

- [`spec.md` — Worktree Root Discipline / Tri-Tool Parallel Collaboration Contract](../../spec.md)
- [`docs/team-composition.md` — parallel worktree root / team operation](../../docs/team-composition.md)
- [`.claude/rules/github-release.md`](github-release.md) — VERSION bump and CHANGELOG operation
- [`scripts/ci/check-consistency.sh`](../../scripts/ci/check-consistency.sh) — existence check for this convention file (Section 15)
