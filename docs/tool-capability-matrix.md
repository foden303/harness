# Tool Capability Matrix

Last updated: 2026-07-09

## Purpose

This document defines the host capability contract. It is a contract document,
not a marketing support matrix.

The current support-tier scope is:

| Host | Support tier | Claim boundary |
|---|---|---|
| Claude Code | `supported` | Public Claude-first support is allowed for the verified Claude Code path. |

Harness supports exactly one host. Adapters for other CLIs were carried as
`candidate` / `future/unsupported` entries before v1.0.0 and removed with the
research that backed them; no other host carries a claim of any tier, and
naming one here without bootstrap, trigger, runtime, and release evidence
would recreate the false parity this document exists to forbid.

`not_observed != absent`. Missing local runtime evidence is `not observed`
until the relevant source of truth is checked. It is not a license to promote a
host to supported.

## False Parity Rule

False parity is forbidden.

The same capability name does not mean the same enforcement strength. Claude
Code can stop some actions at runtime through hooks. A host that lacks that
surface does not inherit the safety or bootstrap claims of one that has it,
however similar the capability label looks.

## Capability Status

| Capability | Core meaning | Claude Code |
|---|---|---|
| `skill_loading` | Host can discover and load workflow skills. | Supported through the Claude plugin `skills/` surface. |
| `bootstrap_notice` | Host can load startup guidance or prove the guidance surface exists. | Supported through Claude SessionStart guidance, plugin instructions, and root `CLAUDE.md`. |
| `prompt_routing` | Host can map user intent to a workflow. | Supported through slash commands, skill triggers, and SessionStart guidance. |
| `pre_use_guard` | Host can block risky actions before execution. | Supported through PreToolUse / permission boundaries. |
| `post_use_gate` | Host can inspect outputs after execution. | Supported through PostToolUse and review workflow checks. |
| `review_artifact` | Host can produce structured review evidence. | Supported through harness-review and Claude-side review artifacts. |
| `memory_bridge` | Host can use a controlled memory surface. | Supported when Agent Memory / harness-mem wiring is configured. |

## Validation Requirements

The matrix is valid only when all of the following stay true:

- All required capability names are present exactly as code-formatted labels.
- Claude Code is `supported`.
- No other host is given a support tier without its own evidence.
- Any public support wording preserves the false parity rule.
