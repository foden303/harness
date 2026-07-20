# BA feedback loop (Step 3)

When verification returns `needs-clarification`, ask the BA on the ticket and
resume when they reply. This loop pauses/resumes through `flow-session.v1` — it
is never a foreground busy-wait.

## Marker format

Every clarification comment carries a hidden, greppable marker plus a human
message. The `nonce` (a uuid) is the join key.

```
<!-- harness-flow:clarify session=<session-id> req=<PROJ-123|pageId> nonce=<uuid> -->
@BA — this requirement needs clarification before implementation:
1. <open_question 1>
2. <open_question 2>
Please reply to this comment. (the marker line above is auto-tracked; do not delete)
```

Generate the nonce with `python3 -c 'import uuid;print(uuid.uuid4())'` (scripts
have no randomness ban). Store the posting metadata:

```
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" set-json <session.json> clarification \
  '{"nonce":"<uuid>","posted_comment_id":"<id>","posted_at":"<utc>","bot_account_id":"<acct>","rounds":<n+1>}'
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" status <session.json> awaiting-ba
```

## Operator approval BEFORE posting (required)

Posting a comment to JIRA/Confluence is **external transmission** — under
`.claude/rules/autonomous-confirmation-scope.md` case 1 it MUST be approved by the
operator before it is sent. harness-flow never auto-posts a BA comment.

1. Draft the full comment body (marker + open questions) and show it to the
   operator for review via `AskUserQuestion` (or emit `decision_needed.v1` and
   halt if the tool is unavailable):
   ```json
   {
     "decision_needed": {
       "required": true,
       "ask_tool": "AskUserQuestion",
       "question": "Post this clarification comment to <PROJ-123>?",
       "options": ["Post it", "Edit the questions first", "Skip — I'll ask the BA myself"],
       "context": { "target": "PROJ-123", "comment_preview": "<full marked body>" }
     }
   }
   ```
2. Only on an explicit **"Post it"** do you call the MCP write. If the operator
   chooses **Edit**, revise the questions and re-present. If **Skip**, set status
   `awaiting-ba` and wait for a manual `--resume` (the operator relays the answer).

## Posting (only after approval)

| Source | MCP call |
|--------|----------|
| JIRA | `addCommentToJiraIssue` (issue key + the marked body) |
| Confluence | `createConfluenceFooterComment` (page id + the marked body) |

**Merged multi-ticket feature**: post each clarifying question to the specific
ticket it came from (a question about `PROJ-124`'s criteria goes on `PROJ-124`).
If a question is feature-wide, post it to the primary (first) ticket. The
approval prompt shows which ticket(s) will receive a comment.

Capture the returned comment id into `clarification.posted_comment_id`, and set
`posted_at` to the created timestamp the API returns (fall back to the current
UTC if the API omits it).

If MCP is `unreachable` here, do not spin — emit `decision_needed.v1`
("Atlassian MCP unreachable; relay the clarification manually or reconnect") and
stop.

## Auto-poll (ScheduleWakeup)

Schedule a re-check instead of blocking. Reuse the `harness-loop` pacing idea:

```
ScheduleWakeup(
  delaySeconds=1200,              # 20 min; clamp is [60, 3600]
  prompt="/harness-flow --resume <session-id>",
  reason="awaiting BA reply on <PROJ-123> (round <n>/3)"
)
```

Pick the interval by urgency: a fast back-and-forth can use ~300s; an overnight
wait uses 3600s. Each wake is one re-check, not a loop.

## Resume (on `--resume` or a wake)

1. Re-fetch comments:
   - JIRA: `getJiraIssue` with comments expanded.
   - Confluence: `getConfluencePageFooterComments` (+ `getConfluenceCommentChildren`
     for threaded replies).
2. Normalize them to the matcher's shape and match:
   ```
   # normalized array: [{id, author_account_id, created, parent_id, body}, ...]
   printf '%s' "<normalized json>" > "$TMP/comments.json"
   bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-ba-match.sh" \
     --comments "$TMP/comments.json" \
     --posted-at "<clarification.posted_at>" \
     --bot-account-id "<clarification.bot_account_id>" \
     --posted-comment-id "<clarification.posted_comment_id>"
   ```
3. `matched:false` → still waiting. Re-schedule the next wake (up to the cap) or,
   if this was a manual `--resume`, report "no BA reply yet" and stop.
4. `matched:true` → record `reply_comment_id`, fold the reply text into
   `requirement.json` (append to `description`, add any stated criteria to
   `acceptance_criteria`), then re-run Step 2 (verify).
   - verify `ok` → advance to planning.
   - verify `needs-clarification` again → post a follow-up comment (increment
     `rounds`) if under the cap.

## Round cap + escalation

Cap clarification rounds at **3** (`clarification.rounds`). On the 4th need:

```
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" status <session.json> escalated
```

and emit `decision_needed.v1` (request-unachievable): summarize what is still
missing and ask the operator whether to proceed with an assumption, keep waiting,
or drop the ticket. Do not guess criteria to force progress.

## Idempotency

The matcher ignores comments authored by `bot_account_id` and anything at or
before `posted_at`, and records `reply_comment_id` once matched — so a repeated
wake or a manual `--resume` never re-matches the same reply or the skill's own
comment.
