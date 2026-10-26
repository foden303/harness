# Draft updates (step 4)

Draft every update before asking anything. Each draft is saved under
`.claude/state/ba-change/<slug>/drafts/` so the report and the apply step read
the same text.

## Not-started ticket: the diff

Show only the parts that change, as before/after pairs. The full new description
is saved alongside for the write.

```markdown
### DPD-903 [Checkout] [BE] Apply discount codes — not started

| Where | Before | After |
| --- | --- | --- |
| AC 2 | Then the discount is capped at 50% of the order total | Then the discount is capped at 30% of the order total |
| Fields: Discount code | Optional | Required when the customer type is Partner |
| Edge case 4 | (none) | Partner order without a code → "Partner orders need a discount code" |

Estimate risk: scope grew — new required-field rule. Re-size with the team.
```

Files: `drafts/<KEY>.diff.md` (the table above) and `drafts/<KEY>.description.md`
(the full new description, same markdown the ticket uses). Change only the lines
the impact quoted; keep every other line byte-for-byte.

A `not-started` ticket also gets a short notice comment (below) so watchers see
why it changed.

## In-progress ticket: the notice comment

```
<!-- ba-change:notice change=<slug> key=<KEY> nonce=<uuid> -->
[~accountid:<assignee_account_id>] heads-up: the requirement for this ticket
changed on <date>. cc [~accountid:<reporter_account_id>]

What changed:
- <AC 2>: "<quoted before>" → "<after>"
- <Fields: Discount code>: Optional → Required for Partner orders

What this means for you: <one line: what to build or test differently>.
Reply here if this breaks something already built.
(the marker line above is auto-tracked; please don't delete it)
```

- Nonce: `python3 -c 'import uuid;print(uuid.uuid4())'`.
- Mention form `[~accountid:<id>]`. No assignee → mention the reporter only and
  say so in the report. Never guess an account id.
- The marker is what makes the comment idempotent: before posting, search the
  ticket's comments for `ba-change:notice change=<slug> key=<KEY>`; if present,
  the comment is already posted.
- Tone: a heads-up, not a blame. No "you built it wrong".

The ticket body itself is edited only if the operator picks it in step 6 (the
diff is drafted anyway so they can).

## Done ticket: the follow-up ticket

Never reopen or edit a done ticket. Draft a new story in the `ba-ticket` short
format (title `[Area] [Team] ...`, Why / Scope / Acceptance criteria / Fields /
Edge cases / Notes per team) that delivers only the change:

```markdown
# [Checkout] [BE] Cap discounts at 30% (change to DPD-901)

**Epic:** DPD-832 · **Teams:** BE, QA · **Follows:** DPD-901 (done)

## Why
The discount cap changed from 50% to 30% on 2026-10-20. DPD-901 shipped the
50% cap.

## Scope
**In:**
- Lower the cap to 30% for every order created after release
**Out:**
- Orders already placed keep their discount

## Acceptance criteria
| # | Given | When | Then |
| --- | --- | --- | --- |
| 1 | An order of $200 and a 40% code | I apply the code | The discount is $60 (30%) |
...
```

- Parent: the same Epic as the done ticket. Link: `relates to` (or the
  project's "follows"/"is caused by" type if it exists) to the done ticket.
- Anything the follow-up needs that the change does not say (for example
  whether existing orders are affected) is asked in step 2-3, never filled in.
- One follow-up per done ticket, unless several done tickets need the same
  single change — then one follow-up linked to all, and say so.
- File: `drafts/follow-up-<n>.md`.

The done ticket also gets a notice comment pointing at the follow-up (the key is
filled in after the create).

## Spec diff

For the `--spec` page, a section-by-section diff:

```markdown
### Spec: Checkout rules › Discounts

| Before | After |
| --- | --- |
| "A discount may not exceed 50% of the order total." | "A discount may not exceed 30% of the order total." |
```

Files: `drafts/spec.diff.md` and `drafts/spec.body.md` (the full new body). Keep
every unchanged paragraph as-is, including macros. Add a one-line change note at
the top of the changed section only if the page already uses change notes.

## Tests and UAT

Do not rewrite test cases here. List each impacted case with the line that
changes and recommend `/ba-uat --refresh` in the report. A UAT item already
passed on an impacted rule is listed as "re-run needed".
