# Bootstrap Routing Contract

Last updated: 2026-07-09

## Purpose

This document defines the bootstrap routing contract for Claude Code, the one
supported host. It keeps bootstrap proof, support tier, and public support
claims separate, so a future host cannot inherit a claim it has not earned.

Golden prompts in this document are a static contract fixture. They are not
runtime auto-routing proof. Passing this contract means the repository declares
the expected routing surface; it does not prove that a model invocation will
always auto-fire the matching skill at runtime.

## False Parity Rule

False parity is forbidden.

Claude SessionStart and candidate-host bootstrap mechanisms are different.
They may point at the same conceptual workflow, but they must not be described
as equivalent runtime enforcement.

Candidate and unsupported hosts must not inherit Claude Code bootstrap
evidence. `not observed` means evidence is missing from the
current artifact set; it does not mean the capability is absent.

## Support Tier Boundary

| Host | Bootstrap tier | Bootstrap claim boundary |
|---|---|---|
| Claude Code | `supported` | SessionStart, plugin instructions, skills, hooks, and release validation may be used as support evidence. |
| Any other host | no tier | No setup docs, bootstrap route, or support claim until this repo observes its own bootstrap evidence for that host. |

## Host Bootstrap Routes

### Claude SessionStart

Claude Code uses plugin instructions, root `CLAUDE.md`, skills in `skills/`,
and SessionStart-style guidance to make workflow routing visible when a
session begins.

Expected properties:

- Natural language prompts can be paired with slash commands and skills.
- Guardrails can use runtime hooks such as PreToolUse and PostToolUse.
- Safety guidance follows the enforcement model in `docs/hardening-parity.md`:
  contract injection + post quality gate + merge gate.
- Bootstrap evidence can mention SessionStart, but it must not imply that any
  other host has the same hook surface.

### Routes for other hosts

There are none. A host without its own bootstrap evidence is not a route, is
not part of the golden prompt fixture, and must not be counted as successful
runtime routing.

Adding one back requires, for that host specifically: the observed source, the
missing proof named explicitly, and the verification command or transcript that
would advance it. Evidence that falls short produces `not observed` or
`manual` — never `supported`, and never parity with Claude's hook surface
inherited by analogy.

## Golden Prompts

These golden prompts are static contract fixture rows. They are used to check
that docs name the expected workflow for common user intent.

| Prompt fixture | Expected workflow | Claude SessionStart route |
|---|---|---|
| `Build a Todo app` / `build a todo app` | `harness-plan` | Start with planning unless an accepted plan already exists. |
| `Plan it` / `plan this` | `harness-plan` | Route to planning workflow. |
| `Implement it` / `work on this` | `harness-work` | Route to implementation workflow. |
| `implement all Plans.md tasks` | `breezing` | Route to team execution wrapper when multiple ready tasks exist. |
| `Do everything` / `breezing all` | `breezing` | Route to team execution wrapper. |
| `review this PR` | `harness-review` | Route to independent review workflow. |
| `Review it` / `review this` | `harness-review` | Route to independent review workflow. |
| `Check progress` / `sync status` | `harness-sync` | Route to sync workflow. |
| `Set up harness` / `setup harness` | `harness-setup` | Route to setup workflow. |

## Validation Requirements

The routing contract is valid only when all of the following stay true:

- Claude SessionStart is named as the bootstrap route, distinct from any
  hypothetical host route.
- Golden prompts are explicitly called a static contract fixture.
- The document says the fixture is not runtime auto-routing proof.
- Unavailable routes must produce `not observed` or `manual` evidence instead
  of being counted as successful runtime routing.
- Each core workflow listed above has at least one prompt fixture.
- No host other than Claude Code is given a tier without its own evidence.
