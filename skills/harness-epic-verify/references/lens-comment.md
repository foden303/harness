# Lens comments + reporter handoff (Steps 5-6)

Ask the BA on the Epic — **one comment per lens** — then hand the Epic back to
them and resume when they reply. Posting a comment, changing the assignee, and
moving the status are all **external transmission**: under
`.claude/rules/autonomous-confirmation-scope.md` case 1 they require operator
approval first. This skill never auto-posts and never auto-transitions.

## Why one comment per lens

A BE question and an FE question have different answerers and different reply
timelines. Splitting them means the BA can answer the frontend thread while the
backend one is still with an architect, each thread carries its own nonce and
round counter, and re-verification runs per lens instead of blocking on the
slowest answer.

## Comment template

Three fixed parts: the tracking marker, the reporter tag, the questions.

```
<!-- harness-epic-verify:clarify epic=<PROJ-100> lens=<be|fe|ba> nonce=<uuid> -->
[~accountid:<reporter_account_id>] — <LENS LABEL> questions on this Epic.

Before this Epic is broken into stories, these need pinning down — otherwise the
<lens noun> side has to guess, and each team will guess differently.

1. <question 1>
   ↳ why: <what cannot be built, sized, or tested until this is answered>
2. <question 2>
   ↳ why: <...>

Reply to this comment with the answers and I'll re-check the Epic.
(the marker line above is auto-tracked; please don't delete it)
```

| lens | LENS LABEL | lens noun |
|------|-----------|-----------|
| `be` | **Backend** | backend |
| `fe` | **Frontend** | frontend |
| `ba` | **Business / scope** | delivery |

**Reporter tag.** `[~accountid:<id>]` is the JIRA Cloud mention form and is what
notifies the BA — this is the point of the tag. Take the id from
`reporter_account_id` on the record. If the Epic has no reporter, fall back to
the plain display name (`Jamie Tran —`), never to a guessed account id, and note
the fallback in the report.

Generate the nonce with `python3 -c 'import uuid;print(uuid.uuid4())'` — one per
lens, never reused across lenses or rounds.

**Tone rules**: the comment is a request for information, never a critique. No
scores, no gate ids, no "this Epic failed 4 checks" — the operator sees the
rubric, the BA sees the questions.

## Approval BEFORE posting (required)

Draft every lens first, then ask **once**, per lens.

1. Show every draft in full (lens + question count + full body) and ask via
   `AskUserQuestion` with `multiSelect: true`:

```json
{
  "decision_needed": {
    "required": true,
    "ask_tool": "AskUserQuestion",
    "question": "Post clarification comments on PROJ-100? Pick the lenses to send.",
    "multi_select": true,
    "options": [
      "Backend (4 questions)",
      "Frontend (2 questions)",
      "Business / scope (3 questions)",
      "Edit the questions first",
      "Skip — I'll ask the BA myself"
    ],
    "context": { "epic": "PROJ-100", "lenses": ["be", "fe", "ba"] }
  }
}
```

2. Act on the answer:
   - **Selected lenses** → post those comments; unselected lenses are recorded
     `state: "skipped"` with their draft kept in the report.
   - **Edit** → revise and re-present the changed drafts. Do not post in between.
   - **Skip** → every lens stays `drafted`; the report keeps the bodies so the
     operator can paste them, and **no handoff runs**.
3. If `AskUserQuestion` is unavailable, emit `decision_needed.v1` and halt. Never
   fall through to posting.

Ask about the handoff in the **same** prompt when it is not obvious — the
assignee/status change is part of "post this", not a second decision. State
plainly what it will do: *"Posting also assigns PROJ-100 to Jamie Tran and moves
it to Waiting for BA."*

`--report-only` and `--dry-run` skip this step entirely: no approval prompt, no
writes, no handoff.

## Posting a lens (only after approval)

`mcp__claude_ai_Atlassian_Rovo__addCommentToJiraIssue` — Epic key + the marked
body. One call per approved lens.

```bash
printf '%s' '{"state":"awaiting-ba","nonce":"<uuid>","posted_comment_id":"<id>","posted_at":"<utc>","bot_account_id":"<acct>","rounds":1}' \
  > "$TMP/clarif-be.json"

bash "${HARNESS_PLUGIN_ROOT}/scripts/epic-verify-record.sh" \
  --in ".claude/state/epic-verify/proj-100/epic.json" \
  --out ".claude/state/epic-verify/proj-100/epic.json" \
  --lens be --set-clarification "$TMP/clarif-be.json"
```

`bot_account_id` comes from a single `atlassianUserInfo` call per run — the
matcher needs it to ignore the skill's own comments. `posted_at` is the created
timestamp the API returns; fall back to the current UTC if it omits one.

If MCP turns `unreachable` mid-post, stop immediately and emit
`decision_needed.v1` naming which lenses were posted and which were not, so a
retry does not double-post.

## Reporter handoff (once per Epic)

After the **first** lens comment posts successfully, hand the Epic back to the
person who has to answer. Skipped entirely when `--no-handoff`, when every lens
was skipped, or in `--report-only` / `--dry-run`.

### 1. Assignee → reporter

`mcp__claude_ai_Atlassian_Rovo__editJiraIssue` with
`fields: {"assignee": {"accountId": "<reporter_account_id>"}}`.

Skip conditions, each recorded and reported, never fatal:

| Condition | `assign_skipped_reason` |
|-----------|-------------------------|
| Epic has no reporter | `no-reporter` |
| Reporter is already the assignee | `already-assigned` |
| The field rejects the write (permission/screen) | `assign-not-permitted` |

### 2. Status → a clarification state

Never assume a workflow name. Read what the Epic actually offers and match:

```bash
# getTransitionsForJiraIssue -> $TMP/transitions.json
bash "${HARNESS_PLUGIN_ROOT}/scripts/jira-status-match.sh" \
  --transitions "$TMP/transitions.json" \
  --current-status "To Do" \
  ${ASK_STATUS:+--prefer "$ASK_STATUS"}
```

- `matched: true` → `transitionJiraIssue` with `transition_id`, then record
  `status_from`, `status_to`, `transition_id`, `transitioned_at`.
- `matched: false` → **post stays, transition is skipped**. Record
  `transition_skipped_reason` (`no-matching-transition`,
  `preferred-status-not-available`, `already-in-target-status`) and say so in
  the summary, naming the statuses that were available.

Default candidate order: `Clarification`, `Waiting for BA`, `Needs Info`,
`In Review`. `--ask-status "<name>"` overrides it; when the named status is not
available the transition is skipped rather than redirected to a different one —
an explicit operator choice is never silently substituted.

### 3. Record it

```bash
printf '%s' '{"assignee_set_to":"<acct>","assigned_at":"<utc>","status_from":"To Do","status_to":"Waiting for BA","transition_id":"31","transitioned_at":"<utc>"}' \
  > "$TMP/handoff.json"

bash "${HARNESS_PLUGIN_ROOT}/scripts/epic-verify-record.sh" \
  --in ".claude/state/epic-verify/proj-100/epic.json" \
  --out ".claude/state/epic-verify/proj-100/epic.json" \
  --set-handoff "$TMP/handoff.json"
```

Report the handoff in one line: *"PROJ-100 → assigned to Jamie Tran, status To Do
→ Waiting for BA."* Or, when skipped: *"PROJ-100 → assigned to Jamie Tran; status
left at To Do (no clarification transition available: In Progress, Done)."*

## Auto-poll (ScheduleWakeup)

Schedule a re-check rather than blocking. One wake re-checks **every**
`awaiting-ba` lens, not one per lens.

```
ScheduleWakeup(
  delaySeconds=1800,
  prompt="/harness-epic-verify --resume",
  reason="awaiting BA replies on PROJ-100 (be, ba lenses — round 1/3)"
)
```

BAs answer on human timescales — use 1800-3600s, not 60s. Reading comments needs
no approval; only writing does.

## Resume (`--resume` or a wake)

For each lens in state `awaiting-ba`:

1. Re-fetch the Epic's comments (`getJiraIssue` with comments expanded).
2. Normalize to `[{id, author_account_id, created, parent_id, body}, ...]` and
   match that lens's thread:

```bash
printf '%s' "<normalized json>" > "$TMP/comments.json"
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-ba-match.sh" \
  --comments "$TMP/comments.json" \
  --posted-at "<clarifications[lens].posted_at>" \
  --bot-account-id "<clarifications[lens].bot_account_id>" \
  --posted-comment-id "<clarifications[lens].posted_comment_id>"
```

3. `matched:false` → still waiting. Leave that lens, continue to the next.
4. `matched:true` → record `reply_comment_id` + `answered_at`, fold the reply
   into the Epic's material, and **re-score only the gates that lens's questions
   cited**.
   - every question in the lens resolved → lens `answered`.
   - still failing → draft a follow-up asking **only what is still missing**
     (never re-ask an answered question), increment that lens's `rounds`, and go
     back through the approval gate. A follow-up does **not** repeat the handoff;
     the Epic is already assigned and already in the clarification status.
5. When every lens is `answered` / `skipped`, re-run the full rubric once. Clear
   → report it and, if `--with-children`, hand the child keys to
   `harness-story-verify`.

## Round cap + escalation

Cap at **3 rounds per lens**. On the 4th need, set that lens `escalated` and emit
`decision_needed.v1`: name what is still unanswered and ask whether to proceed on
a stated assumption, keep waiting, or drop that lens's concern. Never invent the
missing answer to force progress.

## Idempotency

The matcher ignores comments authored by `bot_account_id` and anything at or
before that lens's `posted_at`; `reply_comment_id` is recorded once matched. The
record helper upserts `clarifications[]` **by lens**, so a repeated wake or a
manual `--resume` never creates a second thread for the same lens and never
re-posts to a lens already `awaiting-ba`. The handoff is written once and is not
repeated on later rounds.
