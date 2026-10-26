# Report template (step 4)

Fill this and save to `.claude/state/ba-trace/<slug>/trace.md`. `<slug>` is the
Epic key, the JQL's short form, or the brief name in kebab-case. A re-run
overwrites `trace.md` and keeps the previous one as `trace.prev.md` so changes
can be compared.

```markdown
# Traceability: <scope title>

**Scope:** <Epic DPD-832 "Self-serve discounts" (12 tickets)> · **Requirements from:** <brief checkout/spec.md (9 R-n) | ticket AC rows>
**Repo:** <path> (<default branch>, <n> commits searched) · **Generated:** <date>

## Evidence sources

| Source | State |
| --- | --- |
| JIRA | available |
| Git commits | available — 23 commits reference keys in scope |
| PRs | from merge commits (gh not installed) |
| Tests | available — 3 test folders searched |
| UAT (ba-uat) | not run yet — no results recorded |

<When a source is n/a, one plain sentence, e.g. "No commit in this repo mentions
any JIRA key, so commits cannot be traced here. This says nothing about the work
done; commits may live in another repo or not carry keys.">

## Coverage

| Metric | Value |
| --- | --- |
| Requirements with a ticket | 8 / 9 (89%) |
| Requirements with a commit | 6 / 9 (67%) |
| Requirements with a test | 5 / 9 (56%), 1 by wording only |
| UAT passed | n/a — no UAT results recorded |

## Matrix

| Requirement | Ticket | Status | Commits | PR | Tests | UAT |
| --- | --- | --- | --- | --- | --- | --- |
| R-1 Cap discount at 30% | DPD-903 | Done | a1b2c3d, 9f8e7d6 | #41 | tests/discount.test.ts:42 | — |
| R-2 Partner orders need a code | DPD-903 | Done | a1b2c3d | #41 | — | — |
| R-3 Show the badge | DPD-904 | In Progress | 77aa12c | — | e2e/checkout.spec.ts:88 (wording) | — |
| R-4 Export discount report | — | — | — | — | — | — |

<One row per requirement × ticket. A requirement with two tickets gets two rows.
Empty evidence is "—"; a source that does not exist is "n/a". Keep commit cells
to at most 3 short hashes, then "+<n>".>

## Gaps

| # | Gap | Where | Evidence | Suggested action | Run |
| --- | --- | --- | --- | --- | --- |
| 1 | Requirement with no ticket | R-4 | No ticket names R-4; BA confirmed none | Write a ticket | `/ba-ticket "Export discount report" --epic-key DPD-832` |
| 2 | Done with no commit | DPD-907 | 0 commits for DPD-907 in this repo | Ask Minh Le where it was built | ask on the ticket |
| 3 | AC with no test | R-2 (DPD-903 AC 3) | No test mentions DPD-903 AC 3 or "requires a code" | Write test cases | `/ba-uat DPD-903` |

## Orphan tickets

<Only with --brief.> DPD-911 "Refactor promo service" — traced to no requirement.

## Next actions

- `/ba-ticket` for R-4
- `/ba-uat DPD-832` for 3 AC with no test
- Ask the owner of DPD-907 where the work lives
```

Rules:

- Requirement text in the matrix: the first ~8 words; full text lives in
  `evidence.json`.
- Status is the JIRA status name; `unknown (JIRA unreachable)` when traced from
  the brief only; `unreadable` when the ticket could not be read.
- No `TBD`, `???`, `etc.`. No percentages for an `n/a` source.
- The same content is what `--html` renders and what `--confluence` publishes.
