---
name: harness-bugfix
description: "Operator-driven bug-fix flow from a JIRA bug link to a committed (never pushed) fix. Ingests one or more bug links, triages each against the CURRENT source code, comments back to QA when it is not a bug, and for real bugs splits a worktree, fixes, reviews, gets operator confirmation, and commits. Multiple bugs are processed ONE AT A TIME (pausing after each for the operator to push) to avoid merge conflicts. Trigger: fix a bug, bug ticket, triage a bug, BUG-123, is this a real bug. Do NOT load for: new features/requirements (use harness-flow), standalone review, or release."
description-en: "Operator-driven bug-fix flow from a JIRA bug link to a committed (never pushed) fix. Ingests one or more bug links, triages each against the CURRENT source code, comments back to QA when it is not a bug, and for real bugs splits a worktree, fixes, reviews, gets operator confirmation, and commits. Multiple bugs are processed ONE AT A TIME (pausing after each for the operator to push) to avoid merge conflicts. Trigger: fix a bug, bug ticket, triage a bug, BUG-123, is this a real bug. Do NOT load for: new features/requirements (use harness-flow), standalone review, or release."
kind: workflow
purpose: "Orchestrate bug ingest -> triage vs current source -> (QA comment if not a bug) -> worktree fix -> review -> confirm -> commit (no push), one bug at a time"
trigger: "fix a bug, bug ticket, triage a bug, is this a real bug"
shape: delegate
role: orchestrator
base: harness-work
pair: harness-flow
owner: harness-core
since: "2026-07-16"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "ScheduleWakeup", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<BUG-KEY>|<url> ...] [--resume] [--accept-html] [--close-jira] [--dry-run]"
user-invocable: true
effort: high
---

# harness-bugfix

The bug sibling of `harness-flow`. It takes a bug from a JIRA link to a
**committed (never pushed) fix**:

> **bug link(s) → triage vs current source → (comment QA if not a bug) →
> worktree fix → review → operator confirms → commit → operator pushes → next bug.**

It reuses harness-flow's infrastructure (MCP ingest, `flow-session.v1`,
worktree + work via `harness-work`, the confirm gate, commit-no-push, and the
approval-before-external-write gate). The differences from `harness-flow` are:

| | harness-flow (features) | harness-bugfix (bugs) |
|---|---|---|
| Multiple links | merged into one feature | **one at a time, sequentially** |
| "Verify" step | requirement completeness | **triage against the current source code** |
| Ask-back target | BA | **QA** (the bug reporter) |
| Negative outcome | — | **not a bug → comment QA, close, next bug** |
| Between units | n/a | **pause after each commit for the operator to push** |

## Core contract (read first)

- **Operator supplies the bug link(s).** A JIRA bug key (`BUG-123`) or Confluence
  URL. No JQL/board polling.
- **Multiple bugs run one at a time.** `harness-bugfix BUG-1 BUG-2 BUG-3` fixes
  BUG-1 fully, **pauses for you to push**, then on `--resume` fetches fresh main
  and starts BUG-2 from it. This keeps each fix on an up-to-date base and avoids
  merge conflicts between fixes. Bugs are NOT merged into one unit.
- **The harness commits, the operator pushes.** Never `git push` / `gh pr create`.
- **Every external write needs your approval first.** A QA comment, a JIRA
  transition, or a done comment is drafted, shown to you, and only sent on an
  explicit approval. Nothing is auto-posted.
- **Re-entrant.** Per-bug state lives in `flow-session.v1`
  (`.claude/state/flow/<bug-key>/session.json`); the batch order lives in
  `.claude/state/flow/bug-batch.json`.

## Quick Reference

| Input | Behavior |
|------|------|
| `/harness-bugfix BUG-123` | Triage + fix one bug |
| `/harness-bugfix BUG-1 BUG-2 BUG-3` | Fix sequentially; pause after each for you to push |
| `/harness-bugfix --resume` | Continue the batch (after you pushed the previous fix) |
| `/harness-bugfix BUG-123 --close-jira` | After commit, transition + post a done comment (you approve) |
| `/harness-bugfix BUG-123 --dry-run` | Triage + walk the flow with no MCP writes / no commit |

## Resolving the plugin bundle root

Same as harness-flow: resolve `HARNESS_PLUGIN_ROOT` from `CLAUDE_PLUGIN_ROOT`
(if it contains `scripts/`) else from `CLAUDE_SKILL_DIR`
(`${CLAUDE_SKILL_DIR}/../..`, or `../../..` for a mirror). Call only
`${HARNESS_PLUGIN_ROOT}/scripts/...`; keep `Plans.md` / `.claude/state/...` on
the host project side.

## Batch orchestration (sequential, pause-to-push)

Reference: [`${CLAUDE_SKILL_DIR}/references/sequential-batch.md`](${CLAUDE_SKILL_DIR}/references/sequential-batch.md)

1. Resolve `HARNESS_PLUGIN_ROOT` and probe MCP health once
   (`flow-mcp-health.sh`, tri-state; `not-configured`/`unreachable` → pause with
   `decision_needed.v1`).
2. Determine the batch:
   - With refs: write/refresh `.claude/state/flow/bug-batch.json`
     (`{refs:[...], created_at}`).
   - With `--resume` (no refs): read that batch file.
3. Pick the **next bug** = the first ref whose `flow-session` status is not
   `done` and not `not-a-bug`. If none remain → report the batch complete.
4. Run the per-bug state machine (below) for that one bug until it reaches
   `awaiting-push` (real bug, committed) or `not-a-bug`.
5. On `awaiting-push`: **stop** and tell the operator to push+merge, then re-run
   `/harness-bugfix --resume`. On `not-a-bug`: continue directly to the next bug.

## Per-bug state machine

```
[Step 1] Ingest        status: ingesting -> ingested
  Reference: references/triage-rubric.md (ingest section)
  git fetch origin; base = current up-to-date main/HEAD (so the fix starts fresh).
  JIRA key -> getJiraIssue (summary, description, steps-to-reproduce, environment,
    labels, status, reporter=QA). atlassianUserInfo once -> bot accountId.
  flow-ingest-bug.sh ... --out .claude/state/flow/<bug-key>/bug.json
  |
  v
[Step 2] Triage        status: triaging
  Reference: references/triage-rubric.md
  Check the report AGAINST THE CURRENT SOURCE CODE: locate the code path, decide
  whether the reported behavior is actually a defect (vs expected / already-fixed
  / config / user error). Prefer reproducing with a failing test.
  Write triage {verdict, evidence, code_refs[], reproduced, open_questions[]}.
  verdict == bug         -> Step 4
  verdict == not-a-bug   -> Step 3a
  verdict == needs-info  -> Step 3b
  |
  v
[Step 3a] Not a bug     status: not-a-bug   (terminal for this bug)
  Reference: references/qa-comment.md
  Draft a QA comment explaining WHY it is not a bug (cite code_refs). GET
  OPERATOR APPROVAL, then post (addCommentToJiraIssue) to the reporter's ticket.
  Optionally transition to a "Not a Bug"/"Rejected" state (--close-jira, approved).
  -> return to batch: next bug.

[Step 3b] Needs info    status: awaiting-ba  (reused: awaiting a ticket reply)
  Reference: references/qa-comment.md
  Draft a question to QA, GET APPROVAL, post, then auto-poll for the reply
  (flow-ba-match.sh) and re-run Step 2. Round cap 3 -> escalate.
  |
  v
[Step 4] Fix           status: working
  Delegate to harness-work (Solo for a single bug). It creates the worktree
  under .harness-worktrees/, fixes, self-reviews, and commits. If the bug was
  reproduced with a failing test, that test is the TDD RED evidence.
  Inject the bug key into the briefing so the commit reads [BUG-123].
  |
  v
[Step 5] Review        status: reviewing
  Reuse harness-work's built-in review loop (review-result.v1). Add
  harness-review --security for security bugs. REQUEST_CHANGES -> fix loop.
  |
  v
[Step 6] Confirm       status: awaiting-confirm
  Reference: harness-flow references/confirm-gate.md (decision_needed.v1 default,
  --accept-html opt-in). Show: bug summary, root cause, the fix, review verdict,
  changed files, commit preview. OK -> Step 7; not-OK -> fix loop.
  |
  v
[Step 7] Commit        status: committing -> awaiting-push
  Reference: harness-flow references/commit-close.md
  The fix commit is tagged [BUG-123]. NEVER push. --close-jira (approved) may
  transition + post a done comment. Then STOP:
  "Committed <hash> for BUG-123. Push it manually, then /harness-bugfix --resume
   for the next bug." status stays awaiting-push until the operator resumes.
  |
  v  (operator pushed; --resume)
  -> mark this bug done, return to batch -> next bug (Step 1 with fresh fetch).
```

## Stop / pause conditions

| Condition | status | Response |
|-----------|--------|----------|
| Not a bug | `not-a-bug` | Approve+post QA comment; go to next bug |
| Triage needs QA info | `awaiting-ba` | Approve+post question; auto-poll reply |
| Fix committed, awaiting your push | `awaiting-push` | STOP; you push, then `--resume` |
| not-OK at confirm / REQUEST_CHANGES | `working` | Fix loop (reuse failure-reticketing) |
| Round/rework cap hit | `escalated` | `decision_needed.v1` |
| Batch complete | (all `done`/`not-a-bug`) | Report summary |

## Related skills

- `harness-flow` — the feature sibling (merged multi-ticket; BA instead of QA)
- `harness-work` — worktree + fix + review loop (Steps 4-5)
- `harness-review` — extra review lens for security bugs (Step 5)
- `harness-accept` — optional ship/wait/reject HTML at the confirm gate (Step 6)
