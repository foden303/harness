---
description: Quality policy for tracking CC updates
globs: ["CLAUDE.md", "docs/CLAUDE-feature-table.md"]
---

# CC Update Tracking Policy

Quality standards for updating the Feature Table when supporting a new version of Claude Code.

## Basic Principle

An addition to the Feature Table must be accompanied by a **corresponding implementation change** or an **explicit classification of category C (CC auto-inherited)**.

A PR must not be merged in a state where a row was "just added to the Feature Table."

## 3-Category Classification

| Category | Definition | PR merge |
|---------|------|----------|
| **(A) Has implementation** | Has a corresponding implementation change in hooks / scripts / agents / skills / core | Allowed |
| **(B) Just written** | Only the Feature Table changed. No implementation | **Not allowed** -- presenting an implementation proposal is required |
| **(C) CC auto-inherited** | A fix in CC itself, requiring no change on the Harness side (performance improvement, bug fix, etc.) | Allowed (mark it "CC auto-inherited" in the Feature Table) |

## Rules

### 1. Feature Table additions must be accompanied by implementation or classification

When adding a new row to the Feature Table, satisfy one of the following:

- **(A)** The same PR includes a corresponding implementation file change
- **(C)** The Feature Table explicitly marks it as "CC auto-inherited"

If neither applies, the item is judged as category B (just written).

### 2. When category B is detected, block the PR and require an implementation proposal

If even one category B item exists:

- **Block** the PR merge
- For each category B item, require an **implementation proposal** including:
  - An explanation of the value added uniquely by Harness
  - The target files and specific changes
  - The user-experience improvement (before / after)

After the implementation proposal is approved, create an additional commit with the implementation or a follow-up PR.

### 3. Adding a "value added" column is recommended

Adding a "value added" column that visualizes the A / B / C classification in the Feature Table is recommended.

```markdown
| Feature | Skill | Purpose | Value added |
|---------|-------|---------|---------|
| PostCompact hook | hooks | Context re-injection | A: Has implementation |
| Streaming leak fix | all | Memory leak fix | C: CC auto-inherited |
```

This column:
- Lets reviewers immediately spot leftover category B items
- Self-documents why each Feature Table item is there
- Provides a reference to past judgments during future CC update integrations

## Scope

This policy applies when changing the following files:

- The Feature Table section of `CLAUDE.md`
- `docs/CLAUDE-feature-table.md`

It does not apply to normal implementation PRs, documentation fixes, or release work.
