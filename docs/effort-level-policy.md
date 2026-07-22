# Effort Level Policy

## Overview

Defines the mapping between the CC frontmatter `effort` field and the Anthropic API effort parameter, along with Harness's adoption policy.

## CC Frontmatter to API Effort Mapping Matrix

CC v2.1.72 removed `max`, and v2.1.111 added `xhigh`.

| CC frontmatter `effort` value | Effective API effort | Behavior on Opus 4.8 | Behavior on non-Opus 4.8 |
|----------------------------|------------------|-------------------|---------------------|
| `low` | low | low (stays in scope, no deep dive) | low |
| `medium` | medium | medium | medium |
| `high` | high | high | high |
| `xhigh` | xhigh | xhigh (highest effort tier) | falls back to `high` (noted in changelog) |

**Notes**:
- `xhigh` was added to the frontmatter in CC v2.1.111 (see `CLAUDE-feature-table.md`)
- `max` was removed in CC v2.1.72. Writing it in the frontmatter has no effect
- If `xhigh` is specified on a model other than Opus 4.8 (such as the Sonnet family), CC automatically downgrades it to `high`

### The Opus 4.8 thinking model (important)

On Opus 4.8, **thinking is off by default**. Adaptive thinking only kicks in when `thinking: {type: "adaptive"}` is set explicitly,
automatically adjusting the amount of thinking based on effort and query complexity. The `budget_tokens`-style extended thinking is deprecated.
The CC frontmatter `effort` remains in effect, and on Opus 4.8 it is the **primary lever** for reasoning depth (effort has more impact than on any previous Opus).

For this reason, when Harness wants deeper reasoning it controls it via the `effort` tier rather than a free-text marker (the old `ultrathink`)
(the `harness-work` effort scoring has also been unified to the tier-selection approach).

### Determination: whether xhigh can be passed to the API via CC

**Determination: adopted (there is evidence that xhigh is accepted in the frontmatter)**

Rationale:
1. The v2.1.111 section of `docs/CLAUDE-feature-table.md` records `xhigh effort` as `A: explicit follow-up target`
2. The Opus 4.7 section of the same file also records `xhigh effort` as `A: explicit follow-up target`
3. Harness treats `xhigh` as "reasoning intensity chosen by the caller" and pins it in the agent frontmatter (`agents/reviewer.md`, `agents/advisor.md`)

When `xhigh` is written in the frontmatter, CC sends a highest-effort-tier request to Opus 4.8. On non-Opus 4.8 models (such as the Sonnet family) it is silently downgraded to the equivalent of `high`. It is not rejected or errored.

## Harness Adoption Policy

| Flow | Adopted effort | Reason |
|--------|------------|------|
| Plan | `high` | Good balance of speed and organizational ability |
| Work (Worker agent) | `high` | Implementation benefits more from repeated verification than long deliberation |
| Review (Reviewer agent, harness-review) | `xhigh` | The added thinking pays off in comparison, counter-argument, and gap detection |
| Advisor | `xhigh` | Prioritizes the accuracy of PLAN / CORRECTION / STOP decisions |
| Release / Setup | `high` | Mostly procedure-following; always using `xhigh` is overkill |

### Frontmatter update targets

| File | Before | After | Reason |
|--------|--------|--------|------|
| `agents/reviewer.md` | `effort: medium` | `effort: xhigh` | Adopt xhigh for Review |
| `agents/advisor.md` | `effort: high` | `effort: xhigh` | Adopt xhigh for Advisor |
| `skills/harness-review/SKILL.md` | `effort: high` | unchanged | The skill's effort is overridden by the caller, so keep high |

## Operating Rules

1. **Prioritize review and advisory as targets for `xhigh`**
   Reason: bug detection and counter-argument benefit more from added thinking than implementation itself.

2. **Keep work at the default `high`**
   Reason: implementation often benefits more from short verification cycles than from token consumption.

3. **In the docs, state clearly that "non-Opus 4.8 falls back to `high`"**
   Reason: users easily misunderstand and think "I wrote `xhigh` but it isn't working."

4. **Do not set all skills / all agents uniformly to `xhigh`**
   Reason: cost and latency increase needlessly. Use it selectively by role.

5. **Treat `${CLAUDE_EFFORT}` as read-only**
   Reason: since Claude Code 2.1.120, the current effort level can be referenced from within a skill body.
   However, this is information for reading the effort chosen by the caller; it is not a mechanism for the skill to override effort on its own.

### `${CLAUDE_EFFORT}` guidance

`CLAUDE_EFFORT` is a variable for referencing, from within a skill body, the effort level in effect for the current session / invocation.

Acceptable usage:

```md
Current effort: `${CLAUDE_EFFORT}`.
If effort is low, report only confirmed blockers.
If effort is xhigh, include adversarial checks and edge cases.
```

Usage to avoid:

- Demanding "always change to xhigh" in the skill body
- Treating an environment where `CLAUDE_EFFORT` is empty as a failure
- Ignoring the effort specified by the user / parent workflow

Harness's policy:

- Leave the choice of effort with the caller.
- The skill uses `CLAUDE_EFFORT` only for explanation, branching, and adjusting output granularity.
- For internally-invoked skills such as media / announcement types, prioritize clarifying the invocation contract (`user-invocable` / `disable-model-invocation`) over effort.

## Rationale for deferral (things not adopted)

The following are not adopted. The reasons for deferral are stated.

| Item | Reason for deferral |
|------|-----------|
| Setting the Worker agent to `xhigh` | The implementation loop benefits more from fast iteration than long deliberation. The quality gain does not justify xhigh's added cost |
| Setting the Setup / Release skills to `xhigh` | Mostly procedure-following, where recall matters more than judgment |
| Reviving `max` | Removed in CC v2.1.72. `xhigh` is its successor |

## Caveats

- `xhigh` is not "magic that makes it smarter" but room to think more deeply
- With vague instructions, deeper thinking just refines in the wrong direction
- On models other than Opus 4.8, specifying `xhigh` falls back to the equivalent of `high`, so the expected effect may not materialize
- `xhigh` is "reasoning intensity chosen by the caller," not something the agent prompt infers from a free-text marker (set via `effort:` frontmatter in `agents/reviewer.md` / `agents/advisor.md`)

## Related Files

- `docs/CLAUDE-feature-table.md` — feature list for v2.1.111 / Opus 4.7
- `docs/claude-code-setup-mcp-telemetry-provider.md` — `${CLAUDE_EFFORT}` and setup guidance
- `agents/reviewer.md` — Reviewer effort setting
- `agents/advisor.md` — Advisor effort setting
