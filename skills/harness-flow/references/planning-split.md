# Planning + split, work, review (Steps 4-7)

harness-flow does not plan, worktree, implement, or review on its own — it hands
the verified requirement to the existing skills and records what they produce.

## Step 4 — Plan (delegate `harness-plan create`)

Invoke `harness-plan create` with the requirement as input and the JIRA key as
provenance. Pass:

- Title + description + acceptance criteria from `requirement.json`.
- The source ref (`PROJ-123` / Confluence page) so the plan and its commits are
  traceable to the ticket.

`harness-plan create` produces its usual co-required output: a **Spec delta**
(or a spec-skip reason) plus **Plans.md task rows**, and a `## Pre-approval`
block. Persist that block:

```
# harness-plan writes it; ensure it lands in the host project state
.claude/state/plan-preapprovals.json   (schema: templates/schemas/plan-preapproval.v1.json)
```

### Splitting a long requirement

Prefer the harness-native split — **one Plans.md, multiple Phases + numbered
subtasks** (`| Task | Content | DoD | Depends | Status |`, lanes `[lane:fast|gate|release]`,
markers `cc:TODO` / `pm:pending`). Splitting = phase decomposition + `Depends`
edges so independent subtasks (`Depends: -`) can fan out in parallel.

Use **named plans** only when the requirement decomposes into genuinely
independent deliverables that want separate plan files:

```
# one named plan per sub-deliverable, via the plan registry
scripts/plan-registry.sh ...      # plans/manifest.json
```
Record each created plan name in the session:
```
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" set-json <session.json> plans '["main"]'
```
Carry `--plan <NAME>` through Steps 5-9 for each named plan.

### Gate

Validate the dependency graph before working:
```
( cd "${HARNESS_PLUGIN_ROOT}/go" && go run ./cmd/harness plans check-deps )
```
A dependency-closure failure blocks Step 5 — fix the plan, do not skip the gate.

Then: `flow-session.sh status <session.json> working`.

## Steps 5-6 — Worktree + Work (delegate `harness-work all`)

Invoke `harness-work all` (or `--plan <NAME>` per named plan). Auto-mode selects
topology by task count: **1 = Solo, 2-3 = Parallel, 4+ = Breezing**. Everything
below happens *inside* harness-work — harness-flow does not touch it directly:

- worktrees under `.harness-worktrees/task-<T>`,
- sprint contracts (`scripts/generate-sprint-contract.js` + `ensure-sprint-contract-ready.sh`),
- TDD RED logging,
- the `worker.md` `self_review[]` gate,
- per-task commit onto trunk.

**JIRA-key injection**: pass the source ref in the delegation briefing so each
task's commit message is prefixed `[PROJ-123]`. This is a briefing string, not
new code — the commit itself is created by harness-work's normal cherry-pick.

Record the produced commit hashes:
```
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" set-json <session.json> commit_hashes '["<hash1>","<hash2>"]'
```

## Step 7 — Review

harness-work already runs its built-in review loop and writes `review-result.v1`
(`.claude/state/review-result.json`). No separate call is needed on the happy
path. Add an extra lens only when ingestion flagged risk:

- security-sensitive labels → `harness-review --security`
- broad/cross-cutting change → `harness-review --dual`

A `REQUEST_CHANGES` verdict routes into the fix/rework loop (Step 10) exactly
like an operator not-OK. Set `flow-session.sh status <session.json>
awaiting-confirm` once review converges to APPROVE.
