# QA comment (Steps 3a / 3b) — approval before every post

Both the "not a bug" explanation and the "need info" question go to **QA** (the
bug reporter). Posting is **external transmission** — draft it, get the
operator's approval, and only then send. Never auto-post.

Target = `bug-report.reporter_account_id` (the reporter). Mention them and post
on the bug ticket.

## Step 3a — Not a bug

1. Draft a comment that explains, with evidence, why it is not a bug — cite the
   `triage.code_refs[]` so QA can verify:
   ```
   <!-- harness-bugfix:not-a-bug session=<session-id> req=<BUG-123> -->
   @<reporter> — triaged against the current code; this is not a defect:
   - <reason, referencing file:line>
   - Expected behavior is actually specified / already fixed / config-specific.
   Please reopen with more detail if you disagree.
   ```
2. Show it to the operator (`AskUserQuestion`: Post / Edit / Skip). Only on
   **Post** call `addCommentToJiraIssue`.
3. Optional `--close-jira` (approved): `getTransitionsForJiraIssue` →
   `transitionJiraIssue` to a "Not a Bug" / "Rejected" / "Closed" state.
4. `flow-session.sh status <session.json> not-a-bug`, then return to the batch
   (next bug). This bug is done — it does not go to worktree/fix.

## Step 3b — Needs info

1. Draft a question comment with the `open_questions` and the same marker style
   (`harness-bugfix:clarify`), targeting the reporter.
2. Approval (Post / Edit / Skip). On **Post**, `addCommentToJiraIssue` and store
   `clarification {nonce, posted_comment_id, posted_at, bot_account_id, rounds}`;
   `flow-session.sh status <session.json> awaiting-ba`.
3. Auto-poll via `ScheduleWakeup` (same as harness-flow's BA loop). On resume,
   re-fetch comments and match the reply:
   ```
   bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-ba-match.sh" \
     --comments "$TMP/comments.json" --posted-at "<posted_at>" \
     --bot-account-id "<bot>" --posted-comment-id "<posted_comment_id>"
   ```
4. `matched:true` → fold the reply into `bug.json` and re-run Step 2 (triage).
   Round cap 3 → `escalated` + `decision_needed.v1`.

If MCP is `unreachable` at any post, emit `decision_needed.v1` ("relay to QA
manually or reconnect") and pause — do not spin.
