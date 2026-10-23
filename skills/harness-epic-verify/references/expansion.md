# Fetch + child inventory (Step 1)

Resolve the ref, confirm it really is an Epic, and inventory its children. The
inventory is **evidence for two gates**, not a work list — child stories are
scored by `harness-story-verify`, never here.

## Resolving the ref

| Input | Detection |
|-------|-----------|
| `PROJ-100` | `getJiraIssue` |
| `https://<site>/browse/PROJ-100` | Regex `/browse/([A-Z][A-Z0-9_]+-\d+)` then `getJiraIssue` |

**Always fetch before deciding.** Never infer "this is an Epic" from the key
shape or the word "epic" in the title.

If `issuetype.name` is not the project's epic-level type, stop and route:

> PROJ-123 is a Story, not an Epic. Run `/harness-story-verify PROJ-123` — that
> skill scores it against the user-story rubric.

Do not score a Story with the epic rubric to be helpful; the gates would fail for
the wrong reasons.

Fetch in one pass so Step 2 does not re-fetch: `summary, description, issuetype,
status, reporter, assignee, labels, created, updated, comment`, plus any
epic-level custom fields the project defines (find them once via
`getJiraIssueTypeMetaWithFields`).

The **reporter** matters beyond scoring: it is who gets mentioned, and who the
Epic is assigned to by the handoff. Capture `reporter_account_id` and
`reporter_display_name`, or record that there is no reporter.

## Children

Modern JIRA links children by `parent`; older company-managed projects use the
`Epic Link` custom field. Try in order and stop at the first query returning
rows, via `searchJiraIssuesUsingJql`:

```
1. parent = PROJ-100 ORDER BY created ASC
2. "Epic Link" = PROJ-100 ORDER BY created ASC
```

If both return zero rows, **do not broaden the query** (no `text ~`, no
project-wide sweep). Zero children is a finding, not an error — it is exactly
what `epic-team-split` and `epic-children-coverage` judge.

For each child keep only what the two gates need: `key, summary, issuetype,
status, assignee, labels`. Do not fetch child descriptions — that is
`harness-story-verify`'s job and it will re-fetch them anyway.

## Using the inventory

| Gate | What the inventory contributes |
|------|-------------------------------|
| `epic-team-split` | Whether children divide by owning role (BE/FE/data/infra) — read labels, components, assignees, and title prefixes. A body that states the split passes the gate even with zero children created yet |
| `epic-children-coverage` | Whether every outcome named in the Definition of Done maps to at least one child (created or named in the body). An unowned outcome fails the gate and feeds a question |

Sub-tasks of a child are not part of the inventory; they belong to the child.

## Reporting the inventory

Before any scoring, tell the operator what is in scope — the last cheap moment to
correct the target:

```
Epic PROJ-100 "Q3 payments" — reporter Jamie Tran, status To Do
  children: 7 (5 Story, 1 Task, 1 Bug) — 4 To Do, 2 In Progress, 1 Done
  by role:  BE 3, FE 2, unlabelled 2
```

An `unlabelled` count above zero is a hint for `epic-team-split`, not a verdict —
score the gate on the Epic's own text plus this evidence.

## Chaining to the children (`--with-children`)

Only after the Epic run finishes, and only when the Epic came back `clear`:

```
/harness-story-verify PROJ-101 PROJ-102 PROJ-103 …
```

Chaining while the Epic is still `needs-clarification` generates story questions
that the Epic's own answers may invalidate — say so and let the operator decide
whether to run it anyway.
