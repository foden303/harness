---
name: ba-discovery
description: "Turn raw discovery material (meeting notes, a call transcript, client emails, a folder of them, or a Confluence page) into a discovery brief the BA can act on. Lists every source it read, extracts stakeholders, goals, problems, business rules, constraints, decisions, assumptions and out-of-scope mentions, writes each requirement as a one-line need traced to a source quote + speaker + file/line, classifies it (functional / non-functional / rule / question), flags conflicts between sources and vague words, asks the BA only the gaps as decision-shaped questions, renders the brief, and recommends the exact next command (ba-spec for a large feature, else ba-ticket). Publishes the brief to Confluence only after the operator approves. Trigger: discovery brief, summarize these meeting notes, extract requirements, requirements from transcript, client emails to requirements, what did the client ask for, discovery notes, /ba-discovery. Do NOT load for: writing a PRD / feature spec (use ba-spec), writing a JIRA ticket (use ba-ticket), verifying an existing ticket (use ba-story-verify / ba-epic-verify)."
kind: workflow
purpose: "Notes / transcript / emails -> extract + trace every requirement to a quote -> classify, flag conflicts and vague words -> ask only the gaps -> discovery brief -> operator approves -> (optional) publish to Confluence -> next command"
trigger: "discovery brief, extract requirements, meeting notes to requirements, requirements from transcript, client emails"
shape: delegate
role: orchestrator
pair: ba-spec
owner: harness-core
since: "2026-10-26"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<pasted text>|<file>|<directory>|<confluence page url> ...] [--project KEY] [--confluence <parent page url>] [--draft-only] [--dry-run]"
user-invocable: true
effort: high
---

# ba-discovery

> **Raw notes, transcripts, emails → every requirement traced to a quote →
> conflicts and gaps asked → one discovery brief → the exact next command.**

The brief is the BA's single page of truth after discovery: who asked for what,
in their own words, what is decided, what is still open, and who owns each open
point. It is the input `ba-spec` and `ba-ticket` read next.

## Rules (read first)

1. **Every requirement traces to a quote.** Each `R-n` row carries the verbatim
   source quote, the speaker, and the source file + line (or page + paragraph).
   A need with no source is **not** a requirement; it becomes an open question.
2. **Ask, never invent.** A missing rule, number, priority or decision becomes a
   decision-shaped question with ready-made options, never a guess. No `TBD`,
   `???` or `etc.` in the output.
3. **Conflicts are surfaced, not resolved silently.** When source A says X and
   source B says Y, both quotes go into `## Conflicts` and the BA decides.
4. **Vague words are flagged.** "fast", "easy", "simple", "secure", "etc.",
   "and so on", "user-friendly", "real-time" without a number: each one is a
   question asking for the measurable meaning.
5. **Read-only until approved.** Reading a Confluence page is fine; publishing
   the brief is an external write (`.claude/rules/autonomous-confirmation-scope.md`
   case 1) and happens only after an explicit `AskUserQuestion` approval. If
   `AskUserQuestion` is unavailable, print the question and stop.
6. **English output**, whatever language the sources are in. Quotes stay in the
   original language, with an English gloss in brackets when not English.

## Quick Reference

| Input | Behavior |
|------|------|
| `/ba-discovery notes-2026-10-20.md` | One file → brief, saved locally |
| `/ba-discovery ./discovery/` | Every `.md` / `.txt` / `.eml` / `.vtt` / `.srt` file in the folder |
| `/ba-discovery "<pasted transcript>"` | Pasted text, cited as `pasted:L<n>` |
| `/ba-discovery https://<site>/wiki/.../pages/123` | Read a Confluence page as a source |
| `/ba-discovery ./discovery/ --project DPD` | Project key used in the next-step command |
| `/ba-discovery ./discovery/ --confluence https://<site>/wiki/.../pages/456` | Offer to publish the brief under that parent page |
| `/ba-discovery ./discovery/ --draft-only` | Save the brief, never touch Confluence |
| `/ba-discovery ./discovery/ --dry-run` | Walk the flow, write no state, never touch Confluence |

## References

| Topic | File |
|-------|------|
| Ingest, extract, classify, conflicts, vague words, asking | [extraction.md](${CLAUDE_SKILL_DIR}/references/extraction.md) |
| The brief the skill fills | [brief-template.md](${CLAUDE_SKILL_DIR}/references/brief-template.md) |
| Saving, re-runs, next-step choice, Confluence publish | [publish.md](${CLAUDE_SKILL_DIR}/references/publish.md) |
| Quick start and a filled example | [README.md](${CLAUDE_SKILL_DIR}/README.md) |

## Flow

```
[0] Resolve + probe
    HARNESS_PLUGIN_ROOT: CLAUDE_PLUGIN_ROOT if it contains scripts/, else
    ${CLAUDE_SKILL_DIR}/../.. (or ../../.. for a mirror).
    Probe once with getAccessibleAtlassianResources, then
      bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
      (success -> healthy, error -> unreachable, tools absent -> not-configured)
    not-configured / unreachable: work from local files and pasted text; a
    Confluence URL source is reported as unread (ask for a paste); pause
    before any external write.
    Skip the probe when there is no Confluence URL source and --draft-only or
    --dry-run is set.

[1] Ingest                                  -> references/extraction.md (Ingest)
    One or many sources. Number every line. Print the source list
    (file | kind | lines | read / skipped + why) BEFORE extracting.
    Re-run: load .claude/state/ba-discovery/<slug>/ and continue from there.

[2] Extract                                 -> references/extraction.md (Extract)
    Stakeholders/roles, goals, problems, requirements (one-line need + quote +
    speaker + source:line), business rules, constraints, decisions,
    assumptions, out-of-scope mentions.
    Large input (>= 6 files or > 3,000 lines): fan out with Task, one read-only
    sub-agent per file, then merge and dedupe.

[3] Classify + check                        -> references/extraction.md (Classify)
    Type each R-n: functional / non-functional / rule / question.
    Flag conflicts between sources and vague words. Note missing priority.

[4] Ask the gaps                            -> references/extraction.md (Asking)
    AskUserQuestion, up to 4 per round, each with 2-4 ready-made options.
    Order: conflicts -> vague words -> missing priority -> other gaps.
    "Leave it" -> Open questions with an owner. Never guess.

[5] Render the brief                        -> references/brief-template.md
    Save to .claude/state/ba-discovery/<slug>/brief.md (not with --dry-run).

[6] Next step + optional publish            -> references/publish.md
    Recommend ba-spec (large feature / needs a PRD) or ba-ticket (story or
    epic) with the exact command. If --confluence is set and not
    --draft-only: show the page, ask publish / edit / skip, create only on
    approval.
```

## Stop conditions

| Condition | Response |
|-----------|----------|
| No readable source | List what was tried and why it failed; stop |
| Confluence source but MCP not-configured / unreachable | Mark it unread, ask for a paste or a file, continue with the rest |
| Every candidate requirement lacks a source quote | Do not render requirements; put them all in Open questions and say so |
| Operator declines to publish | Keep the saved brief, give its path, stop |
| Publish fails | Keep the saved brief, report the error, record nothing as published |
| Re-run finds `published.md` with a page URL | Never create a second page; offer to update that page (re-read first) |

## Report

Say: the sources read (and skipped), counts (requirements by type, conflicts,
vague words, open questions), the questions asked and the answers folded in,
the brief path, the published page URL if any, and the exact next command. Do
not narrate line-by-line extraction.

## Related skills

- `ba-spec` — turn the brief into a feature spec / PRD for a large feature
- `ba-ticket` — turn the brief into a story or epic for a small feature
- `ba-story-verify` / `ba-epic-verify` — check tickets someone already wrote
