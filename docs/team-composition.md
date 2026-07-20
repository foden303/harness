# Team Composition

The Harness standard team has 5 roles.
Even when adding more implementation teammates, the responsibility boundaries of these 5 roles do not change.

## Structure diagram

```text
Lead
├── Worker x 1..3
├── Advisor x 0..1
├── Reviewer x 1
└── Scaffolder x 0..1
```

## spawn permissions

- Only the Lead spawns teammates
- Workers do not spawn teammates
- Reviewers do not spawn teammates
- Scaffolders do not spawn teammates
- When a Worker wants to consult, it does not add a subagent; it returns `advisor-request.v1`

## role contract

| Role | subagent_type | Count | Tools used | Returns |
|------|---------------|----|------------|----------|
| Lead | Inside Execute skill | 1 | Agent, SendMessage, Bash | task breakdown, review verdict, main integration |
| Worker | `harness:worker` | 1..3 | Read, Write, Edit, Bash, Grep, Glob | implementation result or `advisor-request.v1` |
| Advisor | `harness:advisor` | 0..1 | Read, Grep, Glob | `advisor-response.v1` |
| Reviewer | `harness:reviewer` | 1 | Read, Grep, Glob | `review-result.v1` |

## How to decide the worker count

| Condition | Worker count |
|------|-----------|
| Target write files form 1 group, or files overlap | 1 |
| Target write files form 2 groups that do not overlap | 2 |
| Target write files form 3 or more groups that do not overlap | 3 |

Here a "group" means a set of writes that do not conflict even when combined into the same commit.
Splitting so that 2 workers write the same file is prohibited.

### Explicit spawn on Opus 4.8

Opus 4.8 (host = Lead) tends to spawn fewer subagents by default.
So treat the worker count conditions above as an **explicit spawn trigger**.

- When there are 2 independent write groups, collapsing them into 1 worker because "doing it directly is faster" is wrong in this case. For 2 groups spawn 2 workers, for 3 or more spawn 3 workers.
- Conversely, for work that completes in 1 file or serially dependent tasks, the Lead proceeds directly without adding subagents.

## Re-spawn on Worker stall (CC 2.1.113+)

When either of the following 2 conditions is met, the Lead re-spawns the same task **at most once**.

- Plans.md `cc:WIP` state is not updated for more than **10 minutes** (600 seconds)
- CC itself emits a stall log (`subagents stalling mid-stream fail after 10 minutes`)

If the same condition recurs after re-spawn, escalate. This does not affect how the worker parallelism is decided; stall detection is the Lead's responsibility only. For details see "Stall detection — 2-layer defense" in [`agents/worker.md`](../agents/worker.md).

## Execution flow

1. The Lead breaks down the task and creates a `sprint-contract`
2. The Lead spawns workers
3. Workers implement, run preflight, verify, and prepare commits
4. A Worker returns `advisor-request.v1` only when it hits a consultation condition
5. The Lead calls the Advisor and returns `advisor-response.v1` to the same Worker
6. When a Worker returns a result, the Lead runs review
7. Only on `APPROVE` does the Lead integrate into main

## review loop

| Condition | Lead's action |
|------|-------------|
| `review-result.v1.verdict == APPROVE` | cherry-pick and commit to main |
| `review-result.v1.verdict == REQUEST_CHANGES` | return a fix request to the same Worker |
| A fix requires a decision on spec, Plans, API, permissions, billing, or migration | take a user decision via AskUserQuestion. Do not fix by guessing |

The fix loop runs at most 3 times.
It does not enter a 4th iteration; instead the Lead escalates the task.

`harness-review` uses TeamAgent Debate when needed.
This does not increase the Reviewer's verdict authority; it is material-gathering to clash the read-only viewpoints of the Spec Agent / Plans Agent / Regression Agent / Skeptic Agent.
The final verdict is still issued by the Reviewer based on `review-result.v1` and a clear pass line.

## Fixed SendMessage pattern

When the Lead returns fixes to a Worker, use the following syntax.

```text
SendMessage(
  to: "{worker_agent_id}",
  message: "Please fix the following critical/major findings:\n\n{issues}\n\nAfter fixing, run git commit --amend and return completion."
)
```

## parallel worktree root

Before fanning out parallel Workers, the Lead creates worktrees from **a single base SHA** using
`scripts/spawn-parallel.sh <task...>`. The root is
`.harness-worktrees/` only (under `task-<name>`, branch `task/<name>`). Do not confuse it with `.claude/worktrees/`,
which is dedicated to CC live agents. For the canonical convention see [Worktree Root Discipline in `spec.md`](../spec.md).

The **contents** of the worktree (who writes shared files, no `VERSION` bump, regenerating artifacts on trunk)
follow [Shared File Discipline](../.claude/rules/shared-file-discipline.md). In the sprint contract, the Lead assigns
one owner each to `Plans.md` / `CHANGELOG.md` / `spec.md` (or no owner → the Lead appends at integration time),
and workers do not touch files outside their assignment.

## Integrating into main during breezing

Workers commit in a worktree or feature branch.
After `APPROVE`, the Lead pulls it into main with the following 2 commands.

```bash
git cherry-pick --no-commit {worktree_commit_hash}
git commit -m "feat: {task_description}"
```

Until the Lead integrates into main, a Worker does not update Plans.md to `cc:done`.

## Advisor boundaries

- The Advisor returns only `PLAN | CORRECTION | STOP`
- The Advisor does not return `APPROVE | REQUEST_CHANGES`
- The Advisor does not edit code
- The Reviewer looks only at the final deliverable, not the advisor's proposal text
- The Phase 61 weak-supervision cue only adds to the Advisor's input information; it does not add response types or final verdict authority

## 2.1.111 precedence rules

- `/ultrareview` is a caller-side review entrypoint. The review artifact contract stays `review-result.v1`
- `--auto-mode` is an opt-in rollout. Do not make it a shipped default

## permission mode

Do not put `permissionMode` in plugin subagent frontmatter.
Because agent-local `permissionMode` is ignored for Claude Code plugin agents,
permissions are inherited from the parent session and plugin settings.

The safety boundary is guaranteed by the following layers.

- plugin-level hooks
- Go guardrails
- Worker preflight
- Reviewer verdict

`--auto-mode` is an opt-in for rollout.
Do not make it a default.

### Preserving background permission mode (CC 2.1.141+)

When a teammate is backgrounded via `/bg` / `←←` / `claude agents`,
CC 2.1.141 and later preserve the permission mode at launch (it does not revert to default).

- The Lead operates on the premise that the mode explicitly set with `claude agents --permission-mode <mode>`
  is maintained even after backgrounding.
- No re-injection of a breezing teammate's permission mode is needed.
  For the special launches previously handled with `--auto-mode`, CC itself guarantees mode preservation.
- Exception: even a teammate launched with `bypassPermissions` does not override
  `permissions.deny` / `autoMode.hard_deny` in `.claude-plugin/settings.json` (defense in depth is maintained).

### Dispatched session via `claude agents` (CC 2.1.142+)

When the Lead launches a dispatched background session with `claude agents --add-dir / --settings /
--mcp-config / --plugin-dir / --permission-mode / --model / --effort / --dangerously-skip-permissions`,
refer to the flag usage conditions in `docs/agent-view-policy.md`. Separation from the
teammate spawn workflow (breezing skill / Agent tool) is a prerequisite.

## Team size

- The standard is 3 to 5 teammates
- The usual Harness composition is `Worker 1..3 + Reviewer 1`
- Advisor and Scaffolder are added only when needed
