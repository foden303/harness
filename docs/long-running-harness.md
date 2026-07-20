# Long-Running Task Execution Guide

This document is a practical guide for safely running **work that does not finish in a single pass** with Claude Code.
Here, a "long-running task" is work advanced incrementally using `/loop` and `ScheduleWakeup`.
This document is a deliverable of Phase 41.4.1.

Its scope is **operation within the same Phase 41 session**. Automatic re-entry across different hosts is out of scope at this stage.

Reference: [skills/harness-loop/SKILL.md](../skills/harness-loop/SKILL.md) / [skills/harness-loop/references/flow.md](../skills/harness-loop/references/flow.md) / [docs/CLAUDE-feature-table.md](CLAUDE-feature-table.md)

---

## 1. Grasp the big picture first

A long-running task advances by repeating these four steps.

1. Decide the one unit of work to do now
2. Implement or verify it in small pieces
3. Record the result as a checkpoint
4. Schedule the next wake-up

What matters here is **re-entering with a "fresh perspective" each time**.
Rather than dragging the previous conversation along as-is, you restart by re-injecting only the needed information via a resume pack.

### Mapping table across the 12 axes B1-B12

| Axis | What it decides | Handling in Harness |
|---|---|---|
| B1 | What you want to achieve | Read the target task and DoD in Plans.md |
| B2 | How far to go in one pass | Advance at 1 cycle = 1 task unit |
| B3 | Where to start | Use `/loop` as the entry point |
| B4 | How to resume | Schedule the next wake-up with `ScheduleWakeup` |
| B5 | What to carry over | Restore only the needed info with `harness-mem resume-pack` |
| B6 | How long to wait | Choose the interval with `pacing` |
| B7 | When to stop | Set an upper limit with `--max-cycles` |
| B8 | How to avoid collisions | Prevent duplicate launches with a lock and an idempotency guard |
| B9 | How to record progress | Record a checkpoint with `harness_mem_record_checkpoint` |
| B10 | Whether it's going well | Find stalls with plateau detection |
| B11 | How much is in scope | Phase 41 is limited to within the same session |
| B12 | What to watch out for | Understand the limits of `bypassPermissions` and Plans.md flock |

---

## 2. How to use `/loop` + `ScheduleWakeup`

`/loop` is the entry point that tells Claude Code the premise of "continuing the work."
`ScheduleWakeup` is the mechanism for scheduling the next resume time.

### Usage basics

```text
/loop all
/loop 41.1-41.3 --pacing ci
/loop all --pacing night
```

### Flow of one pass

1. Pick one next target task from `Plans.md`
2. Perform only the minimum work needed for that task
3. Leave a checkpoint
4. Schedule the next wake-up with `ScheduleWakeup`

### What the scheduling looks like

```text
ScheduleWakeup(
  delaySeconds=270,
  prompt="/harness-loop all --cycles-done 1 --pacing worker",
  reason="1 cycle complete. To move on to the next task"
)
```

`delaySeconds` is "how many seconds until you come back."
Too short is hectic; too long makes it easy to forget the previous flow.
In practice, keep it within the range of 60 to 3600 seconds.

---

## 3. How to choose a pacing preset

`pacing` sets how much to space out the next wake-up.

| pacing | delaySeconds | Suited for | In a word |
|---|---:|---|---|
| `worker` | 270 | Continuing right after the previous work | Standard setting |
| `ci` | 270 | Waiting on CI results | Keeps wait time short |
| `plateau` | 1200 | Progress tends to stall | Cools down a bit longer |
| `night` | 3600 | Running things in bulk overnight | The longest wait |

### How to think about the cache boundary

Claude Code has a "short-term cache" that briefly remembers the immediately preceding flow.
The 270 seconds of `worker` and `ci` is a length still likely to fit in this short-term cache.

On the other hand, `plateau` and `night` easily exceed the short-term cache, so it is safer to **always assume a resume pack**.
In other words, the longer the wait, the more the design leans toward "re-injecting the needed info" rather than "recalling it unaided."

### When to use the 1-hour cache

From Claude Code `2.1.108` onward, adding `ENABLE_PROMPT_CACHING_1H=1` lets you opt into a
**1-hour cache** that is longer than the usual 5-minute cache.

This suits cases where "you re-read nearly the same premise each time, but the next input tends to exceed 5 minutes."
For the long-running tasks covered in this document, it is especially compatible with the following situations.

1. `/harness-loop` inserts a wait after each cycle
2. The same premise is reused across `/resume` or `/continue`
3. A review or advisor consult is inserted, and you come back after more than 5 minutes

Conversely, if it's just a series of short round-trips of tens of seconds to a few minutes, the default 5-minute cache is enough.

### Criteria for choosing 1h vs 5m cache

| Decision axis | Choose 1h cache | 5m cache (default) is enough |
|--------|----------------|------------------------|
| Expected session length | **Exceeds 30 minutes** | Within 30 minutes |
| wake-up interval | `plateau` (1200s) or `night` (3600s) | `worker`/`ci` (270s) |
| Reuse of premise info | Reads nearly the same SKILL.md / Plans.md each cycle | Short round-trips where the premise changes each time |
| Target skill | Multi-task execution of `/breezing` / `/harness-loop` | One-off `/work` or dialogue |

**Decision rule**: if the session length is **expected to exceed 30 minutes**, choose the 1h cache. Otherwise the default 5-minute cache is enough.

opt-in procedure:

```bash
bash scripts/enable-1h-cache.sh
```

This command appends `ENABLE_PROMPT_CACHING_1H=1` to `env.local` (idempotent).
It does not change the global settings. If already set, it does nothing.

### Recommended adoption approach

In this repository, **it is not left on for all sessions**.
The reason is that although the 1-hour cache is convenient, it assumes added cost and tends to be overkill for short dialogues.

Instead, use a thin launch wrapper dedicated to long-running tasks.

```bash
bash scripts/claude-longrun.sh
```

You can pass arguments through directly.

```bash
bash scripts/claude-longrun.sh --resume
bash scripts/claude-longrun.sh --model claude-opus-4-6
```

This script simply launches `claude` with `ENABLE_PROMPT_CACHING_1H=1` set internally.
It does not change the global settings, so it does not extend the impact on normal work.

### env inheritance into child processes

When launching child processes (hook scripts, wrappers, or worktree runs),
you need to confirm whether `ENABLE_PROMPT_CACHING_1H` is inherited by the child process.

| Path | Inherited? | Note |
|------|------------|--------|
| A normal `bash` subprocess | Yes | A normal bash subprocess inherits the parent env |
| Parent process launched by `claude-longrun.sh` | Yes | The script exports internally before launching claude |
| When `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` is active | **May be scrubbed** | The design must not include `ENABLE_PROMPT_CACHING_1H` in the scrub-target env list |

Because `.claude-plugin/settings.json`'s `env.CLAUDE_CODE_SUBPROCESS_ENV_SCRUB="1"` is intended to sweep out contaminated environment variables from subprocesses,
env that controls Claude Code's own behavior, such as `ENABLE_PROMPT_CACHING_1H`, is preserved by design.
When adding a new hook script or wrapper, either explicitly preserve `export ENABLE_PROMPT_CACHING_1H`, or
implement it so that `env -i bash` does not strip the env.

---

## 4. wake-up count limit, lock, idempotency guard

A long-running task can, without you noticing, run the same processing twice.
To prevent this, it is protected in 3 layers.

### 4-1. Count limit

`--max-cycles` decides how many times to continue.
When the limit is reached, it stops there for the time being.

### 4-2. lock

To keep the same task from running twice at once, a lock is taken.
This repository uses `.claude/state/locks/loop-session.lock.d`.

The lock is a marker saying "something is already running here."
If a lock already exists, a new run stops.
This prevents contention from concurrent execution.

### 4-3. Idempotency guard

Idempotency is the property that doing the same operation twice does not break anything.
By inserting a light check like `tests/validate-plugin.sh --quick` first, you avoid forcing progress in a broken state.

Also, the lock is always cleaned up on exit.
Whether it exits normally or abnormally, this ensures the residue does not get in the way of the next run.

---

## 5. Plateau detection and golden fixtures

A plateau is a state where the work looks like it's progressing but is actually going around in the same place.
For example, it happens when you repeat the same fix over and over, or the reruns pile up even though no new decision-making material accrues.

### How to think about the threshold

The actual determination is read from the result of `scripts/detect-review-plateau.sh`.
Here, rather than "how many failures before stopping," the emphasis is on **whether new information is accruing**.

### What to make a fixture

Golden fixtures for preventing regressions are clearest to place under `tests/fixtures/`.
Grouping them into a long-running-task-specific bundle, like `tests/fixtures/long-running-harness/`, makes them easier to find.
For plateau-related cases in particular, it helps to pin down the following cases.

1. Cases where the failure reason is the same every time
2. Cases where the determination does not change even when conditions change
3. Cases that appear to be progressing but are actually stalled

A fixture is a sample of "this determination should stay the same going forward."
With it, when you later touch the logic, it's easier to confirm that stall detection isn't broken.

---

## 6. Scope of Phase 41

What Phase 41 covers is a **long-running task that completes within the same Claude Code session**.

The work is narrowed to the following 2 points.

1. Being able to safely re-enter within the current session
2. Being able to continue the same work across wake-ups

What it does not do is automatic re-entry across different hosts.
That is a scope for a future Phase 42 or later.

---

## 7. Known constraints

### Relationship with `bypassPermissions`

`/loop` is not a mechanism for granting more permissions.
It operates on the premise that the existing permission guards are in place.
In other words, even when using `bypassPermissions`, dangerous operations are not made unlimited.

For long-running tasks, it is actually more important to "not do strong things on your own."
Perform only the needed operations, at the needed timing, the needed number of times.

### Limits of Plans.md flock

`Plans.md` may be touched by multiple execution actors.
It is designed to queue turns via flock, but this is a **mechanism to keep the same file from being corrupted by simultaneous writes**, not a cure-all.

In particular, when another session or another process is reading at the same time, the visible state may be slightly behind.
So when reading `Plans.md`, hold the premise that "what is visible now may not be the latest," and judge together with the checkpoint and contract.

---

## 8. Quick links

- Execution flow details: [skills/harness-loop/references/flow.md](../skills/harness-loop/references/flow.md)
- Command entry point: [skills/harness-loop/SKILL.md](../skills/harness-loop/SKILL.md)
- Claude Code feature list: [docs/CLAUDE-feature-table.md](CLAUDE-feature-table.md)

> **Note (v4.2.0+)**: `HARNESS_WEBHOOK_URL` is set as an env variable. `harness.toml`'s `[telemetry] webhook_url` was removed (2026-04-18 dead config cleanup).
