# Actions (step 5)

Every action here is an external write
(`.claude/rules/autonomous-confirmation-scope.md` case 1). Nothing runs without
an explicit answer. `--report-only` and `--dry-run` never reach this step.

## The one question

Ask **once** with `AskUserQuestion`, `multiSelect: true`. Only offer options
that have findings behind them, and put the count in each label:

- **Comment on <n> tickets** asking the reporter to fix (one comment per ticket,
  listing that ticket's findings)
- **Add label `needs-refinement`** to <n> tickets with a blocker finding
- **Link <n> suspected duplicate pairs** as `Duplicate` and comment on both
- **Hand <n> tickets to ba-story-verify** (prints the command; writes nothing)

The operator can narrow by typing (e.g. "only missing-ac", "skip DPD-140",
"label: refine-q4"). If `AskUserQuestion` is unavailable, print the question and
stop. No answer means nothing is written.

Before asking, show the exact drafts: one sample comment in full, the list of
keys per action, and every duplicate pair with both quotes.

## Comment template

```
<!-- ba-backlog:hygiene check=<id>[,<id>...] nonce=<uuid> -->
[~accountid:<reporter_account_id>] — this ticket was flagged in a backlog check
before refinement. Could you take a look?

- <plain-language finding 1> — <what to add or change>
- <plain-language finding 2> — <what to add or change>

Reply here or update the ticket; nothing has been changed on it.
```

- Generate the nonce with `python3 -c 'import uuid;print(uuid.uuid4())'`.
- No reporter -> use the display name, never a guessed account id, and note it.
- `stuck-in-progress` and `no-assignee-in-sprint` address the assignee (or the
  reporter when there is none) instead.
- Tone: a request, never a critique. No check ids, severities, or counts in the
  visible text; the ids live only in the marker.

## Duplicate links

Per approved pair:

1. `getIssueLinkTypes` once; use the type named `Duplicate` (outward "duplicates").
   If the site has none, say so and offer comments only.
2. `createIssueLink` type `Duplicate`, newer ticket `duplicates` older ticket.
3. One marked comment on each (`check=possible-duplicate`) quoting the other
   ticket and asking the BA to confirm and close one.

Never transition, close, or resolve either ticket.

## Labels

`editJiraIssue` with the label **added** to the existing list (read the current
labels first; never replace them). Default label `needs-refinement`; the
operator may name another.

## Hand-off to ba-story-verify

Print the command; do not run it unless the operator asks:

```
/ba-story-verify DPD-101 DPD-117 DPD-123 DPD-130
```

Split into batches of at most 20 keys per command. Thin descriptions get
`/ba-ticket <KEY>` lines instead (rewrite on approval there).

## applied.json

Write each successful action immediately after it returns:

```json
{
  "scope": "dpd",
  "applied": [
    {"key": "DPD-117", "action": "comment", "checks": ["missing-ac", "unestimated"],
     "nonce": "6f1c...", "comment_id": "10234", "at": "2026-10-26T09:12:00Z"},
    {"key": "DPD-117", "action": "label", "label": "needs-refinement", "at": "..."},
    {"key": "DPD-188", "action": "link", "type": "Duplicate", "target": "DPD-140", "at": "..."}
  ]
}
```

Re-run rules:

- Skip a comment when `applied.json` already has a comment on that key covering
  the same check ids, **or** the ticket's comments already contain a
  `<!-- ba-backlog:hygiene check=...` marker for those checks (covers a lost
  state folder).
- Skip a label already present on the ticket.
- Skip a link when the two tickets are already linked.
- Report skipped writes in one line each ("DPD-117 comment skipped: already
  asked on 2026-10-19").

## After

Report what was written, per action, with keys. A failure stops the batch; list
what was applied and what remains, so a re-run finishes only the rest.
