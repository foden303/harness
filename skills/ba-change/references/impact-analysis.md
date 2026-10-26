# Impact analysis (steps 1-3)

Everything here is a read. Nothing is written to JIRA or Confluence until
step 6 (see `apply.md`).

## Step 1: Restate the change

### Reading the input

| Input | How to read it |
|-------|----------------|
| Pasted text / email / meeting notes | Use as-is; strip signatures, quoted replies, greetings |
| A file path | `Read` it |
| An issue key | `getJiraIssue` (summary, description, comments); the change is the description unless the BA points at a comment |
| A JIRA comment URL (`...?focusedCommentId=<id>`) | `getJiraIssue` with comments, take that comment only |

### Before → after lines

One line per changed rule, field or flow step. Each line names the thing that
changes, the old value and the new value, in the BA's words.

```
| # | What | Before | After |
| --- | --- | --- | --- |
| C1 | Max discount per order | 50% | 30% |
| C2 | Discount code field | Optional | Required for partner orders |
| C3 | Checkout flow | Discount applied after tax | Discount applied before tax |
```

Rules:

- `Before` comes from the current tickets/spec when the request does not say it.
  If neither says it, ask; do not leave it blank.
- An `After` the request leaves open (for example "lower the limit" with no
  number) is a question at this step, with ready-made options where the request
  hints at them.
- Something the request mentions that is not a change (background, reasons)
  goes into a one-line `Why` above the table, not into the table.
- Save to `.claude/state/ba-change/<slug>/change.md`. `<slug>` is the change in
  kebab-case, e.g. `max-discount-30`.

### Confirm

`AskUserQuestion`: **"Is this the change?"** — Confirmed / Edit a line / Add a
line / Cancel. Loop until confirmed or cancelled. Record
`"confirmed_at"` in `state.json`. Nothing downstream runs on an unconfirmed
restatement.

## Step 2: Find impact

### Read the scope

| Scope | Read |
|-------|------|
| Epic key | `getJiraIssue` on the Epic + `searchJiraIssuesUsingJql` `parent = <KEY>` (all statuses, including done) |
| Key list | `getJiraIssue` per key |
| `--jql` | `searchJiraIssuesUsingJql` with the query, then `getJiraIssue` per hit |
| `--spec` | `getConfluencePage` (body as storage/markdown) |

Per ticket keep: key, type, summary, status + status category, assignee,
reporter, description, AC field, `updated`, story points, linked test issues.
Save the raw read to `snapshots/<KEY>.json` (the `updated` value is checked again
before writing).

Also look for local test material: `.claude/state/ba-uat/<slug>/test-cases.md` (case ids `TC-<KEY>-<n>`) and any test case
issues linked to the tickets in scope.

For 8 or more tickets, fan out with `Task` — one read-only sub-agent per ticket,
given `change.md` and the ticket key, returning the marking below. Fewer than 8:
do it in-context.

### Mark each item

For every ticket, spec section and test case, against every change line:

| Mark | When | Must carry |
|------|------|------------|
| `impacted` | The quoted text states the old rule/value/flow and becomes wrong after the change | Change line id + exact quote + where (AC #2, Fields row "Discount", Rule 3, Step 4, TC-DPD-903-2) |
| `maybe` | The text touches the same area but does not state the old value (e.g. "apply the discount", "standard limits") | Change line id + quote + the question that decides it |
| `not impacted` | No text relates to any change line | Nothing (counted only) |

A ticket is impacted if any line is impacted. Quote verbatim; never paraphrase
the affected text.

### Resolve "maybe"

Each `maybe` becomes a decision-shaped question, up to 4 per `AskUserQuestion`
round:

> **DPD-905 AC 3 says "the standard discount applies". Does the 30% cap apply here?**
> Yes, it is impacted / No, this is a different discount / Ask the PO

Answers move the item to `impacted` or `not impacted`. "Ask the PO" (or the
operator saying "leave it") keeps it `maybe`; it goes into the report as an open
question with an owner and is never edited.

Save `impact.json`: `[{key, mark, change_ids, quotes:[{where, text}], question?, answer?}]`.

## Step 3: Classify

### Tickets by status category

| Status category | Class | Action |
|-----------------|-------|--------|
| To Do (new, backlog, ready, clarification) | `not-started` | Edit the ticket (AC / fields / description) |
| In Progress (in progress, in review, QA, blocked) | `in-progress` | Comment with the change + mention the assignee; edit only if the operator picks it in step 6 |
| Done (done, closed, released, resolved) | `done` | Draft a NEW follow-up ticket linked to it; never reopen, never edit the done ticket |

Use the JIRA status **category**, not the status name, so custom workflows work.
If a ticket has no category, ask which class it is.

### Other impacted items

| Item | Recorded as |
|------|-------------|
| Test cases (linked test issues, ba-uat files, AC-derived cases) | `tests[]` with the case id/title and the line that changes |
| UAT items already run | `uat[]` — a passed UAT item on an impacted rule must be re-run |
| Spec sections | `spec[]` with the heading path and the quoted paragraph |

### Estimate risk

Flag a ticket when the change adds work it was not sized for: a new field, a new
rule, a new state, a new screen, or a flow step added. Do not re-estimate; write
"scope grew: <what>, re-size with the team". Done tickets carry no estimate risk
(the work goes to the follow-up).
