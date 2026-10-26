# Impact report (step 5)

Fill this template and save it to
`.claude/state/ba-change/<slug>/report.md`. Show it to the operator before the
approval in step 6. Leave out a section only when it has no rows, and say so in
one line (e.g. "No spec page in scope.").

```markdown
# Change impact: <change title>

**Change from:** <source: email of 2026-10-20 / DPD-950 comment / meeting notes>
**Scope searched:** <Epic DPD-832 (14 tickets) + spec "Checkout rules">
**Confirmed by:** <BA name>, <date>

## The change

| # | What | Before | After |
| --- | --- | --- | --- |
| C1 | ... | ... | ... |

## Summary

- <n> tickets impacted (<a> not started, <b> in progress, <c> done)
- <n> "maybe" resolved, <n> still open
- <n> tickets not impacted
- <n> follow-up tickets to create
- <n> spec sections, <n> test cases, <n> UAT items to update

## Impact

| Ticket | Status | What changes | Action |
| --- | --- | --- | --- |
| DPD-903 Apply discount codes | To Do | AC 2 cap 50% → 30%; Discount code becomes required for Partner | Edit ticket + notice |
| DPD-904 Discount UI | In Progress | AC 1 "up to 50% off" label | Comment, tell @Lan Pham |
| DPD-901 Discount cap | Done | Shipped the 50% cap | New follow-up ticket |

## New tickets

| # | Title | Follows | Teams |
| --- | --- | --- | --- |
| 1 | [Checkout] [BE] Cap discounts at 30% (change to DPD-901) | DPD-901 | BE, QA |

## Spec sections

| Section | Before | After |
| --- | --- | --- |
| Checkout rules › Discounts | "...may not exceed 50%..." | "...may not exceed 30%..." |

## Test cases to update

| Case | Ticket | What changes |
| --- | --- | --- |
| TC-DPD-903-2 Discount over cap | DPD-903 | Expected cap 30% |

Run `/ba-uat --refresh` on the scope to regenerate these.
<UAT items already passed on an impacted rule: list, "re-run needed".>

## Risks

- **Scope grew:** DPD-903 (new required-field rule) — re-size with the team.
- **Built on the old rule:** DPD-904 is in progress; part of the work may be redone.
- **Still open:** DPD-905 AC 3 — does the cap apply to loyalty discounts? Owner: PO.

## Not impacted

DPD-906, DPD-907, ... (<n>)
```

Rules:

- Every "What changes" cell is backed by a quote in `impact.json`; the report
  shows the short form, the drafts show the quote.
- Use the assignee's display name in the report, the account-id mention only in
  the comment.
- No `TBD`, `???`, `etc.`. An open point is a named question with an owner.
- After step 6, append an `## Applied` section: one line per write with key,
  action and URL, and one line per skipped item with the reason.
