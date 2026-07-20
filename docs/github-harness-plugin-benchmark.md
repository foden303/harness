# GitHub Harness Plugin Benchmark

Last updated: 2026-03-06

This document is a dated snapshot comparing popular **harness / workflow plugins for Claude Code** on GitHub, from the perspective of **how standard operation changes after introducing** `harness`.

- This is a **harness comparison**, not a **popularity vote**
- GitHub stars are treated only as the **reason for selecting the comparison targets**
- We first line up "what becomes standard after adoption," then explain what the differences mean
- General AI coding agents (Aider, OpenHands, etc.) and curated lists are excluded from this comparison table because they are **not standalone harnesses**

## Compared Repositories

As of 2026-03-06, we targeted the repos that are public on GitHub, claim to be a "multi-stage workflow / plugin / harness for Claude Code," and have enough public information for a comparison.

| Repo | GitHub stars | Included because |
|------|--------------|------------------|
| [obra/superpowers](https://github.com/obra/superpowers) | 71,993 | The most popular workflow / skills plugin. Cannot be left out as a comparison target |
| [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd) | 2,770 | A popular Claude Code harness that foregrounds a requirements-driven development flow |
| [foden303/harness](https://github.com/foden303/harness) | 232 | This repo |

## User-visible comparison table

Legend:

- `✅` Usable as a standard flow right after adoption
- `△` Possible with effort, but not the primary path
- `—` Not a main selling point

| What users care about | Claude Harness | Superpowers | cc-sdd |
|------------------------|----------------|-------------|--------|
| Plans stay in the repository instead of vanishing in conversation | ✅ | ✅ | ✅ |
| Implementation proceeds smoothly in the same flow after approval | ✅ | ✅ | △ |
| Review is part of the standard process before completion | ✅ | ✅ | △ |
| Dangerous operations are stopped by a runtime guard | ✅ | △ | — |
| Verification can be redone later with the same procedure | ✅ | △ | ✅ |
| After approval, it can run end-to-end to the finish | ✅ | △ | — |

## What these differences mean

### Claude Harness

- Its strongest points are **fixing a standard flow**, **runtime guards**, and **re-runnable verification**
- Plan → Work → Review are lined up as independent paths, and there is even a one-shot shortcut, `/harness-work all`
- It suits people who want "the same shape every time, without falling apart," rather than "just do it nicely each time"

### Superpowers

- Its strongest points are the **breadth of workflows** and the **clarity of the onboarding story**
- The flow from planning to implementation, review, and debugging is easy to see, and its auto-triggers are strong
- However, a mechanism that stops dangerous operations with runtime rules, and re-runnable evidence, are not foregrounded as a standard flow to the extent they are in Harness

### cc-sdd

- Its strongest point is **spec-driven discipline**
- The `Requirements -> Design -> Tasks -> Implementation` flow is clear, and it also has dry-run and validate-gap / validate-design
- However, from its public face, an independent review process and a one-shot execution path do not look as strongly like a standard flow as they do in Harness

## How to present it in the README

For the README or landing page, phrasing like the following is natural.

> If you want to widen your workflow toolkit, Superpowers.
> If you want to strengthen the requirements → design → tasks discipline, cc-sdd.
> If you want to turn planning, implementation, review, and verification into a resilient standard flow, Claude Harness.

## Judgment notes

- `Plans stay in the repository instead of vanishing in conversation`
  - Harness: `Plans.md` / `/harness-plan`
  - Superpowers: brainstorming / writing-plans workflow
  - cc-sdd: requirements / design / tasks workflow
- `Implementation proceeds smoothly in the same flow after approval`
  - Harness: `/harness-work --parallel`, Breezing, and worker/reviewer flows are on the standard flow
  - Superpowers: parallel agent execution / subagent workflows are easy to see on the public face
  - cc-sdd: the Claude agent variant shows multiple subagents, but they are not presented as a central feature in every usage
- `Review is part of the standard process before completion`
  - Harness: `/harness-review` and `/harness-work all`
  - Superpowers: code review workflow is explicit
  - cc-sdd: validate commands are explicit, but the degree to which code review is foregrounded as an independent process is somewhat weaker
- `Dangerous operations are stopped by a runtime guard`
  - Harness: TypeScript guardrail engine + deny / warn rules
  - Superpowers: workflow discipline and hooks are visible, but compiled deny / warn runtime engine is not front-and-center
  - cc-sdd: in the public README, an explicit runtime safety engine is hard to confirm
- `Verification can be redone later with the same procedure`
  - Harness: validate scripts + consistency checks + evidence pack
  - Superpowers: there are verify-oriented workflows, but an artifact pack is not foregrounded
  - cc-sdd: has dry-run / validate-gap / validate-design
- `After approval, it can run end-to-end to the finish`
  - Harness: `/harness-work all`
  - Superpowers: there are auto-triggered workflows, but a published single command in the same sense is not foregrounded
  - cc-sdd: there is a spec-based command set, but a single path that bundles the full loop after approval is not foregrounded

## Caveats

- Because stars change every day, this table is a **dated snapshot**
- This comparison leans toward "user-visible harness feature differences," not "market popularity"
- There are axes where `Superpowers > Claude Harness`. In particular, the strength of its ecosystem / adoption / workflow story stands out
- There are axes where `cc-sdd > Claude Harness`. In particular, the clarity of its requirements-driven discipline is a strength
- When putting this in the README, it is more natural to write **who it suits depending on what they value** than to assert wins and losses

## Evidence Used

### Local evidence

- [README.md](../README.md)
- [docs/claims-audit.md](claims-audit.md)
- [docs/distribution-scope.md](distribution-scope.md)
- [docs/evidence/work-all.md](evidence/work-all.md)

### Public GitHub sources

- [obra/superpowers](https://github.com/obra/superpowers)
- [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd)
- [foden303/harness](https://github.com/foden303/harness)
