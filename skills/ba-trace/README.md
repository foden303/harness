# ba-trace

"Is every requirement built and tested?" **ba-trace** answers from evidence: it
links each requirement to its tickets, their status, the commits that mention
them, the PRs, the tests and the UAT results, and lists what is missing with the
skill that fixes it. It changes nothing (publishing to Confluence happens only
if you ask and approve).

## Quick start

```bash
# An Epic; each child ticket's AC rows are the requirements
/ba-trace DPD-832

# Requirements from a brief/spec with R-n IDs (ba-discovery / ba-spec output)
/ba-trace DPD-832 --brief .claude/state/ba-spec/checkout/spec.md

# Commits live in another local repo
/ba-trace DPD-832 --repo ../checkout-service

# Also a single-file HTML, and publish to Confluence on approval
/ba-trace DPD-832 --html --confluence https://<site>/wiki/spaces/DPD/pages/123456
```

The report is saved to `.claude/state/ba-trace/<slug>/trace.md` (plus
`evidence.json`, and `trace.html` with `--html`).

Commits are found by the JIRA key in the message — `[DPD-903]` (the convention
`harness-flow` uses) or the bare `DPD-903`. If your repo's commits carry no keys
at all, the report says so plainly and shows the commit column as `n/a`, not 0%.

## Example

```bash
/ba-trace DPD-832 --brief .claude/state/ba-spec/discounts/spec.md
```

```markdown
# Traceability: Self-serve discounts

**Scope:** Epic DPD-832 (6 tickets) · **Requirements from:** brief discounts/spec.md (5 R-n)
**Repo:** . (main, 412 commits searched) · **Generated:** 2026-10-26

## Evidence sources

| Source | State |
| --- | --- |
| JIRA | available |
| Git commits | available — 14 commits reference keys in scope |
| PRs | from merge commits (gh not installed) |
| Tests | available — tests/, e2e/ searched |
| UAT (ba-uat) | 4 cases recorded, run 2026-10-22 |

## Coverage

| Metric | Value |
| --- | --- |
| Requirements with a ticket | 4 / 5 (80%) |
| Requirements with a commit | 3 / 5 (60%) |
| Requirements with a test | 3 / 5 (60%), 1 by wording only |
| UAT passed | 2 / 5 (40%) |

## Matrix

| Requirement | Ticket | Status | Commits | PR | Tests | UAT |
| --- | --- | --- | --- | --- | --- | --- |
| R-1 Cap discount at 30% of total | DPD-903 | Done | a1b2c3d, 9f8e7d6 | #41 | tests/discount.test.ts:42 | pass |
| R-2 Partner orders require a code | DPD-903 | Done | a1b2c3d | #41 | — | — |
| R-3 Badge shows the max discount | DPD-904 | In Progress | 77aa12c | — | e2e/checkout.spec.ts:88 (wording) | — |
| R-4 Finance exports a discount report | — | — | — | — | — | — |
| R-5 Every applied code is audited | DPD-907 | Done | — | — | tests/audit.test.ts:12 | fail |

## Gaps

| # | Gap | Where | Evidence | Suggested action | Run |
| --- | --- | --- | --- | --- | --- |
| 1 | Requirement with no ticket | R-4 | No ticket names R-4; BA confirmed none | Write a ticket | `/ba-ticket "Finance exports a discount report" --epic-key DPD-832` |
| 2 | Done with no commit | DPD-907 | 0 commits mention DPD-907 in this repo | Ask Minh Le where it was built | ask on the ticket |
| 3 | Failed UAT | R-5 (DPD-907) | UAT item for R-5 marked Fail on 2026-10-22 | Fix, then re-run UAT | `/harness-bugfix`, then `/ba-uat --refresh` |
| 4 | AC with no test | R-2 (DPD-903) | No test mentions DPD-903 or "require a code" | Write test cases | `/ba-uat DPD-903` |

## Orphan tickets

DPD-911 "Refactor promo service" — traced to no requirement.

## Next actions

- `/ba-ticket` for R-4
- `/ba-uat DPD-903` for R-2
- Ask the owner of DPD-907 where the work lives, and fix the failed UAT
```

## What it never does

- Write to JIRA, git or GitHub.
- Publish to Confluence without your approval (and never with `--draft-only`).
- Guess which ticket covers a requirement — it asks.
- Report 0% for a source that does not exist (no keys in commits, no tests, no UAT).
