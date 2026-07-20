---
name: breezing
description: "Team execution mode — backward-compatible alias for harness-work with team orchestration."
description-en: "Team execution mode — backward-compatible alias for harness-work with team orchestration."
kind: workflow
purpose: "Wrap harness-work with team execution orchestration"
trigger: "breezing, team execution, do everything"
shape: wrap
role: orchestrator
base: harness-work
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "WebSearch", "Monitor"]
argument-hint: "[all|N-M|--parallel N|--no-commit|--no-discuss|--auto-mode]"
user-invocable: true
---

# Breezing — Team Execution Mode

> **Backward-compatible alias**: runs `harness-work` in team execution mode.

## Narration Rules (UX Contract)

The enemy is **verbosity**, not progress reporting. **State the execution plan concisely at startup before beginning execution.** Readable progress reporting is welcome. Only verbose repetition and empty preambles are prohibited.

### Always emit at startup (banner + plan, 5 lines total or fewer)

In the first response, show what will be done and in what order, then start running tools:

```
🚀 claude / feat/hah-11-golden-rule-lint / Reviewer
Next:
1. Identify branch/task
2. Finalize verdict with brain primary review → 3-5 line summary → update Plans.md
```

Banner 1 line (`🚀 <backend> / <branch> / <task>`) + plan 2-4 lines. Emit within 1 second, then proceed straight to Step 1.

### Progress reporting is allowed (within readable limits)

- One-line status for the start/completion of each step (`✓ Worker complete`)
- Intermediate results needed for judgment (key points of the pre-check, resolved model, detected branch, etc.)
- One-line reason for why this branch was taken (e.g., "Delegate Reviewer only: Worker already completed via a separate path")

### Prohibited (= verbosity)

- **Restating the same fact twice**: do not re-explain something already stated
- **Empty preambles**: lines like "Let me check how to use it" that are self-evident from the tool call
- **3+ lines of retrospective recap**: long preambles that drag out the conclusion. If background is needed, compress it to 1 line
- **★ Insight blocks during the startup sequence**: Insight appears only once, in the final report

Bad example (verbose):
```
× "Since the Reviewer stalled last time, offloading to a separate path makes sense" (3+ lines of recap)
× "Let me check how to use it" → bash → "It can be called" (empty preamble + restating the same fact twice)
```

Good example (concise + explicit plan):
```
🚀 claude / feat/hah-11-golden-rule-lint / Reviewer
Next: identify branch/task → finalize verdict with brain primary review
```

## Quick Reference

```bash
/breezing                       # Ask for scope
/breezing all                   # Run all tasks to completion
/breezing 3-6                   # Run tasks 3-6 to completion
/breezing --parallel 2 all      # Run all tasks with parallelism 2
/breezing --no-discuss all      # Run all tasks, skipping the planning discussion
/breezing --auto-mode all       # Try Auto Mode rollout in a compatible parent session
```

## Brief Composer v0

A decomposition/confirmation flow for **free-text input that matches none of** the argument-hints (`all|N-M|--parallel N|--no-commit|--no-discuss|--auto-mode`).

1. **Classify** — the Lead runs `bash scripts/breezing-brief.sh classify "<args>"`.
   - Output `structured` → proceed directly to the existing structured-argument path (see Quick Reference above).
   - Output `free-text` → go to the next step.
2. **Decompose** — the Lead's LLM decomposes the free text into **3-7 subtasks** and assembles a `brief-card.v1` JSON card (schema: `templates/schemas/brief-card.v1.json`). In v0, `breezing-brief.sh` does not call the LLM.
3. **Present** — present the card (goal / subtasks[id,title,dod] / scope_files / risk_notes / confidence) to the user. `confidence` is one of `high` | `medium` | `low`.
4. **Confirm** — after the user's Yes/No, run `bash scripts/breezing-brief.sh confirm <yes|no> <card.json>`.
   - `yes` → emit `DISPATCH: <subtask count>` and hand off to the existing team path (worktree-per-task).
   - `no` → `DISPATCH: 0` (a dry contract that executes nothing).

If you only need validation: `bash scripts/breezing-brief.sh validate <card.json>` (exit 0 = valid).

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `all` | Target all incomplete tasks | - |
| `N` or `N-M` | Specify a task number/range | - |
| `--parallel N` | Number of parallel Implementers | auto |
| `--no-commit` | Suppress auto-commit | false |
| `--no-discuss` | Skip the planning discussion | false |
| `--auto-mode` | Explicit Harness-side Auto Mode rollout. Different from `--enable-auto-mode`, which became unnecessary in CC 2.1.111 | false |

> **CC 2.1.111 note**:
> On Opus 4.8 you can literally use `/effort xhigh`.
> Use the built-in `/ultrareview` only additionally on explicit request; it does not replace the default review.

> **Recommended for long sessions (CC 2.1.108+)**:
> If a session is expected to exceed 30 minutes, after resolving the plugin bundle root run
> `bash "${HARNESS_PLUGIN_ROOT}/scripts/enable-1h-cache.sh"` to opt into the 1-hour prompt cache.
> This script appends `export ENABLE_PROMPT_CACHING_1H=1` to `env.local` (idempotent).
> With the default 5-minute TTL cache, cache misses accumulate over breezing sessions longer than 1 hour and
> input token cost can grow up to 12x, so explicitly opt in for long team runs.
> For details see [`docs/long-running-harness.md`](../../docs/long-running-harness.md).

## Execution

**This skill delegates to `harness-work`.** Run `harness-work` with the following settings:

1. **Pass the arguments through to `harness-work` as-is**
2. **Force team execution mode** — three-way separation of Lead → Worker spawn → Reviewer spawn
3. **The Lead delegates only** — it does not write code directly
4. **Auto Mode is opt-in** — `--auto-mode` is accepted as a rollout flag in a compatible parent session
5. **Advisor only when needed** — the Lead calls the advisor only when a Worker returns `advisor-request.v1`

### Handling of plan-time preapproval

At the start of a breezing run, the Lead runs the same preapproval preflight as `harness-work`.

- If `.claude/state/plan-preapprovals.json` exists, validate it with `templates/schemas/plan-preapproval.v1.json`.
- Treat only the `decision: approved` items of the target task as pre-declared and pass them to the Worker briefing.
- `secret-read` is applied per-run to the project config `.harness.config.json` `runtimefloor.secretAllow` via `bash "${HARNESS_PLUGIN_ROOT}/scripts/plan-preapproval.sh" apply-secret-allow "$PROJECT_ROOT"`, connecting to the 108.2 project config floor.
- For pre-declared items, do not stop mid-run; make `AskUserQuestion` triggered by pre-declared items zero during work. Confirmation happens only once, at plan approval.
- Unplanned secret-read / external send / destructive operations not on record still stop via the runtime floor / ask as before. Do not narrow the safety net.

### Differences from `harness-work`

| Aspect | `harness-work` | `breezing` (this skill) |
|------|-----------------|------------------------|
| Parallelization | Automatic split by required count | **Role separation of Lead/Worker/Reviewer** |
| Lead's role | Coordinate + implement | **Delegate (coordinate only)** |
| Review | Lead self-review | **Independent Reviewer** |
| Default scope | Next task | **Everything** |

### Team Composition

| Role | Agent Type | Mode | Responsibility |
|------|-----------|------|------|
| Lead | (self) | - | Coordinate, direct, distribute tasks |
| Worker ×N | `harness:worker` | `bypassPermissions` (current) / Auto Mode (follow-up)* | Implement |
| Advisor | `harness:advisor` | Read-only | Direction advice (`PLAN` / `CORRECTION` / `STOP`) |
| Reviewer | `harness:reviewer` | `bypassPermissions` (current) / Auto Mode (follow-up)* | Independent review |

> *If the parent session or frontmatter is `bypassPermissions`, that takes precedence. Distribution templates still use `bypassPermissions`, so Auto Mode is a follow-up rollout target, not the default behavior.

### Dispatch path

Breezing fans out through Claude Code's Agent tool: the Lead spawns
`harness:worker` and `harness:reviewer` agents and aggregates their reports.
The three-way Lead/Worker/Reviewer separation above is the whole model.

An in-process Go orchestrator (`harness work --team`) with an opt-in
Producer/Sub-Lead hierarchy was removed before v1.0.0 — it dispatched through
per-backend companion shell scripts that no longer exist. Review iteration
lives in the Reviewer agent loop, not in that layer.

## Flow Summary

```
breezing [scope] [--parallel N] [--no-discuss] [--auto-mode]
    │
    ↓ Load harness-work with team mode
    │
Phase 0: Planning Discussion (skipped with --no-discuss)
Phase A: Pre-delegate (team initialization)
Phase B: Delegate (Worker implements + Advisor when needed + Reviewer reviews)
Phase C: Post-delegate (integration verification + update Plans.md + commit)
```

## Advisor Protocol

Workers do not spawn more generic subagents.
When stuck, they only return a structured JSON consultation request, and the Lead calls the advisor.

1. Worker → `advisor-request.v1`
2. Lead → Advisor
3. Advisor → `advisor-response.v1`
4. Lead → returns the advice to the same Worker to continue
5. The Reviewer looks only at the final deliverable

The consultation conditions match loop / solo.

- Before the first execution of a high-risk task (`needs-spike` / `security-sensitive` / `state-migration`)
- After the same cause fails twice in a row
- Right before returning `PIVOT_REQUIRED` due to a plateau
- The same `trigger_hash` only once. The consultation count per task is at most 3.

### Progress Feed (progress notifications during Phase B)

For each Worker task completion, the Lead emits progress in the following format:

```
📊 Progress: Task {completed}/{total} done — "{task_subject}"
```

**Example output**:
```
📊 Progress: Task 1/5 done — "Add failure re-ticketing to harness-work"
📊 Progress: Task 2/5 done — "Add --snapshot to harness-sync"
📊 Progress: Task 3/5 done — "Add a progress feed to breezing"
```

> **Design intent**: breezing often runs for a long time.
> When the user glances at the terminal, they should see at a glance "how far along it is right now."
> The task-completed.sh hook emits equivalent information via systemMessage, so it complements the Lead's output.

### Silence Policy (organizing notifications for long runs)

Breezing's progress feed narrows notifications to "milestones of the work."

Report these:

- Task completion, blocked, validation failure, review `REQUEST_CHANGES`
- Advisor's `PLAN` / `CORRECTION` / `STOP`
- Reviewer's `APPROVE` / `REQUEST_CHANGES`
- advisor / reviewer drift, plateau, contract readiness failure
- A summary when the user explicitly asks for status

May stay silent for these:

- Just received a transcript delta with no change in judgment or status
- Small increments of tool stdout that are sufficiently captured in the log
- Heartbeats while parallel Workers are waiting

Set the baseline frequency to "once per task completion."
Rather than adding heartbeats to create reassurance, split responsibility across status / log / drift detection.
However, do not silence an unanswered Advisor request, an unarrived Reviewer result, or a warning right before a plateau.

### Monitor tool usage guide (CC 2.1.98+)

When monitoring a long-running command, use the **Monitor tool** rather than polling (periodically reading the file tail with Read). Monitor delivers each stdout line of a background process to the Lead as incremental notifications, so you can track the situation with lower latency and lower token consumption than polling.

**Examples**:
- Monitoring progress during `go test ./... -v`
- Tracking GitHub Actions progress with `gh run watch`
- Immediately detecting build errors with `npm run build --watch` / `vite build --watch`
- Following deploy logs with `docker-compose logs -f` / `kubectl logs -f`

**Criteria for choosing**:

| Target | Use Monitor? | Reason |
|---|---|---|
| Monitoring completion of an Agent (Worker / Reviewer) | Not needed | The Agent layer notifies completion itself |
| A shell process launched with `run_in_background: true` | Recommended | You can pick up each stdout line via incremental notifications |
| A short one-off command (a single `go test` run) | Not needed | A normal Bash tool run is sufficient |
| Long-running tail / watch / stream commands | Recommended | More efficient than polling |

**Typical pattern for a Breezing Lead**:

```
Lead:
  Task(Worker1, ...)           ← Wait for Agent completion (Monitor not needed)
  Task(Worker2, ...)           ← Same as above
  Bash(run_in_background, "gh run watch --exit-status")
  Monitor(tailCommand="...")   ← Detect CI failure immediately → instruct Worker to fix
```

This lets the Lead speed up its reaction of "Worker completes → detect CI failure → instruct fix."

### Review Policy (unified across all modes)

Even in Breezing mode, review follows the unified policy of the **internal Reviewer agent**.
For details, see the "review loop" section of `harness-work`.

- Worker implements/commits inside a worktree → returns `worker-report.v1` (5 self_review items) to the Lead
- **self_review gate (before Reviewer spawn)**: the Lead mechanically verifies `self_review[].verified` and `evidence`. If even one is `verified:false` or `evidence:""`, do not spawn the Reviewer and auto-return to the Worker (up to 2 times within the same session; escalate on the 3rd)
- The Lead reviews via the internal Reviewer agent
- REQUEST_CHANGES → the Lead instructs the Worker to fix via SendMessage, and the Worker amends (up to `MAX_REVIEWS` times; `MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3`)
- APPROVE → **the Lead** cherry-picks to main → updates Plans.md to `cc:done [{hash}]`

### Completion report (Phase C — generated by the Lead)

After all tasks complete, **the Lead** generates a rich completion report by the following steps:

1. Collect all cherry-picked commits with `git log --oneline {base_ref}..HEAD`
2. Get the overall change size with `git diff --stat {base_ref}..HEAD`
3. Extract remaining `cc:TODO` / `cc:WIP` tasks from Plans.md
4. Output following the Breezing template in the "completion report format" of `harness-work`

> **The generator is the Lead**, not the Worker or a hook. The Lead reads git + Plans.md in Phase C to generate it.

### Phase 0: Planning Discussion (structured 3-question check)

Before running all tasks, confirm plan health with the following 3 questions.
When `--no-discuss` is specified, all are skipped.

**Q1. Scope check**:
> "About to run {{N}} tasks. Is the scope appropriate?"

If there are too many, propose narrowing by priority (Required > Recommended > Optional).

**Q2. Dependency check** (only when Plans.md has a Depends column):
> "Task {{X}} depends on {{Y}}. Is the execution order correct?"

Read the Depends column and display the dependency chain. Error if there is a circular dependency.

**Q3. Risk flag** (only when there is a `[needs-spike]` task):
> "Task {{Z}} is [needs-spike]. Spike it first?"

If there is an incomplete-spike `[needs-spike]` task, confirm whether to run the spike first.

If all 3 questions are fine, proceed to Phase A (designed to complete in 30 seconds total).

### Universal Violations Injection (propagating learning across Workers within a session)

Automatically inject the Reviewer's universal gotchas accumulated within the same `/breezing` invocation at the top of the next Worker's briefing. **Valid only within the same session** (discarded at session end; not written to `session-memory`).

```python
# Initialize the Lead process's in-memory array at the start of Phase A
universal_violations = []  # List[str] — accumulated within this session

# Just before spawning a Worker in Phase B, inject at the top of the briefing:
def build_worker_briefing(task, contract_path):
    header = ""
    if universal_violations:
        header = (
            "🚨 Universal violations already detected in this session (do not repeat):\n"
            + "\n".join(f"- {v}" for v in universal_violations)
            + "\n\n"
        )
    return header + f"Task: {task.content}\nDoD: {task.DoD}\ncontract_path: {contract_path}\nmode: breezing"

# After the Reviewer returns review-result.v1, the Lead extracts only scope="universal" and accumulates:
for update in reviewer_result.memory_updates:
    # Backward compat: strings are treated as task-specific → ignore
    if isinstance(update, str):
        continue
    if update.get("scope") == "universal":
        universal_violations.append(update["text"])
```

**Policy**: to avoid over-engineering, do not persist to `session-memory` or `decisions.md`. Keep it only in the Lead process's in-memory array and discard it at the end of the `/breezing` session (per the policy in the body of issue #87).

### Task assignment based on the dependency graph

When Plans.md has a Depends column (v2 format), run tasks according to the dependency graph:

1. Run **tasks whose Depends is `-`** first. If there are multiple independent tasks, they can be spawned in parallel
2. After each Worker completes, the Lead reviews → cherry-picks (see harness-work Phase B)
3. Once a dependency-source task is cherry-picked to main, run the tasks that depended on it next
4. Repeat until all tasks complete

> **Note**: "Worker completes → review → cherry-pick" for each task is sequential.
> Only the Worker-spawn part of independent tasks (Depends is `-`) can be parallelized.

## Orchestration

The Lead orchestrates Workers via the Task tool and instructs a Worker to fix with `SendMessage(to: agentId, message: "...")`.

## Related Skills

- `harness-work` — from a single task to team execution (the core)
- `harness-sync` — progress sync
- `harness-review` — code review (auto-launched within breezing)
