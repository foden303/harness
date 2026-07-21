---
name: harness-story-verify
description: "Verify that BA-authored user stories are clear enough to build, and ask the BA the missing questions on the ticket. Takes an Epic link (expands to every child ticket), a single ticket link, or a list of tickets, scores each one independently against a user-story/acceptance-criteria rubric, and drafts one comment of open questions per unclear ticket — posted only after the operator approves. Read-only until then; it never plans, implements, or commits. Trigger: verify user story, check requirements clarity, review an epic's tickets, is this ticket clear, ask the BA, DoR check, PROJ-123 clear enough. Do NOT load for: implementing a requirement (use harness-flow), bug triage (use harness-bugfix), code review, or release."
description-en: "Verify that BA-authored user stories are clear enough to build, and ask the BA the missing questions on the ticket. Takes an Epic link (expands to every child ticket), a single ticket link, or a list of tickets, scores each one independently against a user-story/acceptance-criteria rubric, and drafts one comment of open questions per unclear ticket — posted only after the operator approves. Read-only until then; it never plans, implements, or commits. Trigger: verify user story, check requirements clarity, review an epic's tickets, is this ticket clear, ask the BA, DoR check, PROJ-123 clear enough. Do NOT load for: implementing a requirement (use harness-flow), bug triage (use harness-bugfix), code review, or release."
kind: workflow
purpose: "Expand an Epic or ticket list -> verify each user story against the US/AC rubric -> draft BA questions per unclear ticket -> operator approves -> post comments -> track replies"
trigger: "verify user story, epic clarity check, is this ticket clear, ask the BA, DoR check"
shape: delegate
role: orchestrator
base: harness-flow
pair: harness-flow
owner: harness-core
since: "2026-07-20"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "ScheduleWakeup", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<EPIC-KEY>|<ISSUE-KEY>|<url> ...] [--jql \"...\"] [--resume] [--report-only] [--html] [--dry-run]"
user-invocable: true
effort: high
---

# harness-story-verify

The requirements-quality gate that runs **before** anyone starts building:

> **Epic or ticket link(s) → expand → verify each story independently →
> draft the open questions per ticket → operator approves → post to the BA →
> track replies → re-verify.**

It is the "verify + ask the BA" half of `harness-flow`, lifted out and scaled to
a whole Epic. It stops at a clear/unclear verdict — **it never plans, writes
code, or commits.** When an Epic comes back clear, hand the tickets to
`harness-flow` to build them.

| | harness-flow | harness-story-verify |
|---|---|---|
| Multiple links | merged into **one** feature | verified as **N independent** stories |
| Epic link | not expanded | **expanded to every child ticket** |
| Ends at | committed change | **verdict + questions on the ticket** |
| Ask-back target | BA | BA (same marker + matcher) |

## Core contract (read first)

- **Read-only until you approve.** Fetching issues and scoring them writes
  nothing to JIRA. The only external write is the clarification comment, and it
  is drafted, shown to you, and sent **only** on an explicit approval
  (`.claude/rules/autonomous-confirmation-scope.md` case 1). Nothing auto-posts.
- **One ticket = one verdict = one comment.** Questions are never pooled across
  tickets; a question about `PROJ-124` is posted on `PROJ-124`.
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
| `/harness-story-verify PROJ-100` (an Epic) | Expand to all children, verify each, draft questions per unclear child |
| `/harness-story-verify PROJ-123` | Verify that one story |
| `/harness-story-verify PROJ-123 PROJ-124 PROJ-125` | Verify all three **independently** (not merged) |
| `/harness-story-verify https://<site>/browse/PROJ-123` | Same, from a URL |
| `/harness-story-verify --jql "parent = PROJ-100 AND status = 'To Do'"` | Verify the JQL result set |
| `/harness-story-verify --resume` | Re-check for BA replies, fold them in, re-verify |
| `/harness-story-verify PROJ-100 --report-only` | Verify + report, never offer to post (no JIRA writes at all) |
| `/harness-story-verify PROJ-100 --html` | Also render the report as a single-file HTML |
| `/harness-story-verify PROJ-100 --dry-run` | Walk the flow, write no state and no comments |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<EPIC-KEY>` / `<ISSUE-KEY>` / `<url>` | Verification target(s) | required (unless `--resume` / `--jql`) |
| `--jql "<query>"` | Use a JQL result set as the batch | - |
| `--resume` | Re-check BA replies on the existing batch | - |
| `--report-only` | Never post; output the report only | off |
| `--html` | Also render `story-verify-report.html` | off |
| `--dry-run` | No state writes, no comments | off |
| `--include-done` | Also verify children in a done/closed status | off (skipped) |

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
`<batch-id>` is derived from the root ref (`PROJ-100` → `proj-100`; a bare list
→ the first key; `--jql` → `jql-<n>` where `<n>` is the ticket count).

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
[Step 1] Expand        -> batch.json
  Reference: references/epic-expansion.md
  Epic key    -> children via JQL (parent, then the Epic Link fallback)
  Ticket keys -> that exact list, deduped, order preserved
  --jql       -> the query result set
  Skip done/closed children unless --include-done; skip sub-tasks of a child.
  story-verify-batch.sh init --batch-id <id> --mode epic|tickets \
    --root <ref> --keys <k1,k2,...>
  Report the expansion (n found / n skipped and why) BEFORE verifying.
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
[Step 4] Approve + post   state: needs-clarification -> awaiting-ba
  Reference: references/ba-comment.md
  Draft ONE marked comment per unclear ticket, show ALL drafts to the operator in
  one AskUserQuestion (post all / pick / edit / skip), and post ONLY what was
  approved (addCommentToJiraIssue). Never auto-post.
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
| Epic has zero eligible children | n/a | Report the expansion result and stop (do not fall back to a broader JQL) |
| Operator declines to post | `needs-clarification` | Keep the draft in the report; the operator asks the BA themselves |
| BA reply not yet available | `awaiting-ba` | Auto-poll (ScheduleWakeup) or wait for `--resume` |
| Clarification round cap (3) reached | `escalated` | `decision_needed.v1` — proceed on a stated assumption, keep waiting, or drop |

## Silence policy

Report on: expansion result, per-ticket verdict, the draft set before approval,
what was posted, replies folded in, final summary. Stay silent on: per-gate
scoring narration, pacing waits between reply checks with nothing new. Always
end a completed run by naming the clear/unclear/blocked counts and the next
action (hand the clear tickets to `harness-flow`, or wait on the open questions).

## Related skills

- `harness-flow` — build a ticket once it is verified clear (Steps 4-9 there)
- `harness-bugfix` — the bug sibling (triage vs source, QA ask-back)
- `harness-plan` — turn verified stories into Plans.md tasks
- `harness-accept` — acceptance decision after the work is delivered
