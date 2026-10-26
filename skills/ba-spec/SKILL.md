---
name: ba-spec
description: "Write a feature spec / PRD for a large feature from a discovery brief (ba-discovery), a rough idea, or an existing Confluence page to revise. Fills a fixed template (Overview with success metrics, Users, Scope in/out/later, numbered User flows with end states and error paths, testable Business rules BR-n, Data fields with required/rules/default/source, Screens, Non-functional, Integrations, Rollout, Risks, Open questions with owners, Traceability from each brief R-n), self-checks it against a readiness checklist, asks the BA only the gaps as decision-shaped questions, and publishes to Confluence only after the operator approves (or saves .md with --draft-only). Revise mode backs up the old page and never overwrites edits made since it was read. Ends by proposing the Epic breakdown and the exact ba-ticket command. Trigger: write a spec, feature spec, PRD, product requirements, functional spec, revise this spec, spec from the brief, /ba-spec. Do NOT load for: extracting requirements from raw notes (use ba-discovery), writing a single story or epic (use ba-ticket), verifying tickets (use ba-story-verify / ba-epic-verify)."
kind: workflow
purpose: "Brief / idea / Confluence page -> draft every spec section, mark gaps -> readiness self-check -> ask only the gaps -> operator approves -> create / update the Confluence page -> propose epics -> ba-ticket command"
trigger: "write a spec, feature spec, PRD, product requirements, functional spec, revise this spec"
shape: delegate
role: orchestrator
base: ba-discovery
pair: ba-ticket
owner: harness-core
since: "2026-10-26"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<brief-file>|<idea text>] [--confluence <space or parent url>] [--page <url>] [--draft-only] [--dry-run]"
user-invocable: true
effort: high
---

# ba-spec

> **Discovery brief or idea → one feature spec every team can build from →
> gaps asked, not guessed → operator approves → Confluence → Epic breakdown.**

The spec is the agreement for a feature too big for one ticket: the rules, the
flows, the data and the limits that FE, BE, Data, AI and QA must share before
anyone writes a story. `ba-ticket` turns it into epics and stories afterwards.

## Rules (read first)

1. **Ask, never invent.** A missing rule, number, field rule or decision becomes
   a decision-shaped question with ready-made options. No `TBD`, `???` or
   `etc.` in the output; what the BA cannot settle goes to Open questions with
   an owner.
2. **Every business rule is testable.** `BR-n` names a condition and an
   outcome a tester can check Yes/No, with a number or a role where it matters.
3. **Every flow ends.** Each flow has numbered steps, an end state, and at least
   one error path.
4. **Every brief requirement is accounted for.** Each `R-n` from the brief is
   traced to a BR / flow / section, or explicitly dropped with a reason.
5. **BA voice, no code.** Business terms, not API, table or column names.
   Field names are the names users see.
6. **Read-only until approved.** Creating or updating a Confluence page is an
   external write (`.claude/rules/autonomous-confirmation-scope.md` case 1),
   sent only after an explicit `AskUserQuestion` approval. If
   `AskUserQuestion` is unavailable, print the question and stop.
7. **Never overwrite unseen edits.** Revise mode backs up the page body
   locally first and re-reads it right before writing.
8. **English output**, whatever language the input is in.

## Quick Reference

| Input | Behavior |
|------|------|
| `/ba-spec .claude/state/ba-discovery/<slug>/brief.md` | Spec from a brief, saved locally, publish target asked |
| `/ba-spec brief.md --confluence https://<site>/wiki/spaces/DPD` | Publish as a new page in that space (on approval) |
| `/ba-spec brief.md --confluence https://<site>/wiki/.../pages/456` | Publish under that parent page (on approval) |
| `/ba-spec "self-serve transaction reporting for finance"` | Spec from an idea; expect more questions |
| `/ba-spec --page https://<site>/wiki/.../pages/789` | Revise an existing spec page in place (on approval) |
| `/ba-spec brief.md --draft-only` | Save the `.md` spec, never touch Confluence |
| `/ba-spec brief.md --dry-run` | Walk the flow, write no state, never touch Confluence |

## References

| Topic | File |
|-------|------|
| Loading input, drafting, asking, Epic breakdown | [drafting.md](${CLAUDE_SKILL_DIR}/references/drafting.md) |
| The spec the skill fills | [spec-template.md](${CLAUDE_SKILL_DIR}/references/spec-template.md) |
| Readiness checklist (step 3) | [readiness.md](${CLAUDE_SKILL_DIR}/references/readiness.md) |
| Saving, approval, create / update in Confluence, revise mode | [publish.md](${CLAUDE_SKILL_DIR}/references/publish.md) |
| Quick start and a filled example | [README.md](${CLAUDE_SKILL_DIR}/README.md) |

## Flow

```
[0] Resolve + probe
    HARNESS_PLUGIN_ROOT: CLAUDE_PLUGIN_ROOT if it contains scripts/, else
    ${CLAUDE_SKILL_DIR}/../.. (or ../../.. for a mirror).
    Probe once with getAccessibleAtlassianResources, then
      bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
      (success -> healthy, error -> unreachable, tools absent -> not-configured)
    not-configured / unreachable: --page cannot be read -> ask for a paste of
    the page body; otherwise work locally and pause before any external write.
    Skip the probe when there is no --page and --draft-only or --dry-run is set.

[1] Load input                              -> references/drafting.md (Input)
    Brief file (R-n rows, rules, decisions), idea text, or --page (revise:
    getConfluencePage, save the body + version to original.md first).
    Re-run: load .claude/state/ba-spec/<slug>/ and continue from there.

[2] Draft                                   -> references/spec-template.md
    Fill every section the input answers. Mark the rest as gaps. Carry each
    R-n into Traceability. Number BR-n, flows F-n, open questions Q-n.

[3] Self-check                              -> references/readiness.md
    Run every check. Each failure becomes a gap with the section it blocks.

[4] Ask the gaps                            -> references/drafting.md (Asking)
    AskUserQuestion, up to 4 per round, 2-4 ready-made options each.
    Fold answers in, re-run step 3. Stop when it passes or the operator says
    "leave the rest" -> Open questions with owners. Never guess.

[5] Show + approve + publish                -> references/publish.md
    Save .claude/state/ba-spec/<slug>/spec.md (not with --dry-run).
    --draft-only / --dry-run stop here. Otherwise show the page and ask once:
    publish / edit / cancel. createConfluencePage, or updateConfluencePage in
    revise mode after re-reading the version. Write only on approval.

[6] Epic breakdown + hand-off               -> references/drafting.md (Epics)
    Propose epics (each a user-visible slice, with the BR / F it covers).
    Give the exact ba-ticket <spec path or url> --epic command per epic.
```

## Stop conditions

| Condition | Response |
|-----------|----------|
| No input (no brief, idea or page) | Ask for one; never draft from nothing |
| `--page` given but MCP not-configured / unreachable | Ask for a paste of the body; revise mode cannot publish until the probe is healthy |
| Publish target unknown at step 5 | Ask for a space or parent URL (offer `getConfluenceSpaces`); never guess |
| Page changed since it was read (revise) | Stop, show what changed, re-read and re-draft; never overwrite |
| Re-run finds `published.md` with a page URL | Never create a second page; switch to revise mode on that page |
| Create / update fails | Keep the saved spec, report the error, record nothing as published |
| Operator cancels | Keep the saved spec, give its path, stop |

## Report

Say: the input used, the readiness result (passed / which checks were left
open), the questions asked and the answers folded in, the spec path, the page
URL if published (and the backup path in revise mode), the proposed epics, and
the exact `ba-ticket` command(s). Do not narrate section-by-section filling.

## Related skills

- `ba-discovery` — build the brief this skill reads, from raw notes
- `ba-ticket` — turn each proposed epic into an epic + stories in JIRA
- `ba-epic-verify` — check an epic once it is written
