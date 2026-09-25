# harness-ba-ticket

Turn a rough idea into a **short, clear JIRA story or Epic**, written from the
BA's point of view, that FE, BE, Data, AI and QA can build and test from without
a follow-up meeting.

## Quick start

```bash
# One story
/harness-ba-ticket "Let finance export the filtered transaction list to CSV" --project DPD

# An epic with its stories
/harness-ba-ticket brief.md --epic --project DPD

# A story under an existing epic
/harness-ba-ticket "..." --epic-key DPD-832

# Rewrite an existing long ticket into this format (updates it on approval)
/harness-ba-ticket DPD-1573

# Markdown only, never touch JIRA
/harness-ba-ticket "..." --draft-only
```

Titles follow `[Area] [Team] ...` for a one-team story, e.g.
`[Admin Portal] [BE] Export audit log API`. When BE and FE deliver one feature
together (the API only exists for that screen), it stays **one story** titled
`[Admin Portal] Invite a user into an organization` with `Teams: BE, FE, QA`.
Split per team only when each part can ship on its own.

The skill writes a draft, asks you only what is missing (pick an option or type
your own), shows the final ticket, and creates it in JIRA only when you say so.

## What a story looks like

```markdown
# [Transactions] [BE] Export the filtered list to CSV

**Epic:** DPD-832 · **Teams:** BE, QA · **Depends on:** none (FE screen: DPD-841)

## Why
**As a** finance analyst, **I want to** export the transactions I have filtered,
**so that** I can reconcile each month without asking support for a report.

Today support runs this report by hand, about 40 requests a month.

## Scope
**In:**
- Export the rows matching the current filters, up to 50,000 rows
- CSV, UTF-8, same columns as the list

**Out:**
- Excel format (later story)
- Scheduled exports (not planned)

## Acceptance criteria

| # | Given | When | Then |
| --- | --- | --- | --- |
| 1 | 120 transactions match the filter | I click Export | A CSV with 120 rows and the list's columns downloads |
| 2 | I sorted by amount | I click Export | The file keeps the same order |
| 3 | I am a Viewer | I open the list | The Export button is not shown |

## Fields

| Field | Required | Rules | Default / example |
| --- | --- | --- | --- |
| Filters | No | Same filters as the transaction list | none = all rows |
| Sort | No | Any column the list can sort by | Date, newest first |
| File (returned) | — | CSV, UTF-8, header row, list columns in list order | `transactions-2026-09-24.csv` |

## Edge & error cases

| # | Case | Expected |
| --- | --- | --- |
| 1 | No rows match | Export button is disabled with "Nothing to export" |
| 2 | More than 50,000 rows | Message: "Narrow your filter to 50,000 rows or fewer" |
| 3 | Export takes longer than 30 s | Error toast, the user can retry |

## Notes per team
- **BE:** Same filters and permissions as the list. Only Admin and Finance roles can export.
- **QA:** Test with 0, 1, 50,000 and 50,001 rows; check Vietnamese characters in names.
```

## What an epic looks like

```markdown
# [Transactions] Self-serve reporting

**Teams:** FE, BE, Data, QA · **Design:** <figma link>

## Why
Finance asks support for transaction reports about 40 times a month and waits up
to 2 days. After this epic, finance pulls the data themselves in under a minute.

## Done when
- A finance user exports any filtered transaction list to CSV without support
- Monthly report requests to support drop to near zero
- Every export is recorded in the audit log

## Scope
**In:**
- CSV export of the transaction list
- Audit log of exports

**Out:**
- Excel export (next quarter)
- Other screens (separate epics)

## Stories

| # | Story | Teams | Depends on |
| --- | --- | --- | --- |
| 1 | [Transactions] [BE] Export the filtered list to CSV | BE, QA | none |
| 2 | [Transactions] [FE] Export button on the transaction list | FE, QA | 1 |
| 3 | [Transactions] [Data] Record every export in the audit log | Data, QA | 1 |
```

## How it differs from `harness-story-author`

| | harness-story-author | harness-ba-ticket |
|---|---|---|
| Template | Long, table-heavy (AC table, positive + negative scenarios, contract table, notes & risks) | One screen: Why / Scope / AC / Fields / Edge cases / Notes per team |
| Audience | Engineer planning the build | Every team that touches the story, including QA, Data, AI |
| Title | `[Area] ... -(BE)` suffix | `[Area] [Team] ...`, or `[Area] ...` when BE + FE ship one feature together |
| Quality check | 12-gate rubric with a state record | 9-point ready check (incl. no code outside BE / FE notes) |
| Epic sizing | Story points per child | Stories table with teams and dependencies; teams size it |

Use `harness-story-author` when you want the full rubric and detailed contract
tables; use this one when the ticket must be quick to read.

## Your own template

Copy `templates/ba-ticket/story.md` (or `epic.md`), change the sections, and pass
`--template <path>`. Every `## Heading` in your copy becomes a section to fill.
