# ba-discovery

Turn **meeting notes, call transcripts and client emails** into a **discovery
brief**: every requirement written as a one-line need and traced to the exact
quote, speaker and line it came from, with conflicts and vague words surfaced
and only the real gaps asked.

## Quick start

```bash
# One file
/ba-discovery discovery/kickoff-call.vtt --project DPD

# A whole folder of notes, transcripts and emails
/ba-discovery ./discovery/ --project DPD

# A Confluence page as a source
/ba-discovery https://<site>/wiki/spaces/DPD/pages/123456

# Also offer to publish the brief under a parent page (asks first)
/ba-discovery ./discovery/ --confluence https://<site>/wiki/spaces/DPD/pages/456789

# Save the brief only, never touch Confluence
/ba-discovery ./discovery/ --draft-only
```

The skill lists what it read, asks you only the conflicts, vague words and
missing priorities (pick an option or type your own), saves the brief to
`.claude/state/ba-discovery/<slug>/brief.md`, and ends with the exact next
command: `ba-spec` for a large feature, `ba-ticket` for a small one.

A requirement nobody actually said is never written as one: it becomes an open
question.

## What a brief looks like

Sources: `kickoff-call.vtt` (Lan, Head of Finance; Minh, Support lead) and one
follow-up email from Minh.

```markdown
# Discovery brief: Self-serve transaction reporting

**Project:** DPD · **Sources:** 2 read, 0 skipped · **Date:** 2026-10-26 · **Prepared by:** ba-discovery

## Summary
Finance asks Support for transaction reports about 40 times a month and waits up
to 2 days. They want to export the filtered transaction list themselves. Export
permissions were contested (Finance only vs Finance + Support) and are now
settled: Finance + Support. Excel output is deferred.

## Sources

| # | Source | Kind | Lines | Status |
| --- | --- | --- | --- | --- |
| 1 | discovery/kickoff-call.vtt | transcript | 412 | read |
| 2 | discovery/email-2026-10-21.eml | email | 38 | read |

## Stakeholders

| Name / role | Cares about | Decides |
| --- | --- | --- |
| Lan, Head of Finance | Month-end reconciliation | Scope, priority |
| Minh, Support lead | Fewer manual report requests | Support access |

## Goals
- Finance pulls its own reports without Support — kickoff-call.vtt:L41

## Problems today
- About 40 report requests a month, up to 2 days wait — kickoff-call.vtt:L35

## Requirements

| ID | Need | Type | Source quote | Who · where | Priority |
| --- | --- | --- | --- | --- | --- |
| R-1 | A finance user can export the filtered transaction list to CSV | functional | "I just want to download what I'm looking at, as a CSV" | Lan · kickoff-call.vtt:L52 | Must |
| R-2 | The export keeps the list's sort order | functional | "same order as on screen, otherwise it's useless for us" | Lan · kickoff-call.vtt:L60 | Should |
| R-3 | An export of up to one month of data finishes in under 30 s | non-functional | "it has to be fast" + BA answer, 2026-10-26 | Lan · kickoff-call.vtt:L88 | Must |
| R-4 | Every export is recorded with who, when and which filters | rule | "audit will ask who pulled what" | Lan · kickoff-call.vtt:L131 | Must |

## Business rules
- **BR-1** Only Finance and Support roles can export — R-1, email-2026-10-21.eml:L14, BA answer 2026-10-26
- **BR-2** One export is at most 50,000 rows — R-1, kickoff-call.vtt:L97

## Constraints
- Must ship before the January audit — kickoff-call.vtt:L140

## Decisions

| # | Decision | Decided by | Source |
| --- | --- | --- | --- |
| D-1 | CSV first; Excel later | Lan | kickoff-call.vtt:L71 |
| D-2 | Support can export too | BA (with Lan) | BA answer, 2026-10-26 |

## Assumptions (to confirm)

| # | Assumption | Confirm with | Source |
| --- | --- | --- | --- |
| A-1 | Export uses the same filters as the list screen | Lan | kickoff-call.vtt:L55 |

## Conflicts

| # | Topic | A says | B says | Resolution |
| --- | --- | --- | --- | --- |
| C-1 | Who can export | "Finance only, nobody else needs it" (Lan, kickoff-call.vtt:L102) | "Support needs this too for disputes" (Minh, email-2026-10-21.eml:L14) | Finance + Support (BA answer, 2026-10-26) |

## Open questions

| # | Question | Owner | Blocks |
| --- | --- | --- | --- |
| Q-1 | How long must export records be kept? (a) 1 year (b) 5 years (c) same as transactions | Lan | BR for R-4 |

## Out of scope
- Excel export — next quarter, kickoff-call.vtt:L71
- Scheduled / emailed exports — not planned, kickoff-call.vtt:L77

## Suggested next step
One screen, 4 requirements, rules settled except retention: an epic with a few stories.

`/ba-ticket .claude/state/ba-discovery/dpd-self-serve-reporting/brief.md --epic --project DPD`
```

## Why every row has a quote

The brief is what the spec and the tickets are built from. When a developer or
QA asks "who said this?", the answer is one click away, and when two people
said different things the brief shows both instead of silently picking one.
