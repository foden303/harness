---
name: ba-change
description: "Change-impact analysis for a requirement change. Takes a change request (pasted text, an email, meeting notes, or a JIRA comment/issue link) and a scope to search (an Epic key, a list of keys, a JQL, or a Confluence spec URL), restates the change as before -> after for the BA to confirm, reads every ticket and the spec in scope, marks each impacted / maybe / not impacted with the quoted text affected, and drafts the exact updates: AC and field diffs for tickets not started, a marked notice comment to the assignee for tickets in progress, a new follow-up ticket for tickets already done, and a spec diff. Writes an impact report and applies only what the operator approves. Trigger: change request, requirement changed, what does this change affect, impact analysis, change impact, scope change, the client changed the rule, update the tickets for this change, /ba-change. Do NOT load for: writing a new ticket from scratch (use ba-ticket), checking a ticket is clear (use ba-story-verify / ba-epic-verify), tracing requirements to commits and tests (use ba-trace), or implementing the change (use harness-flow)."
kind: workflow
purpose: "Change request -> confirmed before/after -> impact per ticket/spec/test -> drafted diffs, notices, follow-ups -> impact report -> operator approves -> apply (logged, never double-applied)"
trigger: "change request, requirement changed, impact analysis, change impact, scope change, update the tickets for this change"
shape: delegate
role: orchestrator
pair: ba-ticket
owner: harness-core
since: "2026-10-26"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<change text>|<file>|<ISSUE-KEY or comment URL>] --scope <EPIC|KEY,KEY,...> | --jql \"...\" [--spec <confluence url>] [--draft-only] [--dry-run]"
user-invocable: true
effort: high
---

# ba-change

> **Change request → confirmed before/after → what it touches, ticket by ticket
> → drafted updates → one approval → applied and logged.**

A requirement changed mid-flight. This skill finds every ticket, spec section
and test that the change touches, says exactly what text changes, and drafts the
update for each — so nothing built next week still follows the old rule.

## Rules (read first)

1. **The restatement is the basis of everything.** Step 1 turns the request into
   before → after lines and the BA confirms them before any impact search. An
   unconfirmed restatement never drives an edit.
2. **Quote, don't summarise.** Every impact cites the exact text affected (AC
   row, field row, business rule, flow step, test case). No quote, no impact.
3. **"Maybe impacted" is never auto-edited.** It becomes a question to the BA.
4. **Status decides the action.** Not started → edit the ticket. In progress →
   comment and tell the assignee. Done → a NEW follow-up ticket; never reopen a
   done ticket silently.
5. **Ask, never invent.** A missing rule, number or decision is a
   decision-shaped question (AskUserQuestion, up to 4 per round, ready-made
   options). No `TBD`, `???`, `etc.` in any output.
6. **Read-only until approved.** Every JIRA edit, comment, create and every
   Confluence update is drafted, shown, and sent only after one explicit
   approval (`.claude/rules/autonomous-confirmation-scope.md` case 1). If
   AskUserQuestion is unavailable, print the question and stop.
7. **Never overwrite unseen edits.** Re-read each target right before writing;
   if it changed since it was read, re-draft and re-show.
8. **Never double-apply.** Every write is logged to `applied.json`; a re-run
   skips anything already there.
9. **BA voice, English output.** Same style rules as `ba-ticket` (no code
   outside the BE / FE notes).

## Quick Reference

| Input | Behavior |
|------|------|
| `/ba-change "Max discount is now 30%, was 50%" --scope DPD-832` | Restate, search the Epic's children, draft updates, apply on approval |
| `/ba-change email.txt --scope DPD-901,DPD-902,DPD-910` | Same, for a list of tickets |
| `/ba-change DPD-950 --jql "project = DPD AND labels = checkout"` | The change is in DPD-950 (issue or comment); search the JQL set |
| `/ba-change notes.md --scope DPD-832 --spec https://<site>/wiki/.../123` | Also diff the Confluence spec page |
| `/ba-change "..." --scope DPD-832 --draft-only` | Full report + drafts saved; never write to JIRA/Confluence |
| `/ba-change "..." --scope DPD-832 --dry-run` | Walk the flow, write no state, never write externally |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<change>` | Text, a file path, an issue key, or a JIRA comment URL | required |
| `--scope <EPIC\|KEYS>` | Epic key (expanded to children) or comma-separated keys | required unless `--jql` / `--spec` |
| `--jql "<query>"` | Search scope as a JQL result set | - |
| `--spec <url>` | Confluence spec page to diff | - |
| `--draft-only` | Produce and save everything; no external writes | off |
| `--dry-run` | No state writes and no external writes | off |

## References

| Topic | File |
|-------|------|
| Restating the change, reading the scope, impact marking, status classes | [impact-analysis.md](${CLAUDE_SKILL_DIR}/references/impact-analysis.md) |
| Drafting ticket diffs, notice comments, follow-up tickets, spec diff | [draft-updates.md](${CLAUDE_SKILL_DIR}/references/draft-updates.md) |
| Impact report template | [impact-report.md](${CLAUDE_SKILL_DIR}/references/impact-report.md) |
| Approval, apply order, backups, `applied.json` | [apply.md](${CLAUDE_SKILL_DIR}/references/apply.md) |
| Filled example | [README.md](${CLAUDE_SKILL_DIR}/README.md) |

## Resolving the plugin bundle root

Same as `ba-story-verify`: `HARNESS_PLUGIN_ROOT` = `CLAUDE_PLUGIN_ROOT` if it
contains `scripts/`, else `${CLAUDE_SKILL_DIR}/../..` (`../../..` for a mirror).
State lives in the host project under `.claude/state/ba-change/<slug>/`.

## Flow

```
[0] Probe
    getAccessibleAtlassianResources: success -> healthy, error -> unreachable,
    tools absent -> not-configured, then
      bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
    not-configured / unreachable: continue only with what is local (pasted
    change, saved state); pause before any read or write that needs JIRA.
    Re-run: load .claude/state/ba-change/<slug>/ and resume from its step.

[1] Restate                                -> references/impact-analysis.md
    Read the change (text / file / getJiraIssue for a key or comment).
    One line per changed rule / field / flow:  before -> after.
    AskUserQuestion: confirm / edit / cancel. Unknown "after" values are asked
    here, never guessed. Save change.md.

[2] Find impact                            -> references/impact-analysis.md
    Read every ticket in scope (Epic -> children via JQL "parent = KEY") and
    the spec page. Per item: impacted / maybe / not impacted + quoted text.
    >= 8 tickets -> fan out with Task (read-only, one per ticket).
    "maybe" items -> AskUserQuestion (up to 4 per round). Save impact.json.

[3] Classify                               -> references/impact-analysis.md
    Impacted ticket by status: not-started (edit) / in-progress (comment +
    assignee) / done (new follow-up). Plus test cases, UAT items, spec sections.

[4] Draft updates                          -> references/draft-updates.md
    Per ticket: AC / field diff (before/after), marked notice comment
    <!-- ba-change:notice change=<slug> key=<KEY> nonce=<uuid> -->, follow-up
    tickets in ba-ticket short format, spec diff. Flag estimate risk.

[5] Impact report                          -> references/impact-report.md
    Save report.md. --draft-only / --dry-run stop here.

[6] Approve + apply                        -> references/apply.md
    One AskUserQuestion: apply all / pick / edit / cancel.
    Back up, re-read, write (editJiraIssue, addCommentToJiraIssue,
    createJiraIssue, updateConfluencePage), log each write to applied.json.
```

## Stop conditions

| Condition | Response |
|-----------|----------|
| MCP not-configured / unreachable | Keep what is saved, say where, stop before the first JIRA read/write |
| BA does not confirm the restatement | Stop; nothing searched, nothing drafted |
| No scope given | Ask for one (Epic / keys / JQL / spec); never search the whole project |
| A ticket cannot be read | Mark it `unreadable` in the report; continue the rest |
| Target changed since read | Re-read, re-draft, re-show that item; never overwrite |
| A write fails mid-batch | Stop; report applied vs pending from `applied.json` |
| Re-run with `applied.json` present | Skip every logged write; apply only the rest |

## Report

Say: the confirmed before → after lines, counts (impacted / maybe resolved / not
impacted), the impact table, follow-up tickets drafted or created, spec sections
changed, test cases to refresh (recommend `/ba-uat --refresh`), estimate risks,
and what was applied (keys + URLs). Do not narrate per-ticket reading. End with
the next action: wait for assignees to acknowledge, or run `/ba-uat --refresh`.

## Related skills

- `ba-ticket` — format of the follow-up tickets; rewrite a ticket in full
- `ba-story-verify` — re-check an edited ticket is still clear
- `ba-uat` — refresh test cases and UAT items the change touches
- `ba-trace` — see what is already built and tested before deciding
- `harness-flow` — build the follow-up tickets
