---
name: ba-backlog
description: "Backlog hygiene scan before refinement or sprint planning. Takes a project key, a sprint, an Epic, a board's backlog, or a JQL, fetches the open Stories/Tasks/Bugs in scope (capped, and says when capped), and runs 11 cheap hygiene checks: missing acceptance criteria, thin description, possible duplicates, stale, stuck in progress, no Epic, broken links, unestimated in the next sprint, no assignee in a sprint, oversized, and label/component outliers. Reports counts per check, a Top 10 to fix before refinement, and a table per check with the suggested action and the skill to run next. Read-only until the operator approves; then it can post a marked comment asking the reporter to fix, add a label, link suspected duplicates, or hand the deep-check set to ba-story-verify. Never closes, deletes, or merges tickets. Trigger: backlog hygiene, groom the backlog, clean up the backlog, backlog health, is the backlog ready, refinement prep, sprint planning prep, find duplicate tickets, stale tickets, tickets without AC, /ba-backlog. Do NOT load for: scoring one ticket against the 13-gate rubric (use ba-story-verify), verifying an Epic (use ba-epic-verify), writing or rewriting a ticket (use ba-ticket), or implementing a ticket (use harness-flow)."
kind: workflow
purpose: "Scope (project/sprint/epic/JQL) -> fetch open issues (capped) -> 11 hygiene checks -> ranked report -> operator approves -> marked comments / labels / duplicate links / hand-off to ba-story-verify"
trigger: "backlog hygiene, groom the backlog, backlog health, refinement prep, sprint planning prep, find duplicate tickets, stale tickets"
shape: delegate
role: orchestrator
pair: ba-story-verify
owner: harness-core
since: "2026-10-26"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[--project KEY] [--sprint \"<name>|next|active\"] [--epic KEY] [--jql \"...\"] [--stale-days N] [--cap N] [--html] [--report-only] [--dry-run]"
user-invocable: true
effort: medium
---

# ba-backlog

> **Scope → fetch the open issues → cheap hygiene checks → ranked report →
> operator approves → comment / label / link / hand off.**

The janitor that runs **before** refinement or sprint planning, so the meeting
spends its time on decisions instead of discovering that half the tickets have
no acceptance criteria. It is a wide, shallow scan. The deep per-ticket check is
`ba-story-verify`; this skill finds the tickets that need it and says so.

## Rules (read first)

1. **Read-only until approved.** Searching and scoring write nothing. Every JIRA
   write (comment, label, issue link) is drafted, shown, and sent only after an
   explicit `AskUserQuestion` approval
   (`.claude/rules/autonomous-confirmation-scope.md` case 1). If
   `AskUserQuestion` is unavailable, print the question and stop.
2. **Never close, delete, merge, or transition.** A suspected duplicate is
   *linked* (`Duplicate`) and commented; the BA decides and closes it.
3. **Shallow, not deep.** Do not re-implement the 13-gate rubric of
   `ba-story-verify`. Each check is a cheap signal from fields already fetched;
   anything that needs judgment of the requirement routes to the right skill.
4. **Detect conventions, never assume them.** Story points, labels, components
   and the next sprint are checked only when the data shows the project uses
   them. A check that does not apply is `n-a` with the reason, not a pass.
5. **Ask, never invent.** Unknown scope, ambiguous sprint name, or an unclear
   duplicate is a question, not a guess. Duplicates are always "possible".
6. **Say when capped.** The scope is capped (default 200). The report states
   the cap and the total matching count every time.
7. **Never double-post.** Applied actions are logged to `applied.json`; a re-run
   skips anything already applied for the same key + check.
8. **English output.**

## Quick Reference

| Input | Behavior |
|------|------|
| `/ba-backlog --project DPD` | Open Stories/Tasks/Bugs in the DPD backlog (not Done), capped at 200 |
| `/ba-backlog --sprint next --project DPD` | Only the next (future) sprint: planning prep |
| `/ba-backlog --sprint active --project DPD` | Only the active sprint |
| `/ba-backlog --epic DPD-832` | Open children of that Epic |
| `/ba-backlog --jql "project = DPD AND labels = payments"` | Exactly that JQL (open filter added unless it names a status) |
| `/ba-backlog --project DPD --stale-days 14` | Stale threshold 14 days instead of 30 |
| `/ba-backlog --project DPD --cap 500` | Raise the cap |
| `/ba-backlog --project DPD --html` | Also write a single-file HTML report |
| `/ba-backlog --project DPD --report-only` | Report only, never offer an action |
| `/ba-backlog --project DPD --dry-run` | Report only, no state files and no JIRA writes |

## References

| Topic | File |
|-------|------|
| Scope resolution, JQL, fields, cap, fan-out | [scope-and-fetch.md](${CLAUDE_SKILL_DIR}/references/scope-and-fetch.md) |
| The 11 checks: id, detects, how, suggested action, routing | [hygiene-checks.md](${CLAUDE_SKILL_DIR}/references/hygiene-checks.md) |
| Report layout, ranking, HTML | [report-template.md](${CLAUDE_SKILL_DIR}/references/report-template.md) |
| Approval, comment template, apply, applied.json | [actions.md](${CLAUDE_SKILL_DIR}/references/actions.md) |
| Quick start + filled example report | [README.md](${CLAUDE_SKILL_DIR}/README.md) |

## Flow

```
[0] Resolve + probe
    HARNESS_PLUGIN_ROOT from CLAUDE_PLUGIN_ROOT (if it has scripts/), else
    ${CLAUDE_SKILL_DIR}/../.. (or ../../.. for a mirror).
    getAccessibleAtlassianResources once -> cloudId, then
      bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
      (success -> healthy, error -> unreachable, tools absent -> not-configured)
    not-configured / unreachable -> decision_needed.v1 and STOP. This skill
    cannot run without JIRA.
    |
    v
[1] Resolve scope                           -> references/scope-and-fetch.md
    --jql > --epic > --sprint > --project. No flag -> ask for the project
    (offer getVisibleJiraProjects). Build the JQL, count matches, apply --cap.
    Print: "<scope>: <N> matching, scanning <M> (cap <C>)" BEFORE scanning.
    Empty scope -> report it and stop; never widen the query on your own.
    |
    v
[2] Fetch (read-only)                       -> references/scope-and-fetch.md
    searchJiraIssuesUsingJql with only the needed fields, paged.
    Detect conventions once: story points field + usage, label/component usage,
    next/active sprint. >100 issues -> fan out with Task (read-only sub-agents,
    one page range each); the lead merges and runs the cross-issue checks.
    |
    v
[3] Run the checks                          -> references/hygiene-checks.md
    11 checks, each finding = key + check id + evidence + suggested action +
    route (ba-story-verify / ba-ticket rewrite / ba-epic-verify / none).
    possible-duplicate needs both texts quoted and the match reason.
    |
    v
[4] Report                                  -> references/report-template.md
    Counts per check -> Top 10 to fix before refinement -> one table per check.
    --html -> single-file HTML next to the state files.
    Save findings.json + report.md to .claude/state/ba-backlog/<slug>/
    (skipped under --dry-run). --report-only / --dry-run -> STOP here.
    |
    v
[5] Offer actions (ONE AskUserQuestion, multi-select) -> references/actions.md
    a) marked comment asking the reporter to fix (per selected check)
    b) add a label (default needs-refinement)
    c) link suspected duplicates ("Duplicate") + comment on both
    d) hand the missing-ac / oversized set to ba-story-verify (print command)
    Show the drafts, apply only what was approved, skip anything already in
    applied.json, log each write there immediately.
```

## Stop conditions

| Condition | Response |
|-----------|----------|
| MCP not-configured / unreachable | `decision_needed.v1`, stop |
| No scope flag and the project cannot be inferred | Ask for the project; never guess |
| `--sprint next` and the board has no future sprint | Say so, offer the active sprint or the backlog; do not substitute silently |
| Sprint name matches several sprints | Ask which one |
| Scope is empty after filtering | Report the JQL and the zero count, stop |
| Total matches exceed the cap | Scan the first `<cap>` by rank, state the cap in the report header |
| A page of the search fails | Retry once; still failing -> report the partial scan and which range is missing |
| An approved write fails mid-batch | Stop; list what was applied and what is left (applied.json makes the re-run safe) |
| Operator approves nothing | Keep the report and state, write nothing to JIRA |

## Report

Say: the scope and JQL, matched vs scanned (and the cap), conventions detected
(points / labels / components / sprint), counts per check, the Top 10, and,
after step 5, exactly what was written where. Do not narrate per-issue checking.
End with the next action, e.g. "Run `/ba-story-verify DPD-101 DPD-117 ...` on
the 9 tickets with no AC before Thursday's refinement."

## Related skills

- `ba-story-verify` — deep 13-gate check of the tickets this scan flags
- `ba-epic-verify` — check an Epic that has thin or orphaned children
- `ba-ticket` — rewrite a thin or oversized ticket into the short format
- `harness-flow` — build a ticket once it is clear
