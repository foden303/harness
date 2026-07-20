---
name: harness-loop
description: "Long-running task loop using /loop (Claude Code dynamic mode) and ScheduleWakeup to re-enter with fresh context on each wake-up. Internally invokes harness-work through Agent. Trigger: long-running, loop, wake-up, autonomous. Do NOT load for: one-shot task execution, review, release, planning."
description-en: "Long-running task loop using /loop (Claude Code dynamic mode) and ScheduleWakeup to re-enter with fresh context on each wake-up. Internally invokes harness-work through Agent. Trigger: long-running, loop, wake-up, autonomous. Do NOT load for: one-shot task execution, review, release, planning."
kind: workflow
purpose: "Re-enter long-running Plans.md execution with fresh context"
trigger: "long-running, loop, wake-up, autonomous"
shape: delegate
role: orchestrator
base: harness-work
pair: harness-sync
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Edit", "Bash", "Task", "ScheduleWakeup", "mcp__harness__harness_mem_resume_pack", "mcp__harness__harness_mem_record_checkpoint"]
argument-hint: "[all|N-M] [--max-cycles N] [--pacing worker|ci|plateau|night]"
user-invocable: true
---

# harness-loop

A meta-skill that combines `/loop` (CC dynamic mode) with `ScheduleWakeup` to
**re-enter and run a long-running task with fresh context on each wake-up**.

At each wake-up it invokes `harness-work --breezing` via Agent,
forming a re-enterable loop where 1 cycle = 1 task completed.

> **Long-session helpers (CC 2.1.108+)**:
> When a person returns, re-fetch a summary with `/recap` before looking at `/harness-loop status`.
> For operations with long absences or frequent re-entries, prefer `ENABLE_PROMPT_CACHING_1H=1`.

> **Recommended for long sessions (CC 2.1.108+)**:
> If a session is expected to exceed 30 minutes, after resolving the plugin bundle root run `bash "${HARNESS_PLUGIN_ROOT}/scripts/enable-1h-cache.sh"` to opt into the 1-hour prompt cache.

## Quick Reference

| Input | Behavior |
|------|------|
| `/harness-loop all` | Loop over all incomplete tasks (default: max 8 cycles) |
| `/harness-loop all --max-cycles 3` | Stop after 3 cycles |
| `/harness-loop 41.1-41.3 --pacing ci` | Run a task range with CI pacing |
| `/harness-loop all --plan roadmap` | Loop over the named Plans `roadmap` |
| `/harness-loop all --pacing night` | Overnight batch (3600s interval) |
| `/harness-loop status` | Check the status of a running runner |
| `/harness-loop stop` | Request a running runner to stop |

## Options

| Option | Description | Default |
|----------|------|----------|
| `all` | Target all incomplete tasks | - |
| `N-M` | Specify a task number range | - |
| `--plan NAME` | Use a named plan from `plans/manifest.json` | active/default |
| `--max-cycles N` | Maximum number of cycles | `8` |
| `--pacing <mode>` | Wake-up interval mode | `worker` (270s) |

### pacing value mapping

| pacing | delaySeconds | Use case |
|--------|-------------|------|
| `worker` | 270 | Right after Worker completion (cache warm within 5 min) |
| `ci` | 270 | Waiting for a short CI job |
| `plateau` | 1200 | 20 min (retry interval after plateau detection) |
| `night` | 3600 | Long overnight idle |

> **Constraint**: `ScheduleWakeup`'s `delaySeconds` is clamped to **[60, 3600]** at runtime.
> `worker` / `ci` at 270s and `night` at 3600s are within this range.
> `plateau` at 1200s is also within range. When specifying a value directly, always keep it between 60 and 3600 inclusive.

## Startup flow (entry per wake-up)

Detailed version: [`${CLAUDE_SKILL_DIR}/references/flow.md`](${CLAUDE_SKILL_DIR}/references/flow.md)

### Resolving the plugin bundle root

`harness-loop` calls helper scripts under the plugin bundle root, not the host project's cwd.
As an analogy, treat the workbench (host project) and the toolbox (plugin bundle) separately.

At the start of each wake-up, determine `HARNESS_PLUGIN_ROOT` in this order:

1. If `CLAUDE_PLUGIN_ROOT` exists and contains `scripts/`, use it
2. If `CLAUDE_PLUGIN_ROOT` is absent, derive the plugin bundle root from `CLAUDE_SKILL_DIR`
   - For a `skills/harness-loop` distribution, `${CLAUDE_SKILL_DIR}/../..`
   - For a `.agents/skills/harness-loop` mirror distribution, `${CLAUDE_SKILL_DIR}/../../..`
3. If neither resolves, stop and re-run after setting `CLAUDE_PLUGIN_ROOT` to the plugin bundle root

Keep `Plans.md` and `.claude/state/...` on the host project side.
Call only helper scripts from `${HARNESS_PLUGIN_ROOT}/scripts/...`.

In a repo with multiple Plans.md, specify `--plan NAME` explicitly when starting a long run.
The runner keeps the Plans file resolved at start across cycles, so it does not switch the active plan mid-run.

```
wake-up
  │
  ▼
[Step 0] Resolve the plugin bundle root into HARNESS_PLUGIN_ROOT
  Use CLAUDE_PLUGIN_ROOT if it is valid
  Otherwise derive the plugin bundle root from CLAUDE_SKILL_DIR
  ※ Do not reference the host project cwd's scripts/
  │
  ▼
[Step 1] Read Plans.md first
  Identify the first cc:WIP / cc:TODO task (get the task_id)
  ※ No incomplete task → end the loop (normal completion)
  │
  ▼
[Step 2] Check for and generate the sprint-contract
  Check whether .claude/state/contracts/${task_id}.sprint-contract.json exists
  If absent, generate with node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" ${task_id}
  Right after generation (first time only): bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh" <contract-path> \
    --check "wake-up auto-approval (for harness-loop, confirm DoD from the reviewer's perspective)" \
    --approve  ← promote draft → approved
  (Existing contracts are already approved, so skip)
  │
  ▼
[Step 3] Contract readiness check
  bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh" <contract-path>
  │
  ▼
[Step 4] Reload the resume pack
  harness-mem resume-pack (re-inject context)
  │
  ▼
[Step 4.5] Advisor consult (only when needed)
  Before the first execution of a high-risk task / after the 2nd failure of the same cause / right before a plateau,
  assemble `advisor-request.v1` and consult
  │
  ├── PLAN        → prepend the advice to the next executor prompt
  ├── CORRECTION  → re-run as a local-fix instruction
  └── STOP        → stop the loop on the spot and record the reason
  │
  ▼
[Step 5] Run one task cycle
  worker_result = Agent(
      subagent_type="harness:worker",  # the worker agent (not harness-work)
      prompt="Task: ${task_id}\nDoD: <extract from Plans.md>\ncontract_path: ${CONTRACT_PATH}\nmode: breezing",
      isolation="worktree",
      run_in_background=false
  )
  # worker_result: { commit, branch, worktreePath, files_changed, summary }
  │
  ▼
[Step 5.5] Run the Lead review
  diff_text = git show worker_result.commit
  verdict = reviewer_agent_review(diff_text)
  ※ See flow.md for details
  │
  ▼
[Step 5.6] APPROVE → cherry-pick to main / REQUEST_CHANGES → fix loop (up to the contract's max_iterations, default 3)
  APPROVE: git cherry-pick → update Plans.md to cc:done [{hash}] → delete the feature branch
  Still rejected after REQUEST_CHANGES x MAX_REVIEWS: escalate
  ※ See flow.md for details
  │
  ▼
[Step 6] Plateau decision
  bash "${HARNESS_PLUGIN_ROOT}/scripts/detect-review-plateau.sh" ${current_task_id}
  │
  ├── PIVOT_REQUIRED (exit 2)  → stop the loop + escalate to the user
  ├── INSUFFICIENT_DATA (exit 1)→ continue
  └── PIVOT_NOT_REQUIRED (exit 0)→ continue
  │
  ▼
[Step 7] Cycle count check
  │
  ├── cycles >= max_cycles → stop the loop (cap reached)
  │
  ▼
[Step 8] Record a checkpoint
  harness_mem_record_checkpoint(
      session_id, title, content=cycle result summary
  )
  │
  ▼
[Step 9] Schedule the next wake-up
  ScheduleWakeup(
      delaySeconds=<pacing value>,
      prompt="/harness-loop <same arguments>",
      reason="cycle {N}/{max} complete — to the next task"
  )
```

## Cycle stop conditions

| Condition | Stop type | Response |
|------|---------|------|
| `cycles >= max_cycles` | Normal stop (cap reached) | Report to the user |
| `PIVOT_REQUIRED` (exit 2) | Abnormal stop (escalation) | Ask the user to decide |
| No incomplete task | Normal stop (all complete) | Output a completion report |

When `--max-cycles 3` is specified, stop after 3 cycles.
By default (`--max-cycles 8`), stop after 8 cycles.

## Interim reports / Silence Policy

In a long-running loop, treat interim reports as "notifications when a judgment changes," not "heartbeats for reassurance."
Do not reply just because a transcript delta arrived; stay silent explicitly when nothing is needed.

Report these:

- Cycle completion, cap reached, all complete, blocked
- validation failure, review `REQUEST_CHANGES`, plateau, advisor `STOP`
- advisor / reviewer drift, contract readiness failure
- A summary when the user asks for `status`

May stay silent for these:

- Only a transcript delta increased, with no change in task / review / advisor state
- Only fine-grained stdout that remains in the log increased
- Waiting for pacing until the next wake-up

The default is "one final report per cycle."
However, an unanswered Advisor request, an unarrived Reviewer result, and a warning right before a plateau are reported with priority over the silence policy.

## Integration with /loop

Use this skill in combination with CC's `/loop` (dynamic mode).

When `/loop` is enabled, CC continues autonomous re-entry execution, and
at the end of each cycle it schedules the next wake-up by calling `ScheduleWakeup`.

`/loop` sentinel: `<<autonomous-loop-dynamic>>`

Since each wake-up starts with **fresh context**, it prevents context contamination from the previous cycle.
Reloading the resume pack via `harness-mem resume-pack` is required (Step 2).

## Checkpoint recording

`harness_mem_record_checkpoint` schema:

```json
{
  "session_id": "<session ID>",
  "title": "harness-loop cycle {N}/{max}: {task name}",
  "content": "one-line summary of cycle_result + commit hash"
}
```

## Advisor Strategy

The star of this skill is the executor; the advisor is called only when needed.
As an analogy, the owner usually self-drives and consults a veteran only at the hard parts.

The consultation conditions are fixed; do not use a natural-language "low confidence" judgment.

| Condition | Consult? |
|------|-----------|
| `needs-spike` / `security-sensitive` / `state-migration` | Yes |
| `<!-- advisor:required -->` | Yes |
| The 2nd failure of the same cause | Yes |
| Right before stopping due to a plateau | Yes |

The same trigger is consulted only once.
For that judgment, use `trigger_hash = task_id + reason_code + normalized_error_signature`.

## Related skills

- `harness-work` — the task-implementation skill run in each cycle
- `harness-plan` — planning the loop-target tasks
- `harness-review` — reviewing individual tasks
- `session-control` — session state management
