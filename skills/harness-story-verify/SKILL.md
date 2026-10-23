---
name: harness-story-verify
description: "Verify that BA-authored user stories are clear enough to build, and ask the BA the missing questions on the ticket. Takes a single ticket link or a list of tickets (or a JQL result set), scores each one independently against a user-story/acceptance-criteria rubric, and drafts one comment of open questions per unclear ticket. When a comment is posted it also hands the ticket back: the reporter is @mentioned, made assignee, and the status is moved to a clarification state. Posted only after the operator approves; read-only until then, and it never plans, implements, or commits. An Epic link is routed to harness-epic-verify instead of expanded. Trigger: verify user story, check requirements clarity, is this ticket clear, ask the BA, DoR check, PROJ-123 clear enough. Do NOT load for: verifying an Epic (use harness-epic-verify), implementing a requirement (use harness-flow), bug triage (use harness-bugfix), code review, or release."
description-en: "Verify that BA-authored user stories are clear enough to build, and ask the BA the missing questions on the ticket. Takes a single ticket link or a list of tickets (or a JQL result set), scores each one independently against a user-story/acceptance-criteria rubric, and drafts one comment of open questions per unclear ticket. When a comment is posted it also hands the ticket back: the reporter is @mentioned, made assignee, and the status is moved to a clarification state. Posted only after the operator approves; read-only until then, and it never plans, implements, or commits. An Epic link is routed to harness-epic-verify instead of expanded. Trigger: verify user story, check requirements clarity, is this ticket clear, ask the BA, DoR check, PROJ-123 clear enough. Do NOT load for: verifying an Epic (use harness-epic-verify), implementing a requirement (use harness-flow), bug triage (use harness-bugfix), code review, or release."
kind: workflow
purpose: "Verify a ticket list against the US/AC rubric -> draft BA questions per unclear ticket -> operator approves -> post comments + hand the ticket back to its reporter -> track replies"
trigger: "verify user story, is this ticket clear, ask the BA, DoR check"
shape: delegate
role: orchestrator
base: harness-flow
pair: harness-epic-verify
owner: harness-core
since: "2026-07-20"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "ScheduleWakeup", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<ISSUE-KEY>|<url> ...] [--jql \"...\"] [--ask-status \"<name>\"] [--no-handoff] [--resume] [--report-only] [--html] [--dry-run]"
user-invocable: true
effort: high
---

# harness-story-verify

The requirements-quality gate that runs **before** anyone starts building:

> **Ticket link(s) → verify each story independently → draft the open questions
> per ticket → operator approves → post to the BA + hand the ticket back to its
> reporter → track replies → re-verify.**

It is the "verify + ask the BA" half of `harness-flow`, lifted out and scaled to
a list of stories. It stops at a clear/unclear verdict — **it never plans, writes
code, or commits.** When a ticket comes back clear, hand it to `harness-flow` to
build it.

| | harness-flow | harness-story-verify | harness-epic-verify |
|---|---|---|---|
| Unit | one feature | **N independent stories** | one Epic |
| Multiple links | merged into **one** feature | verified independently | n/a |
| Epic link | not expanded | **routed out** to `harness-epic-verify` | the target |
| Questions | one set | one set per ticket | **one set per lens** (BE/FE/BA) |
| Ends at | committed change | **verdict + questions on the ticket** | verdict + questions on the Epic |

## Core contract (read first)

- **Read-only until you approve.** Fetching issues and scoring them writes
  nothing to JIRA. The external writes — the clarification comment and the
  reporter handoff (assignee + status) — are drafted, shown to you, and sent
  **only** on an explicit approval
  (`.claude/rules/autonomous-confirmation-scope.md` case 1). Nothing auto-posts
  and nothing auto-transitions.
- **One ticket = one verdict = one comment.** Questions are never pooled across
  tickets; a question about `PROJ-124` is posted on `PROJ-124`.
- **Stories only.** An Epic ref is routed to `harness-epic-verify`, never scored
  here — an Epic has no acceptance criteria of its own, so these gates would fail
  for the wrong reasons.
- **Questions must trace to a failing gate.** Every question in the draft comes
  from a gate that failed. No gate failure, no question — this keeps the BA from
  being asked things the ticket already answers.
- **No requirement invention.** When a field is missing, ask; never fill in a
  plausible acceptance criterion and proceed. A guessed AC is worse than a
  missing one because it looks answered.
- **Re-entrant.** Batch cursor + per-ticket records live under
  `.claude/state/story-verify/<batch-id>/`; a re-run resumes and never re-posts
  a question already asked.
- **MCP dependency.** JIRA access uses the Atlassian Rovo MCP tools. Absent
  (headless/cron) → tri-state health reports `not-configured` and the skill
  pauses at the first step that needs it rather than guessing.

## Quick Reference

| Input | Behavior |
|------|------|
| `/harness-story-verify PROJ-123` | Verify that one story |
| `/harness-story-verify PROJ-123 PROJ-124 PROJ-125` | Verify all three **independently** (not merged) |
| `/harness-story-verify https://<site>/browse/PROJ-123` | Same, from a URL |
| `/harness-story-verify PROJ-100` (an Epic) | **Route out**: recommend `/harness-epic-verify PROJ-100`, verify nothing |
| `/harness-story-verify --jql "parent = PROJ-100 AND status = 'To Do'"` | Verify the JQL result set |
| `/harness-story-verify PROJ-123 --ask-status "Waiting for BA"` | Force the status the handoff moves to |
| `/harness-story-verify PROJ-123 --no-handoff` | Comment only; do not touch assignee or status |
| `/harness-story-verify --resume` | Re-check for BA replies, fold them in, re-verify |
| `/harness-story-verify PROJ-123 --report-only` | Verify + report, never offer to post (no JIRA writes at all) |
| `/harness-story-verify PROJ-123 --html` | Also render the report as a single-file HTML |
| `/harness-story-verify PROJ-123 --dry-run` | Walk the flow, write no state and no comments |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<ISSUE-KEY>` / `<url>` | Verification target(s) — stories, not Epics | required (unless `--resume` / `--jql`) |
| `--jql "<query>"` | Use a JQL result set as the batch | - |
| `--ask-status "<name>"` | Status the handoff transitions to | matched from a candidate list |
| `--no-handoff` | Never change assignee or status | off (handoff on) |
| `--resume` | Re-check BA replies on the existing batch | - |
| `--report-only` | Never post; output the report only | off |
| `--html` | Also render `story-verify-report.html` | off |
| `--dry-run` | No state writes, no comments | off |
| `--include-done` | Also verify tickets in a done/closed status | off (skipped) |

## Resolving the plugin bundle root

Same as `harness-flow`: resolve `HARNESS_PLUGIN_ROOT` from `CLAUDE_PLUGIN_ROOT`
(if it contains `scripts/`), else from `CLAUDE_SKILL_DIR`
(`${CLAUDE_SKILL_DIR}/../..`, or `../../..` for a mirror). Call only
`${HARNESS_PLUGIN_ROOT}/scripts/...`; keep state under the host project's
`.claude/state/story-verify/`.

## State machine

Batch cursor: `.claude/state/story-verify/<batch-id>/batch.json`, managed only
through `${HARNESS_PLUGIN_ROOT}/scripts/story-verify-batch.sh`.
Per-ticket verdicts: `.claude/state/story-verify/<batch-id>/<KEY>.json`
(`story-verification.v1`), written only through
`${HARNESS_PLUGIN_ROOT}/scripts/story-verify-record.sh`.
`<batch-id>` is derived from the root ref (a bare list → the first key
lowercased, `PROJ-101` → `proj-101`; `--jql` → `jql-<n>` where `<n>` is the
ticket count; called from `harness-epic-verify --with-children` → the Epic key).

```
[Step 0] Resolve + probe
  Resolve HARNESS_PLUGIN_ROOT.
  Probe MCP once:
    bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
    (getAccessibleAtlassianResources: success -> healthy, error -> unreachable,
     tools absent -> not-configured)
  not-configured / unreachable -> decision_needed.v1 and STOP. Never guess.
  |
  v
[Step 1] Resolve targets -> batch.json
  Reference: references/target-list.md
  Ticket keys -> that exact list, deduped, order preserved
  --jql       -> the query result set
  Epic key    -> STOP and route to /harness-epic-verify (do not expand, do not score)
  Skip done/closed tickets unless --include-done; skip sub-tasks of a listed ticket.
  story-verify-batch.sh init --batch-id <id> --mode tickets \
    --root <ref> --keys <k1,k2,...>
  Report the target list (n in scope / n skipped and why) BEFORE verifying.
  |
  v
[Step 2] Verify each   -> <KEY>.json (state: clear | needs-clarification | blocked)
  Reference: references/us-rubric.md   (12 gates, 8 blocker + 4 advisory)
  Per ticket: getJiraIssue (summary, description, AC field, labels, type, status,
    reporter, parent, links, attachments/design links, comments).
  Score every gate to pass | fail | n-a(+note). Each failing blocker contributes
  >=1 concrete question. Persist via story-verify-record.sh (it derives the
  verdict from the gates — do not hand-write it).
  Tickets are independent: verify all of them before asking anything.
  For a batch of >=6 tickets, fan out with Task (one sub-agent per ticket,
  read-only) and collect the records; <6 -> verify in-context.
  |
  v
[Step 3] Report        Reference: references/report.md
  One table: ticket | verdict | failing gates | #questions.
  --html -> render a single-file HTML alongside it.
  --report-only -> STOP here.
  |
  v
[Step 4] Approve + post + handoff   state: needs-clarification -> awaiting-ba
  Reference: references/ba-comment.md
  Draft ONE marked comment per unclear ticket (reporter @mentioned), show ALL
  drafts to the operator in one AskUserQuestion (post all / pick / edit / skip),
  and post ONLY what was approved (addCommentToJiraIssue). Never auto-post.
  Then per posted ticket, unless --no-handoff:
    editJiraIssue       assignee = reporter
    transitionJiraIssue status -> the one chosen by jira-status-match.sh
  A missing transition or a missing reporter is a recorded skip, never a failure.
  |
  v
[Step 5] Track replies    state: awaiting-ba -> answered | needs-clarification
  Reference: references/ba-comment.md (resume section)
  ScheduleWakeup re-entry: re-fetch comments, match via flow-ba-match.sh, fold the
  reply into the ticket record, re-run Step 2 for that ticket only.
  Re-verify clear -> answered. Still failing -> follow-up (round cap 3) -> escalated.
  |
  v
[Done] All tickets terminal -> final summary + next action
  story-verify-batch.sh summary <batch.json>
```

## Stop / pause conditions

| Condition | State | Response |
|-----------|-------|----------|
| MCP not-configured / unreachable | unchanged | `decision_needed.v1`, stop |
| A ticket cannot be read (permission) | `blocked` | Record verdict `blocked`, continue the rest, list them in the summary |
| The ref is an Epic | n/a | Report the type, recommend `/harness-epic-verify <KEY>`, stop |
| The target list is empty after filtering | n/a | Report the counts per reason and stop (do not fall back to a broader JQL) |
| Operator declines to post | `needs-clarification` | Keep the draft in the report; the operator asks the BA themselves. No handoff |
| Transition unavailable | `awaiting-ba` | Post + assign anyway, record `transition_skipped_reason`, name it in the summary |
| Reporter missing on the ticket | `awaiting-ba` | Skip the assign, record `assign_skipped_reason`, still post and still transition |
| BA reply not yet available | `awaiting-ba` | Auto-poll (ScheduleWakeup) or wait for `--resume` |
| Clarification round cap (3) reached | `escalated` | `decision_needed.v1` — proceed on a stated assumption, keep waiting, or drop |

## Silence policy

Report on: the target list, per-ticket verdict, the draft set before approval,
what was posted, the handoff result per ticket (assignee + status, or why
skipped), replies folded in, final summary. Stay silent on: per-gate scoring
narration, pacing waits between reply checks with nothing new. Always end a
completed run by naming the clear/unclear/blocked counts and the next action
(hand the clear tickets to `harness-flow`, or wait on the open questions).

## Related skills

- `harness-epic-verify` — the Epic sibling: epic rubric + BE/FE/BA lens questions
- `harness-flow` — build a ticket once it is verified clear (Steps 4-9 there)
- `harness-bugfix` — the bug sibling (triage vs source, QA ask-back)
- `harness-plan` — turn verified stories into Plans.md tasks
- `harness-accept` — acceptance decision after the work is delivered
