---
name: ba-uat
description: "Turn the acceptance criteria of one ticket, a list, an Epic (its stories), a JQL result or a spec into two test artifacts: QA test cases (TC-<KEY>-<n>, each traced to an AC row, a field rule or an edge case, with concrete test data and positive / negative / edge / permission types) and a plain-language UAT checklist for the client or business user, grouped by user flow, with Pass / Fail / Comment columns and a sign-off block. Shows a coverage table, never invents an expected result (untestable AC goes to 'Cannot test yet' with a pointer to ba-story-verify), saves both as markdown, and publishes to Confluence and/or a comment per ticket only after the operator approves. --refresh re-reads the tickets and diffs the cases after a requirement change; --csv also writes a CSV for a test tool. Trigger: write test cases, generate test cases, UAT checklist, UAT script, acceptance test, test plan from AC, QA cases for this ticket, sign-off sheet, refresh test cases, /ba-uat. Do NOT load for: checking whether a ticket is clear (use ba-story-verify), writing or rewriting the ticket (use ba-ticket), automated test code (use harness-work), or the acceptance decision on delivered work (use harness-accept)."
kind: workflow
purpose: "Ticket(s) / Epic / JQL / spec -> parse AC, Fields, Edge cases -> QA test cases + UAT checklist + coverage -> save -> operator approves -> Confluence page and/or ticket comments"
trigger: "write test cases, UAT checklist, test plan from AC, QA cases, sign-off sheet, refresh test cases"
shape: delegate
role: orchestrator
pair: ba-story-verify
owner: harness-core
since: "2026-10-26"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<ISSUE-KEY or URL> ...|<EPIC-KEY>|<spec-file>] [--jql \"...\"] [--confluence <url>] [--refresh] [--csv] [--only qa|uat] [--draft-only] [--dry-run]"
user-invocable: true
effort: high
---

# ba-uat

> **Acceptance criteria → QA test cases + a UAT checklist the business can sign
> → coverage table → operator approves → Confluence page and/or a comment on
> each ticket.**

Two readers, two artifacts. **QA** gets precise cases with concrete data they
can execute. **The client / business user** gets a checklist in plain words they
can walk through and sign. Both come from the same AC, so nothing is tested that
the ticket does not ask for, and nothing the ticket asks for goes untested.

## Rules (read first)

1. **Every case traces to the ticket.** Each test case names the AC row, Fields
   row or Edge case row it checks. No trace, no case.
2. **Never invent an expected result.** If an AC row is not testable (no clear
   outcome, a vague word, a missing number), the row goes under **Cannot test
   yet** with the reason, and the report recommends `ba-story-verify <KEY>`.
   A guessed expectation is worse than a visible gap.
3. **Concrete test data only.** Real values (`anna.tran@example.com`,
   `49,999 rows`, `2026-02-29`), never "valid data", "a long string", "etc.".
4. **Coverage minimums** (details in
   [case-rules.md](${CLAUDE_SKILL_DIR}/references/case-rules.md)):
   every AC row ≥ 1 positive case; every Fields row with rules gets boundary
   cases (min, max, just outside, empty, wrong format); every Edge & error row
   gets a negative case; permission cases when the ticket names roles.
5. **UAT checklist is business language.** No endpoints, no status codes, no
   dev tools, no "check the database". What the user does and what they see.
6. **Ask, never invent.** A missing number or rule that blocks a case becomes a
   decision-shaped question (AskUserQuestion, up to 4 per round, ready-made
   options). No `TBD`, `???` or `etc.` in the output.
7. **Read-only until approved.** Creating or updating a Confluence page and
   commenting on a ticket are external writes
   (`.claude/rules/autonomous-confirmation-scope.md` case 1): drafted, shown,
   sent only on an explicit approval. No AskUserQuestion → print the question
   and stop.
8. **English output**, whatever language the tickets are written in.

## Quick Reference

| Input | Behavior |
|------|------|
| `/ba-uat DPD-901` | Cases + checklist for one story |
| `/ba-uat DPD-901 DPD-902 DPD-905` | One set covering all three, cases numbered per ticket |
| `/ba-uat DPD-832` (an Epic) | Expands to its child stories, one checklist grouped by flow |
| `/ba-uat --jql "fixVersion = 2.4 AND type = Story"` | The JQL result set |
| `/ba-uat spec.md` | From a spec file or pasted text (keys become `SPEC-1`, `SPEC-2`, ...) |
| `/ba-uat DPD-832 --confluence https://<site>/wiki/.../123` | Publish under that parent page on approval |
| `/ba-uat DPD-832 --refresh` | Re-read tickets, show added / changed / removed cases (after `ba-change`) |
| `/ba-uat DPD-901 --csv` | Also write `test-cases.csv` for import into a test tool |
| `/ba-uat DPD-901 --only uat` | Only the UAT checklist (`--only qa` = only the test cases) |
| `/ba-uat DPD-901 --draft-only` | Save the markdown, never touch JIRA or Confluence |
| `/ba-uat DPD-901 --dry-run` | Show everything, write no state, no external calls beyond reads |

## References

| Topic | File |
|-------|------|
| Parsing tickets, testability check, case rules, coverage | [case-rules.md](${CLAUDE_SKILL_DIR}/references/case-rules.md) |
| QA test case template (filled by step 3) | [test-case-template.md](${CLAUDE_SKILL_DIR}/references/test-case-template.md) |
| UAT checklist template (filled by step 3) | [uat-template.md](${CLAUDE_SKILL_DIR}/references/uat-template.md) |
| Saving, `--refresh` diff, `--csv`, approval, publishing | [publish.md](${CLAUDE_SKILL_DIR}/references/publish.md) |
| Filled example | [README.md](${CLAUDE_SKILL_DIR}/README.md) |

## Resolving the plugin bundle root

Same as `ba-story-verify`: `HARNESS_PLUGIN_ROOT` = `CLAUDE_PLUGIN_ROOT` (if it
contains `scripts/`), else `${CLAUDE_SKILL_DIR}/../..` (or `../../..` for a
mirror). State lives under the host project's `.claude/state/ba-uat/`.

## Flow

```
[0] Resolve + probe
    getAccessibleAtlassianResources, then
      bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
      (success -> healthy, error -> unreachable, tools absent -> not-configured)
    not-configured / unreachable -> work locally from pasted text or files;
    pause before any external write (step 6) and say so.
    |
[1] Load tickets                              -> references/case-rules.md (Parsing)
    Keys / URLs -> getJiraIssue each. Epic -> its child stories
    (searchJiraIssuesUsingJql "parent = <EPIC>"). --jql -> the result set.
    Spec / pasted text -> split into SPEC-<n> items.
    Parse AC, Fields, Edge cases from the ba-ticket short format, the --full
    format, or free text. Existing state + no --refresh -> reload, do not redo.
    Report the list (n in scope / n skipped and why) before generating.
    |
[2] Testability check                         -> references/case-rules.md (Testable)
    Untestable AC rows -> "Cannot test yet" with the reason; recommend
    `/ba-story-verify <KEY>`. A missing value that blocks only a boundary case
    -> decision-shaped question (up to 4 per round), or "Cannot test yet" if
    the operator says "leave it". Never guess.
    |
[3] Generate                                  -> test-case-template.md, uat-template.md
    QA cases per ticket: TC-<KEY>-<n>, traced, typed, concrete data.
    UAT checklist: grouped by user flow, plain language, sign-off block.
    --only qa|uat -> skip the other artifact.
    Batch of >= 6 tickets -> fan out with Task (one read-only sub-agent per
    ticket returns its cases); merge and number in the lead.
    |
[4] Coverage                                  -> references/case-rules.md (Coverage)
    Per ticket: AC rows covered, fields covered, edge cases covered,
    roles covered, cannot-test count. A gap below the minimums is fixed in
    step 3 before showing, not reported as done.
    |
[5] Save                                      -> references/publish.md
    .claude/state/ba-uat/<slug>/{test-cases.md, uat-checklist.md}
    (+ test-cases.csv with --csv). --refresh -> diff vs the saved set first.
    --dry-run -> show only, write nothing. --draft-only -> stop after saving.
    |
[6] Approve + publish                         -> references/publish.md
    Show the artifacts + coverage, ask once: Confluence page / comment on each
    ticket / both / edit / cancel. Send only what was approved
    (createConfluencePage or updateConfluencePage, addCommentToJiraIssue).
    Record what was sent in published.md; a re-run never re-creates the page
    or re-posts a comment already sent.
```

## Stop conditions

| Condition | Response |
|-----------|----------|
| MCP not-configured / unreachable | Work from pasted text / files; at step 6 keep the saved files, say where they are, stop |
| A ticket cannot be read (permission, not found) | Skip it, list it in the report, continue the rest |
| Every AC row of a ticket is untestable | No cases for it; whole ticket under "Cannot test yet", recommend `ba-story-verify` |
| Input is empty after filtering (all Done, no stories under the Epic) | Report the counts per reason and stop; never widen the query |
| `--confluence` missing at publish time | Ask for the parent page URL, or offer "comments only" |
| Confluence page changed since the last publish | Re-read it, show what changed, ask before overwriting |
| A publish fails mid-batch | Stop; record what was sent in `published.md`, list what is left |

## Report

Say: the tickets in scope (and skipped, with why), the questions asked and the
answers folded in, the coverage table, the "Cannot test yet" list with the
`ba-story-verify` recommendation, the saved file paths, and what was published
(page URL, ticket keys commented). Do not narrate case-by-case generation.
End with the next action: "Hand `test-cases.md` to QA and `uat-checklist.md`
to the business tester."

## Related skills

- `ba-story-verify` — make an untestable ticket testable first
- `ba-ticket` — write the ticket the cases come from
- `ba-change` — a requirement change; follow it with `/ba-uat <KEY> --refresh`
- `ba-trace` — trace requirement → ticket → test case
- `harness-accept` — the ship / wait / reject decision after delivery
