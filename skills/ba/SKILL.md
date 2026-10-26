---
name: ba
description: "Single entry point for the BA (business analyst) skill pack. Reads what the BA has in hand — meeting notes, an idea, a ticket key, an Epic, a change request, a sprint — and routes to the one ba-* skill that handles it, with the exact command. Does no work of its own and writes nothing. Trigger: ba, business analyst, I am a BA, which BA skill, help me with requirements, what should I run, /ba. Do NOT load for: a request that already names a specific ba-* skill (run that skill directly), implementing a ticket (use harness-flow), bug triage (use harness-bugfix), code review, or release."
kind: workflow
purpose: "Classify what the BA has in hand -> route to the one ba-* skill that handles it -> hand over the exact command"
trigger: "ba, business analyst, which BA skill, help me with requirements, what should I run"
shape: wrap
role: orchestrator
base: ba-ticket
pair: ba-story-verify
owner: harness-core
since: "2026-10-26"
allowed-tools: ["Read", "Glob", "Grep", "Skill", "AskUserQuestion"]
argument-hint: "[<what you have: notes file, idea, ISSUE-KEY, EPIC-KEY, change request, sprint>]"
user-invocable: true
effort: low
---

# ba

> **What do you have in hand → the one BA skill that handles it → the exact
> command.** This skill only routes. Every write to JIRA or Confluence happens
> inside the target skill, behind that skill's own approval gate.

## Rules (read first)

1. **Route, don't do.** Never draft a ticket, verify, or analyse here. Pick the
   target skill and start it with the Skill tool, passing the BA's input through
   unchanged.
2. **One question at most.** When the input fits two rows of the table below,
   ask once with `AskUserQuestion` (offer the two candidates). Otherwise pick and
   say which in one line.
3. **No input → show the menu.** With no argument, print the routing table as a
   short menu and ask what the BA has in hand.
4. **Never route to engineering skills silently.** A request to *build* a ticket
   goes to `harness-flow`, a bug to `harness-bugfix` — say so and stop; they are
   outside the BA pack.

## Routing table

| The BA has… | Route to | Command |
|---|---|---|
| Meeting notes, a call transcript, client emails | `ba-discovery` | `/ba-discovery <file\|folder\|"pasted text">` |
| A discovery brief for a large feature that needs a spec / PRD | `ba-spec` | `/ba-spec <brief.md\|idea>` |
| An idea for one story or an Epic | `ba-ticket` | `/ba-ticket "<idea>"` (add `--epic`, or `--full` for the 13-gate template) |
| A long, messy ticket to shorten | `ba-ticket` | `/ba-ticket <ISSUE-KEY>` |
| A written story (or list) to check before refinement | `ba-story-verify` | `/ba-story-verify <KEY ...>` |
| A written Epic to check before splitting it | `ba-epic-verify` | `/ba-epic-verify <EPIC-KEY>` |
| A whole backlog / sprint to tidy before planning | `ba-backlog` | `/ba-backlog --sprint next` or `--project KEY` |
| "The client changed X" | `ba-change` | `/ba-change "<change>" --scope <EPIC-KEY>` |
| Tickets that need QA test cases or a client UAT checklist | `ba-uat` | `/ba-uat <KEY\|EPIC-KEY>` |
| "Is requirement X built yet?" / coverage of an Epic | `ba-trace` | `/ba-trace <EPIC-KEY>` |
| A finished sprint or release to announce | `ba-release-notes` | `/ba-release-notes --sprint "<name>"` |

## How to tell which row

- A JIRA key: this skill does not read JIRA. Infer the type and intent from the
  BA's words; if they don't say, ask. Epic → `ba-epic-verify`; story the BA
  wants *checked* → `ba-story-verify`; story the BA wants *rewritten* →
  `ba-ticket <KEY>`. (The verify skills route a wrong type to each other anyway.)
- Words like "changed", "now they want", "instead of" → `ba-change`.
- Words like "test", "UAT", "acceptance test", "sign-off" → `ba-uat`.
- A file of notes or a transcript → `ba-discovery`, even if it mentions tickets.

## The pack, end to end

```
notes ──► ba-discovery ──► ba-spec (large) ──► ba-ticket ──► ba-story-verify / ba-epic-verify
                                                                │
                  ba-change ◄── client changes a requirement      ▼
                                                          harness-flow (engineering builds)
                                                                │
                  ba-release-notes ◄── ba-trace ◄── ba-uat ◄─────┘
            ba-backlog: run any time before refinement / sprint planning
```

## Report

One line: the chosen skill and why, then start it. If you asked a question,
start the chosen skill as soon as it is answered.

## Related skills

All `ba-*` skills above; `harness-flow` builds a ticket once it is clear.
