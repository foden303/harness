# Model Routing Policy

Status: adopted
Last updated: 2026-06-11

This document defines the default model and reasoning-effort routing for
Claude Code in Harness workflows.

## Decision

Use explicit role tiers, not prompt-text inference.

Harness must route model and effort from the workflow role:

- `lite`: cheap, read-heavy, low-risk work
- `standard`: ordinary implementation and setup
- `deep`: architecture, security, cross-repo, migration, and failure recovery
- `review`: quality gates and adversarial checks
- `release`: procedural release and public-surface checks
- `long-context`: large repository or long-session context work

Do not infer effort from free-text markers such as "think harder". A caller may
still ask for one-off deeper reasoning, but durable routing belongs in config,
agent frontmatter, or wrapper arguments.

## Official Evidence

Claude Code supports model aliases and explicit model IDs. `opusplan` uses Opus
in plan mode and Sonnet in execution mode, which matches Harness' Plan -> Work
split. Claude Code settings can pin `model`, restrict `availableModels`, and set
default alias targets through `ANTHROPIC_DEFAULT_*_MODEL` environment variables.
Official docs: https://code.claude.com/docs/en/model-config

Claude Code effort is configurable through `/effort`, `/model`, `--effort`,
`CLAUDE_CODE_EFFORT_LEVEL`, `effortLevel`, and skill/subagent frontmatter.
Frontmatter overrides the session level, while `CLAUDE_CODE_EFFORT_LEVEL`
overrides both. Official docs: https://code.claude.com/docs/en/model-config

Claude subagents can set `model` to an alias, full model ID, or `inherit`.
Resolution order is `CLAUDE_CODE_SUBAGENT_MODEL`, per-invocation model,
frontmatter model, then main conversation model. Therefore Harness must not set
`CLAUDE_CODE_SUBAGENT_MODEL` by default because it would flatten per-agent
routing. Official docs: https://code.claude.com/docs/en/sub-agents

Anthropic's current model table positions Claude Opus 4.8 as the most capable
model for complex reasoning and agentic coding, Sonnet 4.6 as the best speed /
intelligence balance, and Haiku 4.5 as the fastest model. Official docs:
https://platform.claude.com/docs/en/about-claude/models/overview

## Override Priority

1. **Explicit caller override** — Task/subagent `model` or CLI `--model`.
2. **Harness routed default** — `scripts/model-routing.sh --role …`
3. **Session inherit** — subagent `model: inherit` or host session default.

Residual risk: team/admin/plan-unavailable models may fall back silently unless
smoke or operator checks catch them. Do not treat availability in one account as
guaranteed for every Harness user.

## Claude Code Routing

| Harness tier | Claude model | Effort | Use cases |
| --- | --- | --- | --- |
| `lite` | `claude-haiku-4-5` or `haiku` | `low` or `medium` | read-only search, docs cleanup, simple summaries, cheap side research |
| `standard` | `claude-sonnet-5` | `medium` by default, `high` for code-risk tasks | normal worker implementation, setup, tests, scoped refactors |
| `deep` | `claude-opus-4-8` | `xhigh` | architecture, security, migration, cross-repo decisions, repeated failures |
| `review` | default reviewer: `claude-sonnet-5`; adversarial/final reviewer: `claude-opus-4-8` | `xhigh` | normal review stays cost-aware; high-risk gates use Opus |
| `advisor` | `claude-opus-4-8` | `xhigh` | PLAN / CORRECTION / STOP decisions after blocked execution |
| `release` | `claude-sonnet-5` | `high` | release preflight, changelog, version/tag/GitHub Release checks |
| `long-context` | `sonnet[1m]` | `high` | large repo reading, long sessions, context-heavy comparison |

Recommended Claude session default:

```json
{
  "model": "opusplan",
  "availableModels": [
    "opusplan",
    "claude-opus-4-8",
    "claude-sonnet-5",
    "claude-haiku-4-5",
    "sonnet[1m]"
  ],
  "effortLevel": "high",
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5"
  }
}
```

Notes:

- `opusplan` is the preferred operator default because it naturally spends Opus
  on planning and Sonnet on execution.
- Keep `CLAUDE_CODE_SUBAGENT_MODEL` unset by default. Use it only as a temporary
  emergency override, because it outranks per-agent model settings.
- Do not set `max` in shared settings. `max` is session-only and should be used
  only for explicit one-off experiments.
- `ultrathink` is a legacy free-text marker. Do not use it for durable routing.
  On Claude Opus 4.8, control reasoning depth with `effort` (`high`/`xhigh`), not
  prompt markers. If reasoning looks shallow on a hard task, raise effort rather
  than prompting around it.
- `HARNESS_BRAIN_MODEL=fable` opts the `deep` / `advisor` tiers into
  `claude-fable-5` (Fable 5). Unset, empty, or `opus` keeps `claude-opus-4-8`;
  any other value exits 2 instead of falling back silently. The opt-in never
  changes the `standard` / `review` tiers.

## Harness Role Defaults

| Harness surface | Claude default | Why |
| --- | --- | --- |
| Interactive operator session | `opusplan`, `high` | strong default without forcing max spend |
| `/harness-plan` | `opusplan` or Opus for non-trivial planning | planning quality affects all downstream work |
| `worker` | Sonnet 4.6, `medium` to `high` | implementation benefits from iteration and tests |
| `explorer` / read-only fan-out | Haiku 4.5, `low` | cheap context isolation |
| `reviewer` | Sonnet 4.6 `xhigh`; Opus 4.8 `xhigh` for high-risk | review is where deeper reasoning pays |
| `advisor` | Opus 4.8, `xhigh` (Fable 5 via `HARNESS_BRAIN_MODEL=fable`) | blocked-loop decisions need high confidence |
| `release` | Sonnet 4.6, `high` | procedural but public-facing |

## Non-Goals

- Do not update global user config automatically.
- Do not force every subagent to the most expensive model.
- Do not route by vague prompt words.
- Do not use model routing to bypass sandbox, approval, or review gates.
- Do not treat availability of a model in one account type as guaranteed for
  every Harness user.

## Implementation Surface

Harness implements the routing contract through `scripts/model-routing.sh`.
The router maps:

```text
tier -> claude model/effort
role -> tier
```

The router should be tested independently from the current user-level
`~/.claude/settings.json`, because that file is an operator preference, not
repository truth.
