# ba-spec

Write a **feature spec / PRD** for a feature too big for one ticket: the flows,
rules, data and limits every team must agree on before stories are written.
Built from a `ba-discovery` brief, a rough idea, or an existing Confluence page
you want brought up to standard.

## Quick start

```bash
# From a discovery brief, publish into a space (asks before writing)
/ba-spec .claude/state/ba-discovery/dpd-self-serve-reporting/brief.md \
  --confluence https://<site>/wiki/spaces/DPD

# From an idea (expect more questions)
/ba-spec "self-serve transaction reporting for finance" --draft-only

# Revise an existing spec page in place (backs it up, never overwrites newer edits)
/ba-spec --page https://<site>/wiki/spaces/DPD/pages/789

# Walk the flow without writing anything
/ba-spec brief.md --dry-run
```

The skill drafts every section the input answers, runs an 18-point readiness
check (testable rules, flows with end states and error paths, every field with
required + rules, every brief requirement traced or dropped), asks only the
gaps, shows the page, and publishes only when you approve. It ends with the
proposed epics and the exact `ba-ticket` command for each.

## What a spec looks like (excerpt)

```markdown
# Self-serve transaction reporting: feature spec

**Project:** DPD · **Status:** In review · **Owner:** Hoa (BA) · **Updated:** 2026-10-26 · **Source:** .claude/state/ba-discovery/dpd-self-serve-reporting/brief.md

## 1. Overview

**Problem.** Finance asks Support for transaction reports about 40 times a month and waits up to 2 days.

**Goal.** Finance and Support export the transaction data they need themselves, in under a minute.

**Success metrics**

| Metric | Today | Target | How measured |
| --- | --- | --- | --- |
| Report requests to Support | 40 / month | under 5 / month | Support tickets tagged "report" |

## 2. Users & personas

| Persona | Role in the product | Goal in this feature | Permissions |
| --- | --- | --- | --- |
| Finance analyst | Finance | Month-end reconciliation | View + export |
| Support agent | Support | Answer payment disputes | View + export |
| Merchant admin | Viewer | See transactions | View only |

## 3. Scope

**In**
- CSV export of the filtered transaction list
- Audit record of every export

**Out**
- Scheduled / emailed exports — not planned (brief D-1)

**Later**
- Excel export — next quarter

## 4. User flows

### F-1 Export the filtered list

**Actor:** Finance analyst · **Starts when:** the analyst has filtered the transaction list

1. The analyst clicks Export.
2. The system checks the row count against BR-2.
3. The system builds the CSV with the list's columns in the list's order.
4. The file downloads as `transactions-<date>.csv`.

**End state:** the file is downloaded and an export record exists (BR-3).

**Error paths**
- At step 2, if more than 50,000 rows match: "Narrow your filter to 50,000 rows or fewer"; nothing is exported.
- At step 3, if building takes longer than 30 s: error with Retry; no export record is written.

## 5. Business rules

| ID | Rule | Applies to | Source |
| --- | --- | --- | --- |
| BR-1 | When a user without the Finance or Support role opens the list, the Export action is not shown | F-1 | R-1, BA answer 2026-10-26 |
| BR-2 | When more than 50,000 rows match the filter, the export is refused with a message | F-1 step 2 | brief BR-2 |
| BR-3 | When an export succeeds, a record with user, time and filters is stored for 5 years | F-1 end state | R-4, BA answer 2026-10-26 |

## 6. Data

| Entity | Field | Required | Rules | Default | Source |
| --- | --- | --- | --- | --- | --- |
| Export record | Requested by | Yes | The signed-in user | none | system |
| Export record | Filters | Yes | The filters active at export time, as shown on screen | none | system |
| Export record | Row count | Yes | 0 to 50,000 | none | system |

## 7. Screens / UI
- Transaction list, Export button — <figma link> — states: enabled, disabled ("Nothing to export"), error with Retry

## 8. Non-functional

| Area | Requirement |
| --- | --- |
| Performance | An export of one month of data (up to 50,000 rows) finishes in under 30 s |
| i18n | Vietnamese characters in names are preserved (UTF-8 with BOM) |

## 13. Traceability

| Requirement | Covered by | Note |
| --- | --- | --- |
| R-1 Export the filtered list to CSV | F-1, BR-1, BR-2 | |
| R-2 Keep the sort order | F-1 step 3 | |
| R-3 Under 30 s for one month | §8 Performance | |
| R-4 Record every export | BR-3, §6 Export record | |
```

Then the hand-off:

```
Proposed epics
| # | Epic                               | Covers             | Depends on |
| 1 | [Transactions] CSV export          | F-1, BR-1, BR-2    | none       |
| 2 | [Transactions] Export audit trail  | BR-3, §6           | 1          |

/ba-ticket https://<site>/wiki/spaces/DPD/pages/789 --epic --project DPD   # epic 1
/ba-ticket https://<site>/wiki/spaces/DPD/pages/789 --epic --project DPD   # epic 2
```

## Revise mode

`--page <url>` reads the page, saves its body and version to
`.claude/state/ba-spec/<slug>/original.md`, reshapes it into the template
without dropping content (your own extra headings are kept after section 13),
and asks before updating. If someone edits the page while you are answering
questions, the skill sees the newer version, folds it in, and shows you the
result again instead of overwriting it.
