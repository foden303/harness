# Approve and apply (step 6)

Every write here notifies people or changes a shared record, so it is external
transmission (`.claude/rules/autonomous-confirmation-scope.md` case 1). Nothing
is written without the approval below. `--draft-only` and `--dry-run` never
reach this step.

## The one approval

Show the impact report and the full text of every draft, then ask once with
`AskUserQuestion`:

- **Apply all** (<n> edits, <n> comments, <n> new tickets, spec update)
- **Let me pick** — a multi-select of the individual writes, grouped by ticket
- **Edit first** — revise the named drafts, re-show, ask again; write nothing in between
- **Cancel** — nothing is written; the drafts stay in state

State in the question what "apply" covers, e.g. *"Applying edits DPD-903,
comments on DPD-903/904/901 mentioning their assignees, creates 1 follow-up
under DPD-832, and updates the spec page."*

An in-progress ticket's body edit is offered as a separate, unticked item in
**Let me pick**; **Apply all** does not edit in-progress ticket bodies (only the
comment). `maybe` items are never in the list.

If `AskUserQuestion` is unavailable, print the question and stop.

## Before each write

1. **Skip if logged.** If `applied.json` already has an entry for this
   `{key, action}`, skip it and say "already applied".
2. **Back up.** Save the current description (or page body) to
   `backup/<KEY>.md` / `backup/spec-<pageId>.md` before the first write to it.
3. **Re-read.** `getJiraIssue` (or `getConfluencePage`) and compare `updated`
   (page `version.number`) with `snapshots/`. Changed → do not write; re-read,
   re-draft that item, show the new diff, ask for that item again.
4. **Comment check.** For a notice, search the ticket's comments for
   `ba-change:notice change=<slug> key=<KEY>`; present → log it as applied with
   the found comment id and skip.

## Write order

1. Follow-up tickets — `createJiraIssue` (parent = Epic, `contentFormat:
   "markdown"`), then `createIssueLink` to the done ticket. Log the new key at
   once.
2. Ticket edits — `editJiraIssue` with `fields: {description: ...}` (and the AC
   field if the project keeps AC in a custom field), `contentFormat:
   "markdown"`. Summary, status, assignee, labels and links stay unchanged.
3. Notice comments — `addCommentToJiraIssue`; done tickets' notices now include
   the follow-up key.
4. Spec — `updateConfluencePage` with the new body and `version.number + 1`.

Apply the JIRA markdown pitfalls from
`skills/ba-ticket/references/create-jira.md` and check the returned text after
each write.

## applied.json

`.claude/state/ba-change/<slug>/applied.json`, appended after every successful
write (never batched to the end):

```json
{
  "change": "max-discount-30",
  "writes": [
    {"action": "create", "draft": "follow-up-1.md", "key": "DPD-960", "at": "2026-10-26T09:12:03Z"},
    {"action": "link", "from": "DPD-960", "to": "DPD-901", "type": "Relates", "at": "..."},
    {"action": "edit", "key": "DPD-903", "backup": "backup/DPD-903.md", "at": "..."},
    {"action": "comment", "key": "DPD-904", "comment_id": "10421", "nonce": "<uuid>", "at": "..."},
    {"action": "spec", "page_id": "123456", "version": 18, "backup": "backup/spec-123456.md", "at": "..."}
  ]
}
```

A re-run reads it first: logged writes are skipped, the rest are offered again.

## Failures

Stop at the first failed write. Report what `applied.json` holds and what is
still pending, so a re-run continues from there. MCP turning unreachable
mid-apply is the same: stop, report, never retry blindly.

## After

Append `## Applied` to `report.md`. The skill does not transition, assign or
estimate anything. End with: "Applied. Assignees have been notified; run
`/ba-uat --refresh` for the test cases listed."

## Restoring

To undo an edit, the operator can ask to restore from `backup/<KEY>.md`; that
restore is itself a write and goes through the same approval.
