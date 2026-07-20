# Claude Code 2.1.99-2.1.111 Impact Summary

In one line:
As the docs decision for Phase 44, we took inventory of the public changelog from `2.1.99` through `2.1.111` and classified the Harness impact into `A` and `C`, with `B` at `0`.

By analogy:
It is a note that, when a new toolbox arrives, sorts tools into "usable as-is" and "tools that need a new handle or storage built for them on our side."

## Assumptions

- The primary source is the `CHANGELOG.md` in Anthropic's public `claude-code` repository
- This document's classification is meant to map to the Phase 44 plan
- `A`: items that require explicit follow-up on the Harness side
- `C`: items you benefit from just from the Claude Code core update
- `B`: "written only" is `0` this time

## Summary

| Range | Verdict | Notes |
|------|------|------|
| `2.1.99`, `2.1.100`, `2.1.102`, `2.1.103`, `2.1.104`, `2.1.106` | `C` | No individual items in the public changelog. Nothing to add for Phase 44 |
| `2.1.101` | `C` | Mostly UX improvements and stability fixes; no Harness-specific code addition needed |
| `2.1.105` | `A` | The `PreCompact` hook and `monitors` manifest require Harness-side integration |
| `2.1.107` | `C` | Thinking-display improvement. Auto-inherited by Harness |
| `2.1.108` | `A` / `C` mixed | The 1-hour prompt cache is an explicit follow-up item; the rest is mostly auto-inherited |
| `2.1.109` | `C` | thinking indicator improvement only |
| `2.1.110` | `A` / `C` mixed | The permission re-evaluation area is an explicit follow-up item; the rest is mostly auto-inherited |
| `2.1.111` | `A` / `C` mixed | `xhigh`, `/ultrareview`, and the removal of the Auto Mode flag are formal follow-up items |

## Per-version list

| Version | Key changes | Harness impact | Class | Phase 44 trace |
|---------|----------|--------------|------|-------------------|
| `2.1.99` | No individual items in the public changelog | Confirmed only as the range's starting point. No Harness-specific work | `C` | - |
| `2.1.100` | No individual items in the public changelog | No additional follow-up | `C` | - |
| `2.1.101` | `/team-onboarding`, OS CA trust, `/ultraplan` initial-environment automation, resume stabilization, etc. | Existing workflows benefit as-is. No new code needed for Phase 44 | `C` | - |
| `2.1.102` | No individual items in the public changelog | No additional follow-up | `C` | - |
| `2.1.103` | No individual items in the public changelog | No additional follow-up | `C` | - |
| `2.1.104` | No individual items in the public changelog | No additional follow-up | `C` | - |
| `2.1.105` | `PreCompact` hook, plugin `monitors` manifest, `/proactive` alias, etc. | Requires implementation integration into `hooks.json` and the plugin manifest | `A` | `44.2.1`, `44.2.2` |
| `2.1.106` | No individual items in the public changelog | No additional follow-up | `C` | - |
| `2.1.107` | thinking indicator improvement | Auto-inherits the display improvement | `C` | - |
| `2.1.108` | `ENABLE_PROMPT_CACHING_1H`, recap, built-in slash command discovery, etc. | The 1-hour cache needs operational-policy work. The rest is largely auto-inherited | `A/C` | `44.6.1`, `44.7.1` |
| `2.1.109` | extended-thinking indicator improvement | UI benefit only. No follow-up code needed | `C` | - |
| `2.1.110` | permission deny re-evaluation fix, `PreToolUse.additionalContext` fix, `/tui`, resume/scheduled task, etc. | Requires guardrail re-verification and docs update. Other UX improvements are auto-inherited | `A/C` | `44.3.1`, `44.11.1` |
| `2.1.111` | `xhigh`, `/ultrareview`, Auto mode no longer requires flag, `/effort` slider, etc. | `xhigh` and `/ultrareview` are formal follow-up items. The Auto Mode prerequisite wording also needs updating | `A/C` | `44.5.1`, `44.8.1`, `44.11.1` |

## Key notes

### `2.1.105`

- The `PreCompact` hook ties directly into Harness's long-run protection
- The `monitors` manifest is the starting point for turning monitor scripts from "bolted on afterward" into "auto-armed at startup"
- Both create Harness added value, so they are `A`

### `2.1.108`

- `ENABLE_PROMPT_CACHING_1H` isn't just about being usable; it needs a policy for "which flows to enable it in"
- For that reason, we lean it toward `A`, which comes with docs and policy
- On the other hand, most of recap and slash command discovery are core benefits, so they are `C`

### `2.1.110`

- The `permissions.deny` re-evaluation fix directly affects Harness's guardrail explanation and expected behavior
- It's not "CC fixed it, so we're done"; we need to update Harness's explanation and test perspective, so it is a mix of `A/C`

### `2.1.111`

- `xhigh` is not deferred but a formal target
- `/ultrareview` is also not deferred but a formal target
- `Auto mode no longer requires --enable-auto-mode` is an explicit follow-up item to keep the Auto Mode docs prerequisite from staying stale

## Why B is zero

- For versions not in the public changelog, we do not force meaning onto them just to add rows
- Things that end at core improvement alone are leaned toward `C`
- Only things that affect Harness's decisions, wording, settings, or hooks are leaned toward `A`

With this split, we avoid creating "written only into the Feature Table" `B` items.

## Concrete example

Concrete example:
`2.1.111`'s `xhigh` is not just a matter of a new effort name being added. On the Harness side it affects the reviewer/advisor thinking-intensity policy and the docs explanation, so we treat it as `A`.

## Why we organized it this way

Phase 44's goal is not "to summarize the CC changelog" but to clarify "which parts Harness owns itself."
