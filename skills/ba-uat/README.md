# ba-uat

Turn a ticket's **acceptance criteria** into two things people can use the same
day: **QA test cases** with concrete data, and a **UAT checklist** the client
or business user can walk through and sign.

## Quick start

```bash
# One story
/ba-uat DPD-901

# Every story under an Epic, published under a Confluence page on approval
/ba-uat DPD-832 --confluence https://<site>/wiki/spaces/DPD/pages/123456

# A release's stories, plus a CSV for the test tool
/ba-uat --jql "fixVersion = 2.4 AND type = Story" --csv

# After the requirement changed: show added / changed / removed cases
/ba-uat DPD-832 --refresh

# Only the business checklist, never touch JIRA or Confluence
/ba-uat DPD-901 --only uat --draft-only
```

The skill reads the tickets, checks each AC row is testable, writes both
artifacts, shows a coverage table, saves everything under
`.claude/state/ba-uat/<slug>/`, and publishes only when you say so. An AC row
it cannot test without guessing is listed under **Cannot test yet** with a
pointer to `/ba-story-verify <KEY>`.

## Example

Input: `DPD-901 [Transactions] [BE] Export the filtered list to CSV` (the story
in [ba-ticket's README](../ba-ticket/README.md)): 3 AC rows, 3 Fields rows,
3 Edge rows, roles Admin / Finance (can export) and Viewer (cannot).

### test-cases.md (excerpt)

```markdown
# Test cases — DPD-901 Export the filtered list to CSV

**Source:** DPD-901 · **Generated:** 2026-10-26 · **Tickets:** 1 · **Cases:** 11

## Coverage

| Ticket | AC rows covered | Fields covered | Edge cases covered | Roles covered | Cannot test yet |
| --- | --- | --- | --- | --- | --- |
| DPD-901 | 3 / 3 | 3 / 3 | 3 / 3 | 3 / 3 | 0 |

## DPD-901 — Export the filtered list to CSV

**Roles:** Admin, Finance (export) · Viewer (no export) · **Assumptions:** none

| ID | Title | Traces to | Preconditions | Steps | Test data | Expected result | Type |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TC-DPD-901-1 | Export 120 filtered rows | AC-1 | Logged in as Finance; Org Alpha has 120 transactions in Sept 2026 | 1. Open Transactions<br>2. Filter Month = September 2026<br>3. Click Export | Month = September 2026 | A CSV with 120 rows and the list's columns downloads | positive |
| TC-DPD-901-2 | Export keeps the sort order | AC-2 | As TC-1 | 1. Sort by Amount, high to low<br>2. Click Export | Top row amount $4,980.00 | File rows are in the same order; first row $4,980.00 | positive |
| TC-DPD-901-3 | Viewer has no Export button | AC-3, Role: Viewer | Logged in as Viewer (viewer.lan@example.com) | 1. Open Transactions | — | The Export button is not shown | permission |
| TC-DPD-901-4 | No filter exports all rows | F-Filters (empty) | Org Alpha has 1,240 transactions | 1. Clear all filters<br>2. Click Export | No filters | CSV with 1,240 rows | edge |
| TC-DPD-901-5 | Default sort is date, newest first | F-Sort (default) | As TC-4 | 1. Do not sort<br>2. Click Export | — | First row is the newest transaction | edge |
| TC-DPD-901-6 | File name and encoding | F-File | As TC-1 | 1. Click Export | Payee "Nguyễn Văn An" in the data | File `transactions-2026-10-26.csv`, UTF-8, header row, "Nguyễn Văn An" shown correctly | positive |
| TC-DPD-901-7 | Exactly 50,000 rows (max) | F-Filters (max), E-2 | Filter matches 50,000 rows | 1. Click Export | 50,000 rows | CSV with 50,000 rows downloads | edge |
| TC-DPD-901-8 | No rows match | E-1 | Filter matches 0 rows | 1. Filter Payee = "ZZZ-none" | Payee = ZZZ-none | Export disabled with "Nothing to export" | negative |
| TC-DPD-901-9 | 50,001 rows (just over max) | E-2 | Filter matches 50,001 rows | 1. Click Export | 50,001 rows | Message: "Narrow your filter to 50,000 rows or fewer" | negative |
| TC-DPD-901-10 | Export over 30 s | E-3 | Export delayed past 30 s in the test environment | 1. Click Export | 31 s delay | Error toast; Retry works | negative |
| TC-DPD-901-11 | Admin can export | Role: Admin | Logged in as Admin (admin.mai@example.com) | 1. Click Export | — | CSV downloads | permission |
```

### uat-checklist.md (excerpt)

```markdown
# Acceptance checklist — Transaction export

**Version / sprint:** 2.4 · **Prepared:** 2026-10-26 · **Covers:** DPD-901, DPD-902

## Before you start

- Log in to the test site as a Finance user
- Org Alpha has transactions for September 2026

## Export what I filtered

| # | Scenario | What to do | What you should see | Pass | Fail | Comment | Ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1.1 | Export a month | Filter to September 2026, click Export | A spreadsheet file downloads with only September rows | ☐ | ☐ | | DPD-901 |
| 1.2 | Keep my sort | Sort by amount, highest first, click Export | The file is in the same order as the screen | ☐ | ☐ | | DPD-901 |
| 1.3 | Nothing to export | Filter to a payee that does not exist | Export is greyed out with "Nothing to export" | ☐ | ☐ | | DPD-901 |
| 1.4 | Too many rows | Remove all filters on a large organization | A message asks you to narrow the filter | ☐ | ☐ | | DPD-901 |

## Who can export

| # | Scenario | What to do | What you should see | Pass | Fail | Comment | Ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.1 | Viewers cannot export | Log in as a Viewer, open Transactions | There is no Export button | ☐ | ☐ | | DPD-901 |

## Sign-off

| | |
| --- | --- |
| **Tester name** | |
| **Date tested** | |
| **Decision** | ☐ Accept · ☐ Accept with issues · ☐ Reject |
```

## Untestable AC

If DPD-901 had said "Then large exports are refused", the row would not get a
guessed limit. It would appear as:

| Ticket | Row | Reason | Next step |
| --- | --- | --- | --- |
| DPD-901 | AC-4 | "Large" has no number | `/ba-story-verify DPD-901` |

and the checklist would list it under **Not included in this round**.
