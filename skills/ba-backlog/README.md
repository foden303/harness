# ba-backlog

A **backlog hygiene scan** to run before refinement or sprint planning. It finds
the tickets that are not ready (no AC, title-only, stale, stuck, orphaned,
unestimated, unassigned, too big, possible duplicates, broken blockers, missing
labels), ranks what to fix first, and tells you which skill to run on each.

It reads only. Comments, labels and duplicate links happen only after you
approve them, and it never closes, deletes, or moves a ticket.

## Quick start

```bash
# The project backlog (open Stories/Tasks/Bugs, first 200 by rank)
/ba-backlog --project DPD

# Planning prep: only the next sprint
/ba-backlog --sprint next --project DPD

# One Epic's open children
/ba-backlog --epic DPD-832

# Your own query, stale after 14 days, with an HTML copy
/ba-backlog --jql "project = DPD AND component = Payments" --stale-days 14 --html

# Look, never offer to write anything
/ba-backlog --project DPD --report-only
```

## What it checks

| Check | Means |
| --- | --- |
| `missing-ac` | No acceptance criteria anywhere |
| `thin-description` | Title-only or a couple of lines |
| `possible-duplicate` | Looks like the same work as another ticket (both quoted) |
| `stale` | Not updated in 30 days (`--stale-days`) |
| `stuck-in-progress` | In Progress too long with no comment or commit |
| `no-epic` | Story with no parent Epic |
| `broken-link` | "Blocked by" a Done ticket, or linked to one that is gone |
| `unestimated` | In the next sprint without points (only if you use points) |
| `no-assignee-in-sprint` | In a sprint with nobody on it |
| `oversized` | Probably needs splitting |
| `label-hygiene` | Missing the label/component almost every other ticket has |

Deep checks are not repeated here: tickets with no AC or that look too big go to
`/ba-story-verify`, thin ones to `/ba-ticket <KEY>`.

## Example report

```markdown
# Backlog hygiene: DPD sprint next

Sprint 42 (DPD) — 38 scanned of 38 matching (cap 200). 27 findings on 19
tickets; 11 tickets have at least one blocker finding.

JQL: `project = DPD AND sprint in futureSprints() AND statusCategory != Done ORDER BY Rank ASC`
Conventions: story points yes (Story point estimate, 86% of resolved);
labels no consistent convention; components yes on Story (88%);
next sprint "Sprint 42" starts 2026-10-29.
Not run: label-hygiene (labels): no consistent convention.

## Counts

| Check | Severity | Tickets |
| --- | --- | --- |
| missing-ac | blocker | 6 |
| thin-description | blocker | 3 |
| stuck-in-progress | blocker | 1 |
| broken-link | blocker | 2 |
| unestimated | blocker | 5 |
| oversized | blocker | 1 |
| possible-duplicate | advisory | 1 pair |
| stale | advisory | 2 |
| no-epic | advisory | 3 |
| no-assignee-in-sprint | advisory | 2 |
| label-hygiene | advisory | 1 |

## Top 10 to fix before refinement

| # | Key | Title | Why it is here | Fix with |
| --- | --- | --- | --- | --- |
| 1 | DPD-917 | Export filtered transactions | missing-ac, unestimated, oversized | /ba-story-verify |
| 2 | DPD-903 | Refund flow | missing-ac, thin-description, unestimated | /ba-ticket DPD-903 |
| 3 | DPD-874 | Settlement report job | stuck-in-progress (19 days), broken-link | ask assignee |
| 4 | DPD-921 | Merchant search | missing-ac, unestimated | /ba-story-verify |
| 5 | DPD-899 | Webhook retries | broken-link (blocked by DPD-850, Done) | remove the blocker |
| 6 | DPD-925 | Fee config screen | missing-ac, no-assignee-in-sprint | /ba-story-verify |
| 7 | DPD-930 | Dispute upload | missing-ac | /ba-story-verify |
| 8 | DPD-911 | Payout CSV | thin-description, unestimated | /ba-ticket DPD-911 |
| 9 | DPD-934 | Audit export | missing-ac | /ba-story-verify |
| 10 | DPD-940 | Currency rounding | thin-description, unestimated | /ba-ticket DPD-940 |

## missing-ac (6)

| Key | Title | Finding | Suggested action | Skill to run |
| --- | --- | --- | --- | --- |
| DPD-917 | Export filtered transactions | AC field empty; description has Scope but no criteria | Ask the reporter to add AC | ba-story-verify |
| DPD-903 | Refund flow | Description is 1 line: "see Figma" | Ask the reporter to add AC | ba-story-verify |
| ... | | | | |

## possible-duplicate (1 pair)

| Ticket A | Ticket B | Why they match | Suggested action |
| --- | --- | --- | --- |
| DPD-917 "Export filtered transactions" | DPD-938 "CSV export for the transaction list" | title overlap 0.71; both name the list filters and CSV | Link as Duplicate; BA confirms and closes one |

## broken-link (2)

| Key | Title | Finding | Suggested action | Skill to run |
| --- | --- | --- | --- | --- |
| DPD-899 | Webhook retries | "is blocked by DPD-850", which is Done since 2026-10-02 | Remove the blocker or confirm it | none |
| DPD-874 | Settlement report job | Linked to DPD-512, which cannot be read (deleted or no access) | Check the link | none |
```

Then one question with the actions that apply:

```
Which actions should I apply? (multi-select)
[ ] Comment on 11 tickets asking the reporter to fix
[ ] Add label needs-refinement to 11 tickets
[ ] Link 1 suspected duplicate pair (DPD-938 duplicates DPD-917) and comment on both
[ ] Hand 6 tickets to ba-story-verify (prints the command)
```

Only the selected actions run. Each write is logged in
`.claude/state/ba-backlog/dpd-sprint-next/applied.json`, so running the scan
again next week never asks the same reporter twice for the same thing.
