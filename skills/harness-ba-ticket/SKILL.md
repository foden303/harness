---
name: harness-ba-ticket
description: "Write a short, clear JIRA story or Epic in the BA's voice that FE, BE, Data, AI and QA can build from without a meeting. Takes a rough idea, fills a one-screen template titled [Area] [Team] ... (Why / Scope / Acceptance criteria / Fields with required-optional rules / Edge cases / Notes per team / Open questions), asks the BA only what is missing, proposes an Epic's stories, and creates the issues in JIRA only after the operator approves. Given an existing issue key it rewrites that ticket into the short format and updates it in place on approval. Trigger: write a ticket, rewrite this ticket, shorten this ticket, BA ticket, write a story, write an epic, short ticket, lean ticket, ticket for FE/BE/QA, /harness-ba-ticket. Do NOT load for: verifying an existing ticket (use harness-story-verify / harness-epic-verify), the full 12-gate authoring flow (use harness-story-author), implementing a ticket (use harness-flow), or bug triage (use harness-bugfix)."
kind: workflow
purpose: "Rough idea -> one-screen BA-voice story/epic -> ask only the gaps -> (epic) propose stories -> operator approves -> createJiraIssue"
trigger: "write a ticket, BA ticket, write a story, write an epic, short ticket, lean ticket"
shape: delegate
role: orchestrator
pair: harness-story-verify
owner: harness-core
since: "2026-09-24"
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<idea text>|<brief-file>|<ISSUE-KEY or URL>] [--epic|--story] [--project KEY] [--epic-key KEY] [--template <path>] [--draft-only]"
user-invocable: true
effort: medium
---

# harness-ba-ticket

> **Rough idea → one-screen ticket in the BA's voice → ask only what is missing →
> operator approves → created in JIRA.**

The ticket is written **for the people who build it**. A developer or tester should
read it in two minutes and know: why it matters, what is in and out, how to tell
it is done, and what their own team has to know. Nothing more.

## Rules (read first)

1. **Short beats complete-looking.** One screen per story, one screen per epic.
   Cut any sentence that does not change what someone builds or tests.
2. **BA voice, no code.** Write what the user needs and the business rules in
   plain words. Code (API / function names, endpoints, table or column names,
   audit keys, enum numbers, file paths, call-site counts) appears **only** in
   the BE / FE lines of `Notes per team`, never in the title, Why, Scope, AC,
   Fields, Edge cases or Open questions, and never anywhere in an epic.
   Example values a user would type or see (`LAUNCH25`, `$399.00`) are fine.
3. **Ask, never invent.** A missing acceptance criterion, limit, or rule is a
   question to the BA, not a guess. No `TBD`, `???`, `etc.` in the output.
4. **Title is `[Area] [Team] ...`** for a one-team story. When several build
   teams deliver one feature that only works once all parts are done, keep one
   story titled `[Area] ...` and list the teams; split per team only when each
   part ships on its own. Epics carry `[Area]` only.
5. **Every field is spelled out.** Each input or returned value gets a row in
   `## Fields`: required or optional (or when), rules, default. "Create an
   account" is not done until the reader knows which fields it takes.
   `Notes per team` lists only the teams in `**Teams:**`.
6. **Nothing reaches JIRA without approval.** Creating an issue is an external
   write (`.claude/rules/autonomous-confirmation-scope.md` case 1).
7. **English output**, whatever language the BA writes the idea in.

## Quick Reference

| Input | Behavior |
|------|------|
| `/harness-ba-ticket "let users export the txn list to CSV"` | One story, ask the gaps, create on approval |
| `/harness-ba-ticket brief.md --epic --project DPD` | Epic + proposed stories, create on approval |
| `/harness-ba-ticket "..." --epic-key DPD-832` | Story created under an existing epic |
| `/harness-ba-ticket DPD-1573` | Rewrite an existing ticket into the short format, update it on approval |
| `/harness-ba-ticket "..." --draft-only` | Write the markdown only, never call JIRA |
| `/harness-ba-ticket "..." --template ./our-story.md` | Use the team's own template |

## References

| Topic | File |
|-------|------|
| Style, sections, ready check, asking, epic breakdown | [writing-guide.md](${CLAUDE_SKILL_DIR}/references/writing-guide.md) |
| Saving, approval, creating or updating in JIRA | [create-jira.md](${CLAUDE_SKILL_DIR}/references/create-jira.md) |
| Filled example | [README.md](${CLAUDE_SKILL_DIR}/README.md) |

## Flow

```
[1] Read the idea
    Idea text, brief file, or an existing issue key/URL (rewrite mode: read it
    with getJiraIssue; its description, parent and links are the idea). Story vs epic: flag, else infer ("epic", "several stories",
    many deliverables -> epic) and say which in one line.
    Template: --template, else <plugin root>/templates/ba-ticket/{story,epic}.md
    (plugin root = $CLAUDE_PLUGIN_ROOT, else ${CLAUDE_SKILL_DIR}/../..).
    Project: --project, else a key in the idea, else ask.

[2] Draft                                   -> references/writing-guide.md
    Fill every slot the idea answers. Mark the rest as gaps, including any field
    whose required/optional status or rules the idea does not state.

[3] Ask the gaps                            -> references/writing-guide.md (Asking)
    AskUserQuestion, up to 4 questions per round, each with ready-made options.
    Fold answers in, re-check. Stop when the "Ready check" passes or the operator
    says "leave the rest" -> remaining gaps go to ## Open questions with an owner.

[4] (Epic) Propose stories                  -> references/writing-guide.md (Epic)
    Stories table, then draft each story with the story template.
    Operator keeps / edits / drops rows.

[5] Show + approve + create                 -> references/create-jira.md
    Save the markdown to .claude/state/ba-ticket/<slug>/.
    --draft-only stops here. Otherwise show the final text and ask once:
    create all / pick stories / edit / cancel. Create only on approval.
    Rewrite mode: back up the old description, then ask update / edit / cancel;
    editJiraIssue (summary + description) only on approval.
```

## Stop conditions

| Condition | Response |
|-----------|----------|
| Atlassian MCP tools missing or failing at step 5 | Keep the saved markdown, say where it is, stop |
| Project unknown | Ask for it (offer `getVisibleJiraProjects` results); never guess |
| A create fails mid-batch | Stop; list created keys and the ones still missing |
| Rewrite mode: ticket changed in JIRA since it was read | Re-read and re-draft before updating; never overwrite unseen edits |
| Draft already has created keys (re-run) | Never re-create those; create only the missing ones |

## Report

Say: which template was used, the questions asked and the answers folded in, the
final ticket(s), and the created keys + URLs. Do not narrate slot-by-slot filling.
End with: "Created, not transitioned — move it when it is ready."

## Related skills

- `harness-story-author` — the full 12-gate authoring flow with the long template
- `harness-story-verify` / `harness-epic-verify` — check a ticket someone already wrote
- `harness-flow` — build a ticket once it is clear
