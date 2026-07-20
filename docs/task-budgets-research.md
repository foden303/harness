# Task Budgets (Public Beta) Research Notes

Phase 44.10.1 created: 2026-04-18

This document summarizes the specification of **Task Budgets (public beta)** added to the Anthropic API,
analyzes how it conflicts with Harness's existing control mechanisms, and
records **the rationale for deferring adoption in this Phase and when to reconsider adoption in the future**.

---

## 1. Summary of the Task Budgets API specification

> **Note**: The following is a summary based on the public beta spec as of 2026-04-18.
> For exact field names, schemas, and error codes, refer to the official Anthropic documentation.
> Uncertain field names and similar items are marked `(estimated)`.

### 1-1. Overview

Task Budgets is a set of parameters added to the Anthropic API's Messages API or Agents API that
declaratively specify the upper limit of resources a single agent call (or per task) can consume.

By passing token consumption and cost as up-front constraints,
it aims to prevent agent runaway and unexpected high charges at the API layer.

### 1-2. Input parameters (estimated)

Since the official documentation is not yet finalized at the beta stage, the following is estimated from Anthropic's public information and known similar features.

| Parameter name | Type | Description |
|------------|-----|------|
| `max_input_tokens` (estimated) | integer | Max input tokens a single task can consume |
| `max_output_tokens` (estimated) | integer | Max output tokens a single task can generate |
| `max_cost_usd` (estimated) | number | Max cost limit in USD |

These parameters appear to be specified inside the `task_budget` object (estimated) of the API request.

```json
// Example structure (estimated — see the Anthropic docs for the actual field names)
{
  "model": "claude-opus-4-7",
  "messages": [...],
  "task_budget": {
    "max_input_tokens": 100000,
    "max_output_tokens": 8000,
    "max_cost_usd": 2.00
  }
}
```

### 1-3. Output / error format (estimated)

When a limit is exceeded, a `budget_exhausted` error appears to be returned, distinct from normal streaming completion.

```json
// Example error response (estimated)
{
  "type": "error",
  "error": {
    "type": "budget_exhausted",
    "message": "Task budget exceeded: max_cost_usd limit reached",
    "exhausted_budget": "max_cost_usd"
  }
}
```

If you have built an agent loop, the loop that receives this error must treat it as
"early termination due to budget exhaustion".

### 1-4. Current status

- **Public beta** — limited release to some users / API tiers
- The GA (general availability) date is unannounced (as of 2026-04-18)
- Schema backward compatibility is not guaranteed (as usual for beta)

---

## 2. Conflicts with Harness's existing mechanisms

The "resource limit" feature Task Budgets provides overlaps with concepts Harness already implements through several of its own mechanisms.
The table below organizes the conflict points.

| Existing Harness mechanism | Location | Controls | Overlap with Task Budgets |
|----------------|------|---------|----------------------|
| Advisor consultation count limit (max 3 times) | Advisor consultation decision in `agents/worker.md` | How many times a Worker can call the Advisor | Low (different purpose) |
| `maxTurns` | `agents/worker.md` frontmatter (Worker: 100, Reviewer: 50) | Agent turn count limit | Medium (indirectly limits token consumption) |
| `effort` frontmatter | `agents/worker.md`, each skill frontmatter | Thinking effort (low/medium/high) | Medium (affects output token consumption) |
| `/cost` per-model breakdown | CC built-in (v2.1.92) | Cost visibility (after the fact) | Low (after-the-fact review, not an up-front constraint) |
| `scripts/detect-review-plateau.sh` | `skills/harness-loop` Step 6 | Detecting review-loop stalls | Low (quality gate, not cost control) |
| harness-loop `--max-cycles N` | `skills/harness-loop` | Loop cycle count limit (default 8) | Medium (indirectly limits whole-session consumption) |
| Advisor `STOP` verdict | `agents/worker.md`, `skills/harness-loop` Advisor Strategy | Manual escalation for dangerous tasks | Low (quality gate, not cost control) |

### 2-1. The highest-conflict point

**`maxTurns` vs `max_input_tokens` / `max_output_tokens`**:

- `maxTurns: 100` limits the Worker's turn count and indirectly suppresses token consumption
- `max_input_tokens` limits the token count more directly
- However, `maxTurns` is "loop control" and `max_input_tokens` is "cost control"; their primary purposes differ

**`harness-loop --max-cycles` vs `max_cost_usd`**:

- `--max-cycles N` indirectly controls the cost of long sessions via the cycle count
- `max_cost_usd` controls it directly in dollar terms
- `--max-cycles 8` (default) is a coarse method that limits without knowing the actual cost, whereas
  Task Budgets' `max_cost_usd` is more precise

### 2-2. Non-conflicting areas

The following are Harness-specific concepts that Task Budgets cannot replace:

- `plateau detection` — stalling of the quality loop (a quality gate, not cost control)
- Advisor consultation count limit — controlling the number of policy consultations (governance, not cost control)
- `effort` level — adjusting thinking quality (adjusting the quality/cost trade-off, not cost reduction)

---

## 3. If adopted, "in which skill" and "at what granularity"

Below are candidate granularities and application points for adopting Task Budgets in the future.

### 3-1. Per-task budget (a limit on a single task's Worker spawn)

| Item | Content |
|------|------|
| Application point | At the Agent call in `agents/worker.md` |
| Granularity | Add a `task_budget` section to the sprint-contract and specify the limit per task |
| Benefit | Prevents a single heavy task from eating up the budget |
| Challenge | Requires appropriate budget estimation per task. Underestimation causes mid-run termination |
| Implementation point | Add `task_budget` section generation logic to `scripts/generate-sprint-contract.js` |

### 3-2. Per-session budget (a limit on an entire breezing session)

| Item | Content |
|------|------|
| Application point | At loop start in `skills/harness-loop/SKILL.md`, or the breezing mode of `skills/harness-work` |
| Granularity | Set `max_cost_usd` for the whole session, and on exceedance stop the loop and report |
| Benefit | Clearly defines a cost limit for long sessions. More precise than `--max-cycles` |
| Challenge | Requires logic to gracefully handle budget exhaustion mid-session |
| Implementation point | Add a step that checks remaining budget before `[Step 9] Schedule next wake-up` in `harness-loop` |

### 3-3. Per-day budget (a per-user daily limit)

| Item | Content |
|------|------|
| Application point | Above the Harness layer (Anthropic dashboard API usage limits, or user-side external control) |
| Granularity | Alert / auto-stop when the daily cumulative cost exceeds a threshold |
| Benefit | Reliably prevents unexpected high charges |
| Challenge | Hard to implement on the Harness side (requires cross-session state management). Needs integration with harness-mem |
| Implementation point | A daily cost accumulation record using `harness_mem_record_checkpoint`, plus a check at `harness-loop` startup, is conceivable |

---

## 4. Decision not to adopt in this Phase + rationale

**Decision: defer implementing Task Budgets in Phase 44.**

### Reason 1: API stability is uncertain because it is public beta

Task Budgets is public beta as of 2026-04-18.
Schema backward compatibility is not guaranteed, and field names and behavior are likely to change before GA.
If a beta API is built into Harness's core control (sprint-contract generation, harness-loop),
there is a risk that changes on Anthropic's side directly cause breaking changes in Harness.

### Reason 2: The existing `maxTurns` + `--max-cycles` + Advisor STOP already cover 80%

| Risk to protect against | Existing handling |
|----------------|-----------|
| Single Worker runaway | Terminate with `maxTurns: 100` |
| Excess consumption in long sessions | Stop with `--max-cycles 8` (default) |
| Quality-loop stalling | `detect-review-plateau.sh` + `PIVOT_REQUIRED` |
| Over-consultation on high-risk tasks | Advisor consultation limit, max 3 times |

Task Budgets' "direct control in dollar terms" is convenient, but
combining the current control mechanisms already prevents effective cost runaway.

### Reason 3: Priority allocation for Phase 44

The Phase 44 scope centers on the following:

- Resolving Plugin agent exposure
- Phase 45 sync.go fixes
- PreCompact hook implementation
- For Task Budgets, the Phase 44 goal is **research and documentation only** (this task)

Rather than investing Phase 44's remaining resources into implementing Task Budgets,
completing the confirmed scope above has higher priority.

### Reason 4: Integration design with harness-mem is undecided

Daily accumulation management like a per-day budget requires integration with `harness-mem`'s checkpoint feature.
Implementing without settling the integration design would create technical debt at a later `harness-mem` design change.
Doing the design correctly requires a separate research task, and it is not in the Phase 44 scope.

---

## 5. When to reconsider adoption in the next cycle

Reassess once any of the following trigger conditions is met.

| Trigger | Detail | Evaluation Phase |
|---------|------|------------|
| Task Budgets is promoted to GA | When Anthropic officially announces GA, recheck the schema and decide on adoption | Phase 45 onward, after GA confirmation |
| An actual cost overrun occurs that `maxTurns` alone cannot prevent | If a high charge occurs during Harness operation before reaching the `maxTurns` limit | As soon as it occurs, create an urgent response task |
| The `harness-mem` accumulation-record design is settled | If harness-mem's daily aggregation feature is implemented and stabilized, begin implementing the per-day budget | Phase 45 onward |
| Anthropic publishes a recommended implementation pattern for Harness | If official docs or a blog show an integration example of Task Budgets + agent framework | Within 1 Phase after confirmation |

### Items to check at reassessment

At reassessment, check the following:

1. Whether the field names match the estimates in this document (e.g., `max_input_tokens`)
2. Whether graceful handling of the `budget_exhausted` error can be built into the sprint-contract loop
3. Decide which of the 3 granularities (per-task / per-session / per-day) to start with
4. Whether adding a `task_budget` section to `scripts/generate-sprint-contract.js` is technically feasible

---

## Referenced files

- `agents/worker.md` — Advisor consultation limit, `maxTurns`, `effort` frontmatter
- `docs/CLAUDE-feature-table.md` — the `task budgets` entry (around line 210, `A: explicit follow-up target`)
- `skills/harness-loop/SKILL.md` — `--max-cycles`, plateau detection, Advisor Strategy
- `.claude/rules/opus-4-7-prompt-audit.md` — definition of the 2.1.111 operational knobs
