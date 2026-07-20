# Versioning Rules

Harness's version management standard. Follows SemVer (Semantic Versioning).

## Version Determination Criteria

| Type of change | Version | Example |
|-----------|----------|-----|
| Wording fix/addition to skill definition (SKILL.md) | **patch** (x.y.Z) | Minor template tweak, description improvement |
| Documentation/rule file update | **patch** (x.y.Z) | CHANGELOG rewrite, rules/ addition |
| Bug fix in hooks/scripts | **patch** (x.y.Z) | Escaping fix in task-completed.sh |
| New flag/subcommand added to existing skill | **minor** (x.Y.0) | `--snapshot`, `--auto-mode` |
| New skill/agent/hooks added | **minor** (x.Y.0) | New skill `harness-foo` |
| Change to the Go guardrail engine | **minor** (x.Y.0) | New rule added, existing rule changed |
| Compatibility with a new Claude Code version | **minor** (x.Y.0) | CC v2.1.72 support |
| Breaking change (old skill retired, format incompatibility) | **major** (X.0.0) | Removal of Plans.md v1 support |

## Decision Flowchart

```
Does existing behavior break?
├─ Yes → major
└─ No → Can the user do something new?
    ├─ Yes → minor
    └─ No → patch
```

## Batch Release Recommendation

- **When multiple Phases are completed on the same day**: consolidate into a single minor release
- **Phase completion + documentation fix**: minor for the Phase, documentation fix bundled in (do not make a separate release)
- **CC compatibility + feature addition**: may be consolidated into a single minor

### Bad Example

```
v3.6.0 (03/08 AM) — Phase 25
v3.7.0 (03/08 PM) — Phase 26    ← avoid 2 minors on the same day
v3.7.1 (03/09)    — Auto Mode
```

### Good Example

```
v3.6.0 (03/08) — Phase 25 + Phase 26    ← consolidated into 1 minor
v3.6.1 (03/09) — Auto Mode prep         ← prep is patch
```

## Pre-Release Check

1. **List the changes since the previous release**
2. **Determine the version type against the criteria**
3. **Consider batching multiple same-day changes**
4. **Verify the 4-point sync of VERSION / plugin.json / harness.toml / CHANGELOG**
5. **Verify that git tags are contiguous with no gaps**

## Prohibitions

- Deleting/rolling back tags (published versions are immutable)
- Two or more minor bumps on the same day
- Minor bump for a patch-level change

## Release Train Proposal

Rather than releasing "per commit / PR," accumulate changes in `[Unreleased]` of `CHANGELOG.md`,
**propose a candidate** once the criteria are met, and only cut a release when a human says GO (avoiding fine-grained releases).

- The accumulation layer touches only `[Unreleased]`; it does not bump VERSION / plugin.json / harness.toml.
- The proposer `harness-release --check` is read-only. When a trigger fires, it merely displays `RELEASE_CANDIDATE`
  (with an estimated bump) and does not rewrite anything on the version side.
- v1 trigger (start with just 1 rule): **7 days elapsed** since the last tag OR `### Breaking` present
  in `[Unreleased]`. When `### Security` is present, shorten to **2 days**. Do not add a
  multi-threshold matrix such as an N-count until cadence becomes a problem in practice.
- This is a **proposal**, not a gate. Ignoring it costs nothing; it will be re-proposed at the next threshold. Display it
  passively in the Session Monitor as a tri-state (Candidate / None / NotApplicable),
  following the 3-state naming in `active-watching-test-policy.md` (no candidate is silent).
- Once a human says GO, the existing `harness-release` runs as-is (bump detection → 4-point sync →
  CHANGELOG promote → PR → main → tag → GitHub Release). Batching consolidates the 4-point sync into
  a single time per release, structurally preventing the "2 minors on the same day" violation.

## Post-1.0 Baseline

v1.0.0 is the first published release: no tag or GitHub Release existed before
it, and the pre-1.0 version numbers (up to `5.0.0`) were never distributed. They
survive only in git history and `.claude/memory/archive/Plans-pre-1.0.md`.

From v1.0.0 onward, published versions are immutable and the criteria above
apply as written.
