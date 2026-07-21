# BA comment loop (Steps 4-5)

Ask the BA on the ticket, then resume when they reply. Posting is an **external
transmission** — under `.claude/rules/autonomous-confirmation-scope.md` case 1 it
requires operator approval first. This skill never auto-posts.

## Marker format

Every comment carries a hidden, greppable marker plus the human message. The
`nonce` (a uuid) is the join key used by the reply matcher.

```
<!-- harness-story-verify:clarify batch=<batch-id> key=<PROJ-123> nonce=<uuid> -->
Before this story goes into a sprint, a few things need to be pinned down —
otherwise the implementer has to guess and the AC can't be tested as written.

1. <question 1>
   ↳ why: <what cannot be built or tested until this is answered>
2. <question 2>
   ↳ why: <...>

Reply to this comment with the answers and I'll re-check the ticket.
(the marker line above is auto-tracked; please don't delete it)
```

Generate the nonce with `python3 -c 'import uuid;print(uuid.uuid4())'`.

Tone rules: the comment is a request for information, never a critique of the
BA's work. No scores, no gate ids, no "this ticket failed 4 checks" — the
operator sees the rubric, the BA sees the questions.

## Approval BEFORE posting (required)

Batch the approval: draft every unclear ticket's comment first, then ask **once**.

1. Show the full draft set (ticket key + title + question count + full body of
   each) and ask via `AskUserQuestion`:

```json
{
  "decision_needed": {
    "required": true,
    "ask_tool": "AskUserQuestion",
    "question": "Post clarification comments to 4 tickets in PROJ-100?",
    "options": [
      "Post all 4",
      "Let me pick which tickets",
      "Edit the questions first",
      "Skip — I'll ask the BA myself"
    ],
    "context": { "batch": "proj-100", "targets": ["PROJ-101","PROJ-103","PROJ-105","PROJ-107"] }
  }
}
```

2. Act on the answer:
   - **Post all** → post each approved comment.
   - **Pick** → a second `AskUserQuestion` (multiSelect) listing the tickets; post
     only the selected ones. Unselected stay `needs-clarification`.
   - **Edit** → revise and re-present the changed drafts. Do not post in between.
   - **Skip** → leave every ticket `needs-clarification`; the report keeps the
     drafts so the operator can paste them.
3. If `AskUserQuestion` is unavailable, emit `decision_needed.v1` and halt. Never
   fall through to posting.

`--report-only` and `--dry-run` skip this step entirely: no approval prompt, no
writes.

## Posting (only after approval)

`mcp__claude_ai_Atlassian_Rovo__addCommentToJiraIssue` — issue key + the marked
body. One comment per ticket; never a single comment listing several tickets'
questions.

Record the result and advance the state:

```bash
printf '%s' '{"nonce":"<uuid>","posted_comment_id":"<id>","posted_at":"<utc>","bot_account_id":"<acct>","rounds":1}' \
  > "$TMP/clarif.json"

bash "${HARNESS_PLUGIN_ROOT}/scripts/story-verify-record.sh" \
  --in ".claude/state/story-verify/<batch-id>/PROJ-123.json" \
  --out ".claude/state/story-verify/<batch-id>/PROJ-123.json" \
  --set-clarification "$TMP/clarif.json"

bash "${HARNESS_PLUGIN_ROOT}/scripts/story-verify-batch.sh" \
  set-state ".claude/state/story-verify/<batch-id>/batch.json" PROJ-123 awaiting-ba
```

`bot_account_id` comes from a single `atlassianUserInfo` call per run — the
matcher needs it to ignore the skill's own comments. `posted_at` is the created
timestamp the API returns; fall back to the current UTC if it omits one.

If MCP turns `unreachable` mid-post, stop immediately: emit `decision_needed.v1`
naming which tickets were posted and which were not, so a retry does not
double-post.

## Auto-poll (ScheduleWakeup)

Schedule a re-check rather than blocking. One wake re-checks **every**
`awaiting-ba` ticket in the batch, not one per ticket.

```
ScheduleWakeup(
  delaySeconds=1800,
  prompt="/harness-story-verify --resume",
  reason="awaiting BA replies on 4 tickets in PROJ-100 (round 1/3)"
)
```

BAs answer on human timescales — use 1800-3600s, not 60s. Reading comments needs
no approval; only writing does.

## Resume (`--resume` or a wake)

For each ticket in state `awaiting-ba`:

1. Re-fetch its comments (`getJiraIssue` with comments expanded).
2. Normalize to `[{id, author_account_id, created, parent_id, body}, ...]` and
   match:

```bash
printf '%s' "<normalized json>" > "$TMP/comments.json"
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-ba-match.sh" \
  --comments "$TMP/comments.json" \
  --posted-at "<clarification.posted_at>" \
  --bot-account-id "<clarification.bot_account_id>" \
  --posted-comment-id "<clarification.posted_comment_id>"
```

3. `matched:false` → still waiting. Leave the state, continue to the next ticket.
4. `matched:true` → record `reply_comment_id` + `answered_at`, fold the reply
   text into the ticket's material (treat any criteria the BA states as
   acceptance criteria), and **re-run the rubric for that ticket only**.
   - re-verify `clear` → state `answered`.
   - still failing → draft a follow-up asking **only what is still missing**
     (never re-ask an answered question), increment `clarification.rounds`, and
     go back through the approval gate.
5. After the sweep, re-schedule one wake if any ticket is still `awaiting-ba` and
   under the round cap; otherwise report the batch summary.

## Round cap + escalation

Cap at **3 rounds** per ticket. On the 4th need, set the ticket `escalated` and
emit `decision_needed.v1`: name what is still unanswered and ask whether to
proceed on a stated assumption, keep waiting, or drop the ticket from the Epic.
Never invent the missing criterion to force progress.

## Idempotency

The matcher ignores comments authored by `bot_account_id` and anything at or
before `posted_at`, and `reply_comment_id` is recorded once matched — so a
repeated wake or a manual `--resume` never re-matches the same reply, and a
ticket already `awaiting-ba` is never re-posted to.
