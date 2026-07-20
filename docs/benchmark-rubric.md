# Benchmark Rubric

Last updated: 2026-03-06

This document is a rerunnable rubric for comparing `harness` against other tools.
Rather than scoring by README impressions, it scores static evidence and executed evidence separately.

## Evidence Classes

| Class | Example | When to use |
|------|----|-----------|
| Static evidence | README, repo tree, hook definitions, tests, docs, package metadata | Comparing whether mechanisms exist, design clarity, and distribution flow |
| Executed evidence | test run, smoke run, benchmark logs, evidence pack, CI artifact | Comparing whether claims are reproducible and whether guardrails actually take effect |

## Scoring Axes

| Axis | Weight | What to inspect |
|------|--------|-----------------|
| Runtime enforcement | 25 | Hooks, guardrails, deny/warn behavior, lifecycle automation |
| Verification and test credibility | 25 | Unit/integration tests, consistency checks, evidence pack, CI coverage |
| Onboarding and operator clarity | 20 | install flow, docs completeness, claim consistency, quickstart quality |
| Scope discipline and maintainability | 15 | distribution boundary, compatibility story, residue management |
| Positioning and adoption proof | 15 | public narrative, stars/users, reproducible showcase, differentiation |

Total: 100 points

## Review Flow

1. Gather static evidence
2. List the claims that require executed evidence
3. Separate claims you could execute from claims that remain pending
4. Score each axis and note the evidence type
5. Write strengths and weaknesses separately, e.g. "strong design but unproven" or "strong market presence but thin runtime enforcement"

## Required Output Format

A comparison report must include at least the following.

- Comparison date and time
- Target repositories / versions / commit or default branch snapshot
- List of commands executed
- Distinction between static evidence and executed evidence
- Score per axis
- Items that could not be fully reproduced

## Reusable Template

```md
# Benchmark Report

- Compared at:
- Repositories / versions:
- Commands executed:

## Static evidence

- Repo structure:
- Docs and claims:
- Guardrails / hooks / tests:

## Executed evidence

- Validation commands:
- Benchmark or smoke runs:
- Evidence artifacts:

## Scores

| Axis | Score | Evidence type | Notes |
|------|-------|---------------|-------|
| Runtime enforcement |  | Static / Executed |  |
| Verification and test credibility |  | Static / Executed |  |
| Onboarding and operator clarity |  | Static / Executed |  |
| Scope discipline and maintainability |  | Static / Executed |  |
| Positioning and adoption proof |  | Static / Executed |  |

## Unverified or blocked items

- None

## Harness-specific Notes

- Strong claims like `/harness-work all` should only score highly once the executed evidence in `docs/evidence/work-all.md` is in place
- Leftover items such as `commands/` or `mcp-server/` are not a deduction in themselves; **deduct only when their explanation is ambiguous**
- Lower `Onboarding and operator clarity` when the README claims do not line up with the tests / CI / distribution boundary
