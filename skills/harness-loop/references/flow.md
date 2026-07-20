# harness-loop: wake-up flow details

The detailed version of `harness-loop`'s entry steps for each wake-up.
An implementation reference that complements the summary in SKILL.md.

---

## Entry steps per wake-up (detailed)

### Step 0: Resolve the plugin bundle root

`harness-loop` calls helper scripts under the plugin bundle root, not the host project's cwd.
Keep the target `Plans.md` and `.claude/state/...` on the host project side, and read only the scripts (the tools) from the plugin bundle.

```bash
resolve_harness_plugin_root() {
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/scripts" ]; then
        (cd "${CLAUDE_PLUGIN_ROOT}" && pwd -P)
        return 0
    fi

    if [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
        for candidate in "${CLAUDE_SKILL_DIR}/../.." "${CLAUDE_SKILL_DIR}/../../.."; do
            candidate_abs="$(cd "${candidate}" 2>/dev/null && pwd -P)" || continue
            if [ -f "${candidate_abs}/.claude-plugin/plugin.json" ] && [ -d "${candidate_abs}/scripts" ]; then
                printf '%s\n' "${candidate_abs}"
                return 0
            fi
        done
    fi

    echo "ERROR: cannot resolve Claude Harness plugin root. Set CLAUDE_PLUGIN_ROOT to the installed plugin bundle root." >&2
    return 1
}

HARNESS_PLUGIN_ROOT="$(resolve_harness_plugin_root)" || exit 1
```

- If `CLAUDE_PLUGIN_ROOT` is valid, use it with top priority
- If `CLAUDE_PLUGIN_ROOT` is absent, derive the distribution source from `CLAUDE_SKILL_DIR`
  - For a `skills/harness-loop` distribution, `${CLAUDE_SKILL_DIR}/../..`
  - For a `.agents/skills/harness-loop` mirror distribution, `${CLAUDE_SKILL_DIR}/../../..`
- Treat only candidates that have `scripts/` and `.claude-plugin/plugin.json` as the plugin root
- Do not use the host project cwd's `scripts/`

### Step 0.1: Lock to prevent multiple starts (idempotency guard (a))

```bash
LOCK_DIR=".claude/state/locks/loop-session.lock.d"
mkdir -p ".claude/state/locks"

# Atomic creation (fail immediately if it exists — avoids TOCTOU race)
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    existing=$(cat "${LOCK_DIR}/meta.json" 2>/dev/null || echo '{}')
    echo "ERROR: harness-loop is already running (lock dir exists: ${LOCK_DIR})" >&2
    echo "Lock contents: ${existing}" >&2
    echo "To force-clear, run: rm -rf ${LOCK_DIR}" >&2
    exit 10
fi

# Write lock metadata inside the lock directory
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
ARGS_STR="$*"
cat > "${LOCK_DIR}/meta.json" <<EOF
{
  "pid": $$,
  "session_id": "${SESSION_ID}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "args": "${ARGS_STR}"
}
EOF

# On exit (whether normal or abnormal), remove the lock
cleanup_loop_lock() {
    rm -rf "${LOCK_DIR}" 2>/dev/null || true
}
trap cleanup_loop_lock EXIT INT TERM
```

- `LOCK_DIR` is `.claude/state/locks/loop-session.lock.d` (a directory)
- `mkdir` is atomic, so no TOCTOU race occurs (even if 2 processes run simultaneously, only one succeeds)
- Lock metadata is written to `${LOCK_DIR}/meta.json`: JSON of `{"pid": <pid>, "session_id": <session>, "started_at": <ISO8601>, "args": "<args>"}`
- If an existing lock is present, stop immediately with an `already running` error (exit 10)
- Remove the lock on `EXIT` / `INT` / `TERM` (cleanup whether normal or abnormal)
- `rm -rf` is idempotent (safe to delete twice)

### Step 0.5: State consistency check (idempotency guard (b))

```bash
# At the start of a wake-up, run the lightweight consistency check in --quick mode
# If it fails, stop the loop immediately (protection against a broken Plans.md / uninitialized environment)
if bash "${HARNESS_PLUGIN_ROOT}/tests/validate-plugin.sh" --quick; then
    : # OK — continue
else
    echo "harness-loop: state consistency check failed — stopping the loop" >&2
    echo "Details: run bash \"${HARNESS_PLUGIN_ROOT}/tests/validate-plugin.sh\" --quick to check" >&2
    exit 1
fi
```

- `${HARNESS_PLUGIN_ROOT}/tests/validate-plugin.sh --quick` is lightweight and completes within a few seconds
- Check content: existence of `.claude/state/` / existence + v2 format of Plans.md / format of the sprint-contract
- Does not run the full validate (39 verification items)
- If this check fails when Plans.md is intentionally broken, the loop stops immediately

### Step 1: Read Plans.md first

```bash
# Extract cc:WIP / cc:TODO tasks and identify the task_id of the first task
grep -E "cc:(WIP|TODO)" Plans.md | head -1
```

- If a `cc:WIP` task remains: it may have been interrupted in the previous cycle → get its task_id and continue
- If a `cc:TODO` task exists: get its task_id as the next target task
- If neither exists: **all tasks complete** → the loop ends normally

> **41.1.2 premise**: if `plans-watcher.sh` is protecting Plans.md with flock,
> read Plans.md within that flock scope.
> Before the 41.1.2 release, direct reads without flock are allowed.

### Step 2: Check for and generate the sprint-contract

```bash
CONTRACT_PATH=".claude/state/contracts/${task_id}.sprint-contract.json"

if [ ! -f "${CONTRACT_PATH}" ]; then
    # Contract not generated → generate it
    node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" "${task_id}"

    # Step 2.5: promote draft → approved (only on first generation)
    # generate-sprint-contract.js initializes with review.status == "draft", so
    # always promote before ensure-sprint-contract-ready.sh (which requires approved)
    bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh" "${CONTRACT_PATH}" \
      --check "wake-up auto-approval (for harness-loop, confirm DoD from the reviewer's perspective)" \
      --approve
fi
```

- Check whether `.claude/state/contracts/${task_id}.sprint-contract.json` exists
- If absent, generate with `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" ${task_id}`
  (※ a .sh→.js rename is planned in 41.5.1, but for now the existing name is called via node)
- **Right after generation (first time only)**: promote `draft` → `approved` with `enrich-sprint-contract.sh --approve`
  - `generate-sprint-contract.js` initializes with `review.status == "draft"`
  - `ensure-sprint-contract-ready.sh` (the next Step 3) accepts only `approved`
  - Putting it inside the `if [ ! -f ... ]` block prevents applying it to an existing contract (already approved in the previous cycle)
- After generation, reuse `${CONTRACT_PATH}` in the subsequent steps

### Step 3: Contract readiness check

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh" "${CONTRACT_PATH}"
```

- Confirm the sprint-contract's `review.status == "approved"`
- If an unapproved contract remains, stop with an error

### Step 4: Reload the resume pack

```
Step 4. Reload harness-mem resume-pack:
  Call the mcp__harness__harness_mem_resume_pack tool.
  Required argument:
    - project: the current project name (following the implementation example of the existing session-init skill.
              e.g., get the repo root with `basename $(git rev-parse --show-toplevel)` and pass it)
  optional: session_id (when resuming from a previous session)

  Example (pseudocode):
    resume_pack = mcp__harness__harness_mem_resume_pack(
      project="harness",
      session_id=<session_id of the previous checkpoint>
    )
```

Right after a fresh-context wake-up, the previous cycle's memory is lost.
Re-inject the following via a `harness-mem resume-pack`-equivalent operation:

- `decisions.md` — architecture decisions
- `patterns.md` — reusable patterns
- `session-state` — the previous work state
- The most recent cycle's `checkpoint` — what was completed

> **Note**: run the resume pack reload after Step 3 (contract readiness check).
> Skipping it risks re-implementing the previous cycle's deliverables.

### Step 4.5: Advisor consult (only when needed)

The loop proceeds executor-driven, and the advisor is called only when needed.
Fix the timing to consult to the following 3:

1. Before the first execution of a high-risk task
2. After the same cause fails twice in a row
3. Right before a stop due to `PIVOT_REQUIRED`

```bash
TRIGGER_HASH="${task_id}:${reason_code}:$(normalize_error_signature "${summary_or_risk}")"

if ! advisor_trigger_seen "${TRIGGER_HASH}"; then
    RESPONSE_FILE=$(
        bash "${HARNESS_PLUGIN_ROOT}/scripts/run-advisor-consultation.sh" \
          --request-file ".claude/state/harness-loop/${task_id}.${reason_code}.advisor-request.json" \
          --response-file ".claude/state/harness-loop/${task_id}.${reason_code}.advisor-response.json"
    )
    DECISION=$(jq -r '.decision' "${RESPONSE_FILE}")
fi
```

- `PLAN` / `CORRECTION`: re-run with the advice inserted at the top of the next executor prompt
- `STOP`: stop the loop and record it in `run.json`'s `last_decision`, `last_trigger`, `last_model`
- Consult the same `trigger_hash` only once
- The consultation count per task is at most 3

### Step 5: Run one task cycle

Spawn `harness:worker` via the Agent tool:

> **Important**: specify `"harness:worker"`, not `"harness-work"`, for `subagent_type`.
> `harness-work` is a skill, not an agent. The real agents are `worker` / `reviewer`.
> Specifying `"harness-work"` makes the Agent spawn fail and the loop stops at the first Worker launch.

```python
worker_result = Agent(
    subagent_type="harness:worker",  # ← the worker agent (not a skill)
    prompt="""
    Task: ${task_id}
    DoD: <extract from Plans.md>
    contract_path: ${CONTRACT_PATH}
    mode: breezing
    When done: return the commit hash, branch, and change summary.
    """,
    isolation="worktree",
    run_in_background=false  # foreground execution (wait until complete)
)
# worker_result: { commit, branch, worktreePath, files_changed, summary }
```

Because the Worker operates with `mode: breezing`:
- It only commits on the feature branch and does not touch main
- The changes are stored in `worktreePath`
- The Lead (harness-loop) handles review → cherry-pick in Step 5.5/5.6

> **Implementation note**: `Bash("harness-work --breezing")` is a viable alternative, but
> going through the Agent tool makes context separation clearer and is easier to debug.

### Step 5.5: Run the Lead review

The Lead reviews the commit returned by the Worker:

```bash
# Get the diff (target the commit inside the worktree)
diff_text=$(git -C "${worker_result.worktreePath}" show "${worker_result.commit}")

# ── (a) Internal Reviewer review: target the Worker's worktree directory ────────────
# If the Lead is in the main repo dir, the diff becomes empty (risk of an unconditional APPROVE).
# Target the Worker's worktreePath so the correct diff is reviewed.
#
# If worktreePath is empty or identical to the main repo (environment where worktree isolation doesn't work),
# fall back to the Lead dir.

MAIN_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
WORKER_PATH="${worker_result.worktreePath:-}"

if [ -n "${WORKER_PATH}" ] && [ "${WORKER_PATH}" != "${MAIN_REPO_ROOT}" ]; then
    # The internal Reviewer agent reviews the actual diff of the Worker feature branch and
    # writes its review-result.v1 verdict to review-output.json in the Worker worktree dir.
    REVIEW_OUTPUT_PATH="${WORKER_PATH}/review-output.json"
else
    # Fallback: Lead dir (environment where worktree isolation doesn't work)
    REVIEW_OUTPUT_PATH="$(pwd)/review-output.json"
fi
# → the internal Reviewer agent writes its verdict to the file indicated by REVIEW_OUTPUT_PATH
# Everything after this must use $REVIEW_OUTPUT_PATH (do not directly reference the relative path "review-output.json")

# ── (b) reviewer_profile branch (check the sprint-contract's review.reviewer_profile) ──
# Use the value of CONTRACT_PATH already determined in Step 2/3 as-is (do not overwrite it here)
if command -v jq >/dev/null 2>&1; then
    REVIEWER_PROFILE=$(jq -r '.review.reviewer_profile // "static"' "${CONTRACT_PATH}" 2>/dev/null || echo "static")
else
    REVIEWER_PROFILE="static"
fi

case "${REVIEWER_PROFILE}" in
    runtime)
        # Run the runtime verification commands, which may overwrite the verdict
        # Run run-contract-review-checks.sh inside the Worker's worktree (the test environment is inside the worktree)
        # Important: run-contract-review-checks.sh's stdout is the artifact's "file path" (not a JSON payload)
        if [ -n "${WORKER_PATH}" ] && [ "${WORKER_PATH}" != "${MAIN_REPO_ROOT}" ]; then
            RUNTIME_ARTIFACT_PATH=$(
                cd "${WORKER_PATH}" && bash "${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh" "${CONTRACT_PATH}" 2>/dev/null
            ) || RUNTIME_ARTIFACT_PATH=""
        else
            RUNTIME_ARTIFACT_PATH=$(
                bash "${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh" "${CONTRACT_PATH}" 2>/dev/null
            ) || RUNTIME_ARTIFACT_PATH=""
        fi

        # If empty (script failed), treat as DOWNGRADE_TO_STATIC
        if [ -z "${RUNTIME_ARTIFACT_PATH}" ]; then
            RUNTIME_ARTIFACT_PATH=""
            RUNTIME_VERDICT="DOWNGRADE_TO_STATIC"
        else
            # If it is a relative path, make it absolute based on WORKER_PATH (or the Lead dir)
            if [[ "${RUNTIME_ARTIFACT_PATH}" != /* ]]; then
                if [ -n "${WORKER_PATH}" ] && [ "${WORKER_PATH}" != "${MAIN_REPO_ROOT}" ]; then
                    RUNTIME_ARTIFACT_PATH="${WORKER_PATH}/${RUNTIME_ARTIFACT_PATH}"
                else
                    RUNTIME_ARTIFACT_PATH="$(pwd)/${RUNTIME_ARTIFACT_PATH}"
                fi
            fi

            # Read the verdict from the artifact file
            if command -v jq >/dev/null 2>&1; then
                RUNTIME_VERDICT=$(jq -r '.verdict // "DOWNGRADE_TO_STATIC"' "${RUNTIME_ARTIFACT_PATH}" 2>/dev/null || echo "DOWNGRADE_TO_STATIC")
            else
                RUNTIME_VERDICT=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('verdict','DOWNGRADE_TO_STATIC'))" "${RUNTIME_ARTIFACT_PATH}" 2>/dev/null || echo "DOWNGRADE_TO_STATIC")
            fi
        fi

        if [ "${RUNTIME_VERDICT}" = "REQUEST_CHANGES" ]; then
            # Runtime verification failed → overwrite the verdict to REQUEST_CHANGES
            # Pass the runtime artifact to write-review-result.sh (do not use the static review-output.json)
            EFFECTIVE_VERDICT="REQUEST_CHANGES"
            REVIEW_RESULT_INPUT="${RUNTIME_ARTIFACT_PATH}"
        elif [ "${RUNTIME_VERDICT}" = "DOWNGRADE_TO_STATIC" ]; then
            # No runtime verification command → use the static verdict as-is
            EFFECTIVE_VERDICT=""  # → read from REVIEW_OUTPUT_PATH
            REVIEW_RESULT_INPUT="${REVIEW_OUTPUT_PATH}"
        else
            EFFECTIVE_VERDICT="${RUNTIME_VERDICT}"
            REVIEW_RESULT_INPUT="${RUNTIME_ARTIFACT_PATH}"
        fi
        ;;
    browser)
        # Generate the artifact the browser reviewer uses downstream
        # The browser artifact is a PENDING_BROWSER scaffold. The actual browser run is handled by the reviewer agent.
        # The review-result verdict stays static (not PENDING_BROWSER).
        bash "${HARNESS_PLUGIN_ROOT}/scripts/generate-browser-review-artifact.sh" "${CONTRACT_PATH}" 2>/dev/null || true
        EFFECTIVE_VERDICT=""  # → read from REVIEW_OUTPUT_PATH (use the static verdict)
        REVIEW_RESULT_INPUT="${REVIEW_OUTPUT_PATH}"
        ;;
    *)
        # static (default): use the internal Reviewer verdict as-is
        EFFECTIVE_VERDICT=""
        REVIEW_RESULT_INPUT="${REVIEW_OUTPUT_PATH}"
        ;;
esac

# If EFFECTIVE_VERDICT is not set, read from REVIEW_OUTPUT_PATH (absolute path)
if [ -z "${EFFECTIVE_VERDICT}" ]; then
    if command -v jq >/dev/null 2>&1; then
        EFFECTIVE_VERDICT=$(jq -r '.verdict // "REQUEST_CHANGES"' "${REVIEW_OUTPUT_PATH}" 2>/dev/null || echo "REQUEST_CHANGES")
    else
        EFFECTIVE_VERDICT=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('verdict','REQUEST_CHANGES'))" "${REVIEW_OUTPUT_PATH}" 2>/dev/null || echo "REQUEST_CHANGES")
    fi
fi

# Normalize and save the review-result
# REVIEW_RESULT_INPUT is the runtime artifact path on runtime REQUEST_CHANGES, otherwise REVIEW_OUTPUT_PATH
# This ensures a runtime REQUEST_CHANGES propagates correctly to the pretooluse-guard (addresses finding 4)
bash "${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh" "${REVIEW_RESULT_INPUT}" "${worker_result.commit}"
```

**Verdict decision**:

| verdict | Action |
|---------|----------|
| `APPROVE` | Go to Step 5.6 (cherry-pick) |
| `REQUEST_CHANGES` | Go to the fix loop (up to 3 times) |

**Fix loop (on REQUEST_CHANGES)**:

```python
review_count = 0
latest_commit = worker_result.commit
worker_id = worker_result.agentId
# Read max_iterations only when the sprint-contract exists. If absent, 3 (backward compat)
MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3

while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    # Instruct the Worker to fix (resume via SendMessage)
    SendMessage(to=worker_id, message=f"Findings: {issues}\nFix and amend")
    updated_result = wait_for_response(worker_id)
    latest_commit = updated_result.commit
    diff_text = git("-C", worker_result.worktreePath, "show", latest_commit)
    verdict = reviewer_agent_review(diff_text)
    review_count += 1

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    # Escalate
    raise PivotRequired(f"Still REQUEST_CHANGES after {MAX_REVIEWS} fixes: {issues}")
```

### Step 5.6: APPROVE → cherry-pick to main

```bash
# Return to the trunk branch (the Worker works on a feature branch)
TRUNK=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
git checkout "${TRUNK}"

# Check that the feature branch commit is not yet merged into trunk (re-entry prevention)
if ! git merge-base --is-ancestor "${latest_commit}" HEAD; then
    git cherry-pick --no-commit "${latest_commit}"
    git commit -m "${task_title}"
fi

# ── (c) cleanup order: worktree remove → branch -D ────────────────────────────────
# While the feature branch is checked out in a worktree,
# `git branch -D` errors with "branch is checked out at <path>".
# Running worktree remove first lets branch -D work safely.
#
# Order:
#   1. cherry-pick → incorporate into main (git commit above done)
#   2. worktree remove (remove the worktree where the feature branch was checked out)
#   3. branch -D (removable now that the worktree is removed)

MAIN_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
WORKER_PATH="${worker_result.worktreePath:-}"

# Step 2: worktree remove
if [ -n "${WORKER_PATH}" ] && [ "${WORKER_PATH}" != "${MAIN_REPO_ROOT}" ]; then
    git worktree remove "${WORKER_PATH}" --force 2>/dev/null || true
fi

# Step 3: branch -D (safe after worktree remove)
if [ -n "${worker_result.branch}" ] && \
   [ "${worker_result.branch}" != "main" ] && \
   [ "${worker_result.branch}" != "master" ] && \
   [ "${worker_result.branch}" != "${TRUNK}" ]; then
    git branch -D "${worker_result.branch}" 2>/dev/null || true
fi
```

Update Plans.md:

```bash
# Update cc:WIP → cc:done [{hash}]
HASH=$(git rev-parse --short HEAD)
# Update the relevant task line in Plans.md
```

### Step 6: Plateau decision

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/detect-review-plateau.sh" ${current_task_id}
PLATEAU_EXIT=$?
# ※ current_task_id is the task_id identified in Step 1
```

| exit code | Meaning | Action |
|-----------|------|----------|
| `0` | `PIVOT_NOT_REQUIRED` | Continue |
| `1` | `INSUFFICIENT_DATA` | Continue (insufficient data) |
| `2` | `PIVOT_REQUIRED` | Insert the advisor exactly once. **Stop the loop** + escalate only on `STOP` or when the consultation quota is exhausted |

**Escalation message on PIVOT_REQUIRED**:

```
harness-loop: stopped by plateau detection (cycle {N}/{max})

Detected problem:
  {plateau details: output of detect-review-plateau.sh}

Options:
  1. Manually review the task content
  2. Re-run with `--pacing plateau` to extend the interval
  3. Skip the problem task and restart `/harness-loop`

Please check the current Plans.md state.
```

### Step 7: Cycle count check

```
cycles_completed += 1
if cycles_completed >= max_cycles:
    stop the loop
    print(f"harness-loop: stopping after {max_cycles} cycles")
    return
```

- default `max_cycles = 8`
- When `--max-cycles N` is specified, stop after N cycles

**Persisting the cycle count**:
- Embed the count in the `prompt` argument of `ScheduleWakeup`:
  ```
  /harness-loop all --max-cycles 8 --cycles-done {N} --pacing worker
  ```
- On wake-up, read `--cycles-done N` and restore the count

### Step 8: Record a checkpoint

```json
{
  "session_id": "<current session ID>",
  "title": "harness-loop cycle {N}/{max}: {task_completed}",
  "content": "cycle {N} complete. commit: {commit}. changes: {files_changed}. next: {next_task}"
}
```

Record to memory with the `harness_mem_record_checkpoint` tool.
It is automatically included in the next wake-up's resume pack.

### Step 9: Schedule the next wake-up

```
ScheduleWakeup(
    delaySeconds=<value corresponding to pacing>,
    prompt="/harness-loop <same arguments> --cycles-done {N}",
    reason="cycle {N}/{max} complete: {task_completed}"
)
```

**delaySeconds corresponding to pacing**:

| pacing | delaySeconds | Rationale |
|--------|-------------|---------|
| `worker` | 270 | Re-entry right after Worker completion (within 5 min cache warm) |
| `ci` | 270 | Wait assuming the shortest CI job completion |
| `plateau` | 1200 | 20 min cooldown period (avoid plateau) |
| `night` | 3600 | Overnight batch (max clamp value) |

> **Clamp constraint**: `ScheduleWakeup` clamps `delaySeconds` to `[60, 3600]` at runtime.
> Specifying below 60 rounds up to 60; above 3600 rounds down to 3600.
> All design values are within range, but be careful on future changes.

---

## Cycle stop condition matrix

| Condition | Cycle count | exit | Stop reason | User notification |
|------|-----------|------|---------|------------|
| `cycles >= max_cycles` | N (cap) | 0 | Normal cap | "stopping after {N} cycles" |
| `PIVOT_REQUIRED` | any | 2 | Plateau detected | Escalation details |
| No incomplete task | any | 0 | All tasks complete | Completion report |
| User cancel | any | - | Manual interruption | - |

---

## pacing selection guide

### Which pacing to use

```
What is the nature of the task?
│
├── Want to re-enter right after Worker completion
│     → worker (270s)
│
├── Need to wait for CI / tests to complete
│     → ci (270s)
│     ※ If CI takes more than 270s, adjust --pacing manually
│
├── Want to detect a plateau and space out the interval
│     → plateau (1200s)
│
└── Want to leave it overnight and check the next morning
      → night (3600s)
```

### When to change pacing

- **On first launch**: usually `worker` (default) is fine
- **When there is a lot of CI waiting**: switch to `--pacing ci`
- **After plateau detection**: consider auto-switching to `--pacing plateau` (see Step 5)
- **Overnight idle**: launch with `--pacing night` and go to sleep

---

## ScheduleWakeup constraint details

### Runtime constraint on delaySeconds

```
ScheduleWakeup(delaySeconds=X)
  → X < 60  → clamp to 60
  → X > 3600 → clamp to 3600
  → 60 <= X <= 3600 → used as-is
```

### Relationship with cache TTL

ScheduleWakeup's cache TTL is **5 min (300s)**.

- `worker` / `ci` at 270s is within 5 min → wake up with a cache-warm state
- `plateau` at 1200s and `night` at 3600s wake up after the cache expires
  → Step 2 (resume pack reload) is especially important

### Passing arguments through the prompt

How to carry the cycle count to the next wake-up:

```bash
# Embed the current cycle count in the prompt
NEXT_PROMPT="/harness-loop ${SCOPE} --max-cycles ${MAX_CYCLES} --cycles-done ${CYCLES_DONE} --pacing ${PACING}"

ScheduleWakeup(
    delaySeconds=${DELAY},
    prompt="${NEXT_PROMPT}",
    reason="cycle ${CYCLES_DONE}/${MAX_CYCLES} complete"
)
```

---

## Reference: verification results of spike 41.0.0

This design is based on the empirical results of spike 41.0.0:

- `ScheduleWakeup`: confirmed to exist as an internal tool. delay [60, 3600] clamp, cache 5min TTL
- `/loop`: confirmed to exist as CC dynamic mode. sentinel `<<autonomous-loop-dynamic>>`
- `harness_mem_record_checkpoint`: confirmed to exist (schema: session_id / title / content required)

If these premises change, update this file.
