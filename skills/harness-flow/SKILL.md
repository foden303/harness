---
name: harness-flow
description: "End-to-end operator-driven flow from a JIRA/Confluence requirement to a reviewed, committed (never pushed) change. Ingests an issue key or Confluence URL, verifies the requirement, asks the BA back via a ticket comment when unclear, plans, splits into worktrees, works, reviews, gets operator confirmation, then creates commits (the operator pushes manually). Trigger: run the flow, ingest a requirement, issue key, PROJ-123, confluence page, requirement to commit. Do NOT load for: standalone planning, review, or release."
description-en: "End-to-end operator-driven flow from a JIRA/Confluence requirement to a reviewed, committed (never pushed) change. Ingests an issue key or Confluence URL, verifies the requirement, asks the BA back via a ticket comment when unclear, plans, splits into worktrees, works, reviews, gets operator confirmation, then creates commits (the operator pushes manually). Trigger: run the flow, ingest a requirement, issue key, PROJ-123, confluence page, requirement to commit. Do NOT load for: standalone planning, review, or release."
kind: workflow
purpose: "Orchestrate requirement ingest -> verify -> BA loop -> plan -> worktree -> work -> review -> confirm -> commit (no push)"
trigger: "run the flow, ingest a requirement, issue key, confluence url"
shape: delegate
role: orchestrator
base: harness-work
pair: harness-plan
owner: harness-core
since: "2026-07-16"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "ScheduleWakeup", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<ISSUE-KEY>|<url> ...] [--resume <session-id>] [--accept-html] [--close-jira] [--dry-run]"
user-invocable: true
effort: high
---

# harness-flow

A thin orchestrator that walks one real ticket end to end:

> **JIRA/Confluence requirement → verify → (ask the BA back if unclear) → plan →
> worktree → work → review → operator confirms → commit → (operator pushes manually).**

Every heavy stage is delegated to an existing skill (`harness-plan`,
`harness-work`, `harness-review`) — this skill only ingests the external
requirement, runs the BA-clarification loop, gates on operator confirmation, and
creates the final commits. **It never pushes.**

## Core contract (read first)

- **Operator supplies the target.** Trigger with a JIRA issue key (`PROJ-123`) or
  a Confluence page URL. There is no JQL/board polling.
- **One link = one ticket; multiple links = one merged feature.** Passing several
  refs (`PROJ-123 PROJ-124 PROJ-125`) means they are the **same feature** —
  harness-flow ingests all of them, **merges into a single requirement**, and
  verifies/plans/confirms/commits them as one unit (one `flow-session`). It does
  not run them as independent tickets. The plan may still split the merged
  feature internally into phases/sub-plans.
- **The harness commits, the operator pushes.** harness-flow never runs
  `git push`, `gh pr create`, or any remote transmission. See
  [`${CLAUDE_SKILL_DIR}/references/commit-close.md`](${CLAUDE_SKILL_DIR}/references/commit-close.md).
- **Every external write needs your approval first.** Posting a BA comment,
  transitioning a JIRA issue, or posting a done comment are external
  transmissions — harness-flow drafts them, shows them to you, and only sends on
  an explicit approval. Nothing is auto-posted to JIRA/Confluence.
- **Re-entrant and idempotent.** State lives in `flow-session.v1`; every
  invocation resumes at the recorded `status` and never repeats a completed step.
- **MCP dependency.** JIRA/Confluence access uses the Atlassian Rovo MCP tools
  (`mcp__claude_ai_Atlassian_Rovo__*`). If they are absent (headless/cron), the
  tri-state health probe reports `not-configured` and the skill pauses at the
  first step that needs them rather than guessing.

## Quick Reference

| Input | Behavior |
|------|------|
| `/harness-flow PROJ-123` | Ingest JIRA issue PROJ-123 and run the full flow |
| `/harness-flow PROJ-123 PROJ-124 PROJ-125` | Treat all three as ONE feature — merge, verify, plan, commit together |
| `/harness-flow https://<site>/wiki/.../pageId` | Ingest a Confluence page and run the full flow |
| `/harness-flow --resume <session-id>` | Resume a paused run (BA reply arrived, or manual continue) |
| `/harness-flow PROJ-123 --accept-html` | Use the harness-accept ship/wait/reject HTML at the confirm gate |
| `/harness-flow PROJ-123 --close-jira` | After commit, transition the issue + post a done comment |
| `/harness-flow PROJ-123 --dry-run` | Walk the state machine with no MCP writes / no git commits |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<ISSUE-KEY>` / `<confluence-url>` | The requirement source | required (unless `--resume`) |
| `--resume <session-id>` | Resume a paused session | - |
| `--accept-html` | Render harness-accept HTML at the confirm gate | off (uses `decision_needed.v1`) |
| `--close-jira` | Transition the issue + post a done comment after commit | off |
| `--dry-run` | No external writes, no commits | off |

## Resolving the plugin bundle root

harness-flow calls helper scripts under the plugin bundle root, not the host
project's cwd. At the start of every invocation resolve `HARNESS_PLUGIN_ROOT`:

1. If `CLAUDE_PLUGIN_ROOT` exists and contains `scripts/`, use it.
2. Otherwise derive it from `CLAUDE_SKILL_DIR`
   (`skills/harness-flow` → `${CLAUDE_SKILL_DIR}/../..`;
   `.agents/skills/harness-flow` mirror → `${CLAUDE_SKILL_DIR}/../../..`).
3. If neither resolves, stop and re-run after setting `CLAUDE_PLUGIN_ROOT`.

Keep `Plans.md` and `.claude/state/...` on the host project side. Call only
helper scripts from `${HARNESS_PLUGIN_ROOT}/scripts/...`.

## State machine

State file: `.claude/state/flow/<session-id>/session.json` (`flow-session.v1`),
managed only through `${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh`.
`<session-id>` is derived from the source ref (e.g. `PROJ-123` → `proj-123`;
Confluence page id → `conf-<pageId>`), so re-running the same target resumes the
same session.

On every invocation:

1. Resolve `HARNESS_PLUGIN_ROOT` (above).
2. If `--resume <id>` or a session file already exists for the target, read it
   and jump to the handler for its `status`. Otherwise start at Step 1.
3. Probe MCP health once and record it:
   `bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>`
   where `<result>` is what a lightweight Rovo call
   (`getAccessibleAtlassianResources`) returned: success → `healthy`,
   call error → `unreachable`, tools not present → `not-configured`.
   Persist with `flow-session.sh set session.json mcp_health <state>`.

```
[Step 1] Ingest        status: ingesting -> ingested
  Reference: references/ingestion.md
  For EACH ref passed (1 or many):
    JIRA key   -> getJiraIssue (summary, description, acceptance-criteria field, labels, type, status, reporter)
    Conf URL   -> getConfluencePage (+ getConfluencePageFooterComments)
  atlassianUserInfo once -> cache bot accountId into clarification.bot_account_id
  If >1 ref: MERGE them into ONE requirement (union of criteria, concatenated
    descriptions with per-ticket headers) and pass --sources-file listing all
    refs; the primary (first) ref becomes source/source_ref + session_id.
  Extract fields in-context, then:
    flow-ingest-requirement.sh --source <s> --source-ref <ref> --title <t> \
      --description-file <tmp> --acceptance-criteria-file <tmp> --labels a,b \
      --issue-type <T> --status <S> --reporter-account-id <id> \
      --mcp-available true --out .claude/state/flow/<id>/requirement.json
  flow-session.sh set session.json requirement_path <path>
  |
  v
[Step 2] Verify        status: verifying
  Reference: references/verify-rubric.md  (6 binary gates)
  Write the verification block into requirement.json.
  verdict == ok               -> Step 4
  verdict == needs-clarification -> Step 3
  |
  v
[Step 3] BA loop       status: awaiting-ba  <-> verifying
  Reference: references/ba-loop.md
  Draft a MARKED comment with the open_questions, then GET OPERATOR APPROVAL
  before posting (posting = external transmission; never auto-post):
    show the draft via AskUserQuestion -> only on "Post it" do you send
    JIRA       -> addCommentToJiraIssue
    Confluence -> createConfluenceFooterComment
  Store clarification {nonce, posted_comment_id, posted_at, bot_account_id, rounds}.
  AFTER the approved post, auto-poll via ScheduleWakeup (see ba-loop.md): each
  wake re-fetches comments, matches the BA reply, folds it into requirement.json,
  re-runs Step 2. (Auto-poll only READS; no approval needed to read.)
  Round cap (3) -> manual --resume -> escalate via decision_needed.v1.
  MCP unreachable here -> emit decision_needed.v1 and pause.
  |
  v
[Step 4] Plan          status: planning
  Reference: references/planning-split.md
  Delegate to harness-plan create with the requirement + JIRA key as provenance.
  Split long requirements into Phases + numbered subtasks (preferred), or named
  plans for genuinely independent deliverables (record in session.plans[]).
  Persist the ## Pre-approval block to .claude/state/plan-preapprovals.json.
  Gate: go run ./cmd/harness plans check-deps
  |
  v
[Step 5-6] Worktree + Work   status: working
  Delegate to harness-work all (auto: 1=Solo / 2-3=Parallel / 4+=Breezing).
  Worktrees (.harness-worktrees/), sprint contracts, TDD RED logs, and the
  worker self_review[] gate all run inside harness-work.
  Inject the JIRA key into the worker/lead briefing so commit messages carry
  [PROJ-123]. Record produced commit hashes into session.commit_hashes[].
  |
  v
[Step 7] Review        status: reviewing
  Reuse harness-work's built-in review loop (review-result.v1). For high-risk
  labels detected at ingestion, add harness-review --dual / --security.
  |
  v
[Step 8] Confirm       status: awaiting-confirm
  Reference: references/confirm-gate.md
  Default: decision_needed.v1 CLI gate (requirement + JIRA key, per-criterion
  verified/unverified, verdict, changed files, commit-message preview).
  --accept-html: render harness-accept ship/wait/reject.
  OK        -> Step 9
  not-OK    -> Step 10 (capture the reason)
  |
  v
[Step 9] Commit        status: committing -> done
  Reference: references/commit-close.md
  Per-task commits, each tagged [PROJ-123]. NEVER push.
  --close-jira: getTransitionsForJiraIssue -> transitionJiraIssue + a done comment
  noting the change is committed locally and awaits the operator's manual push.
  |
  v
[Step 10] Fix / rework   status: working (re-entry)
  Route not-OK / REQUEST_CHANGES back to harness-work on the failing task(s),
  reusing references/failure-reticketing.md (per-task counter, buildFixTaskID,
  3-strike escalation). The operator's not-OK reason becomes the fix-task Content.
  After APPROVE, re-enter Step 8. Cap rework_rounds; escalate on exhaustion.
```

## Stop / pause conditions

| Condition | status | Response |
|-----------|--------|----------|
| BA reply not yet available | `awaiting-ba` | Auto-poll (ScheduleWakeup) or wait for `--resume` |
| Clarification round cap reached | `escalated` | `decision_needed.v1` (request-unachievable) |
| MCP unreachable at a step that needs it | unchanged | `decision_needed.v1`, pause |
| Operator answers not-OK at confirm | `working` | Fix/rework (Step 10) |
| Rework round cap reached | `escalated` | Escalate to the operator |
| All committed | `done` | Report commit hashes + remind operator to push manually |

## Silence policy

Report on: ingest done, verification verdict, BA comment posted, BA reply folded
in, plan created, work/review verdict per task, confirm-gate result, commit
hashes, escalation. Stay silent on: pacing waits between BA-loop wakes with no
new reply, fine-grained stdout. Always end a `done` run by naming the commit
hashes and stating the branch is **un-pushed** (operator pushes manually).

## Related skills

- `harness-plan` — planning (Step 4), invoked via `create`
- `harness-work` — worktree + implementation + review loop (Steps 5-7)
- `harness-review` — optional extra review lens for high-risk changes (Step 7)
- `harness-accept` — optional ship/wait/reject HTML at the confirm gate (Step 8)
- `harness-loop` — the ScheduleWakeup re-entry pattern reused by the BA loop
