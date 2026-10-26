# ba-change

A requirement changed after the tickets were written. **ba-change** tells you
every ticket, spec section and test that the change touches, drafts the exact
update for each one, and applies them only when you say so.

## Quick start

```bash
# A change against an Epic
/ba-change "Max discount per order is now 30%, was 50%" --scope DPD-832

# The change is an email; check three tickets and the spec page
/ba-change email.txt --scope DPD-901,DPD-903,DPD-904 --spec https://<site>/wiki/spaces/DPD/pages/123456

# The change is a JIRA comment; search a JQL set
/ba-change "https://<site>/browse/DPD-950?focusedCommentId=10400" --jql "project = DPD AND labels = checkout"

# Report and drafts only, never touch JIRA or Confluence
/ba-change "..." --scope DPD-832 --draft-only
```

What happens:

1. It restates the change as **before → after** lines and asks you to confirm.
2. It reads every ticket in scope and marks each one impacted / maybe / not
   impacted, quoting the text that is affected. Each "maybe" is asked, never
   guessed.
3. It sorts impacted tickets by status: **not started** get edited, **in
   progress** get a comment to the assignee, **done** get a new follow-up
   ticket (a done ticket is never reopened).
4. It writes an impact report and asks once: apply all / pick / edit / cancel.
5. It applies only what you approved, backs up what it overwrites, and logs
   every write so a re-run never applies twice.

State lives in `.claude/state/ba-change/<slug>/` (`change.md`, `impact.json`,
`drafts/`, `report.md`, `backup/`, `applied.json`).

## Example

Input:

```bash
/ba-change "From the 20 Oct call: partner orders must always use a discount code, and the max discount drops to 30%." --scope DPD-832
```

Step 1, the restatement you confirm:

| # | What | Before | After |
| --- | --- | --- | --- |
| C1 | Max discount per order | 50% of the order total | 30% of the order total |
| C2 | Discount code on partner orders | Optional | Required |

Step 2, one "maybe" question:

> **DPD-905 AC 3 says "loyalty points work like a discount". Does the 30% cap apply to loyalty points?**
> Yes, it is impacted / No, loyalty is separate / Ask the PO

You pick "No, loyalty is separate" — DPD-905 is not impacted.

Step 5, the report (shortened):

```markdown
# Change impact: Discount cap 30% and required partner codes

**Change from:** call notes, 2026-10-20 · **Scope searched:** Epic DPD-832 (14 tickets)

## Summary
- 3 tickets impacted (1 not started, 1 in progress, 1 done)
- 1 "maybe" resolved, 0 open · 10 tickets not impacted
- 1 follow-up ticket to create · 2 test cases to update

## Impact

| Ticket | Status | What changes | Action |
| --- | --- | --- | --- |
| DPD-903 Apply discount codes | To Do | AC 2 cap 50% → 30%; Discount code required for Partner | Edit ticket + notice |
| DPD-904 Discount badge on checkout | In Progress | AC 1 label "up to 50% off" | Comment, tell Lan Pham |
| DPD-901 Discount cap | Done | Shipped the 50% cap | New follow-up ticket |

## New tickets

| # | Title | Follows | Teams |
| --- | --- | --- | --- |
| 1 | [Checkout] [BE] Cap discounts at 30% (change to DPD-901) | DPD-901 | BE, QA |

## Test cases to update

| Case | Ticket | What changes |
| --- | --- | --- |
| TC-DPD-903-2 Discount over cap | DPD-903 | Expected cap 30% |
| TC-DPD-903-5 Partner checkout | DPD-903 | Order without a code is refused |

Run `/ba-uat --refresh` on DPD-832 to regenerate these.

## Risks
- **Scope grew:** DPD-903 (new required-field rule) — re-size with the team.
- **Built on the old rule:** DPD-904 is in progress; the badge text may need a redo.
```

The notice posted on DPD-904 after approval:

```
<!-- ba-change:notice change=discount-cap-30 key=DPD-904 nonce=6f1c... -->
[~accountid:5b10...] heads-up: the requirement for this ticket changed on
2026-10-20. cc [~accountid:5a77...]

What changed:
- AC 1: "Badge shows up to 50% off" → "Badge shows up to 30% off"

What this means for you: the badge text and its max value change.
Reply here if this breaks something already built.
```

## What it never does

- Edit a ticket marked "maybe" — that is always a question to you.
- Reopen or edit a done ticket — the change goes into a new follow-up.
- Overwrite a ticket someone edited after it was read — it re-reads and re-drafts.
- Write anything to JIRA or Confluence without your approval.
