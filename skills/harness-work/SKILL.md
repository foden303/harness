---
name: harness-work
description: "HAR: Execute Plans.md tasks from single task to full parallel team run. Trigger: implement, execute, do everything, breezing, team run, parallel. Do NOT load for: planning, review, release, setup."
description-en: "HAR: Execute Plans.md tasks from single task to full parallel team run. Trigger: implement, execute, do everything, breezing, team run, parallel. Do NOT load for: planning, review, release, setup."
kind: workflow
purpose: "Execute Plans.md tasks end to end"
trigger: "implement, execute, do everything, breezing, team run, parallel"
shape: workflow
role: executor
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "Monitor"]
argument-hint: "[all] [task-number|range] [--parallel N] [--no-commit] [--resume id] [--breezing] [--auto-mode] [--tdd-bypass]"
user-invocable: true
effort: high
---

# Harness Work

The unified execution skill for Harness.
It consolidates the following legacy skills:

- `work` — Implement Plans.md tasks (automatic scope detection)
- `impl` — Feature implementation (task-based)
- `breezing` — Fully automated team run
- `parallel-workflows` — Parallel workflow optimization
- `ci` — Recovery from CI failures

## Quick Reference

| User input | Mode | Behavior |
|------------|--------|------|
| `/harness-work` | **auto** | Auto-decides by task count (see below) |
| `/harness-work all` | **auto** | Run all incomplete tasks in auto mode |
| `/harness-work 3` | solo | Run only task 3 immediately |
| `/harness-work --parallel 5` | parallel | Run in parallel with 5 workers (forced) |
| `/harness-work --breezing` | breezing | Force team execution |
| `/harness-work 3 --plan roadmap` | solo | Run task 3 from the named plan `roadmap` |

## Execution Mode Auto Selection (when no flag is given)

When no explicit mode flag (`--parallel`, `--breezing`) is present,
select the optimal mode based on the number of target tasks:

| Number of target tasks | Auto-selected mode | Reason |
|-------------|---------------|------|
| **1 task** | Solo | Minimal overhead. Direct implementation is fastest |
| **2–3 tasks** | Parallel (Task tool) | The threshold where worker separation starts to pay off |
| **4 or more tasks** | Breezing | Three-way separation of Lead coordination + Worker parallelism + independent Reviewer is effective |

### Rules

1. **An explicit flag always overrides auto mode**
   - `--parallel N` → Parallel mode (regardless of task count)
   - `--breezing` → Breezing mode (regardless of task count)

## Orchestration wiring

The Breezing team implements with native Claude Workers spawned via the Agent
tool (`agents/worker.md`), and the Lead aggregates their results. That is the
whole dispatch path.

An alternate in-process orchestrator (`harness work --team`, with the opt-in
`HARNESS_TEAM_HIERARCHY=sublead` Producer/Sub-Lead hierarchy and the
`HARNESS_REVIEW_ITERATE` loop) existed before v1.0.0. It drove work through
per-backend companion shell scripts, which were removed along with the
non-Claude backends, so the path could only exit 127. It was deleted rather
than left in place as a switch that silently fails; parallelism and
review-iteration both live in the skill layer above.

## Options

| Option | Description | Default |
|----------|------|----------|
| `all` | Target all incomplete tasks | - |
| `N` or `N-M` | Task number/range | - |
| `--parallel N` | Number of parallel workers | auto |
| `--sequential` | Force serial execution | - |
| `--plan NAME` | Use the named plan from `plans/manifest.json` | active/default |
| `--no-commit` | Suppress automatic commit | false |
| `--resume <id\|latest>` | Resume the previous session. After a long gap, using `/recap` alongside is recommended | - |
| `--breezing` | Team execution of Lead/Worker/Reviewer | false |
| `--no-tdd` | Skip the TDD phase | false |
| `--tdd-bypass` | Bypass TDD enforcement only in emergencies. Record `HARNESS_TDD_BYPASS_REASON` or an explicit reason in the audit | false |
| `--no-simplify` | Skip Auto-Refinement | false |
| `--auto-mode` | Explicitly enable the Harness-side Auto Mode rollout. Distinct from `--enable-auto-mode`, which became unnecessary in CC 2.1.111 | false |

## Progressive Disclosure

First read only the entry point, auto selection, and stop conditions in this body.
Read the details only when you need them.

| Detail | Reference |
|---|---|
| Concrete steps for Solo / Parallel / Breezing | `references/execution-modes.md` |
| Reviewer agent, AI Residuals, correction loop | `references/review-loop.md` |
| Generating Solo / Breezing completion reports | `references/completion-report.md` |
| Reticketing on test/CI failure | `references/failure-reticketing.md` |
| Criteria for the spec SSOT check | `docs/plans/spec-ssot.md` |

### Important stop conditions

- Stop when `Plans.md` is in the old format and DoD / Depends / Status cannot be read.
- When the spec affects an implementation decision but the project spec SSOT is not found, create/update the spec SSOT first, then implement.
- Do not proceed to implementation when a sprint-contract is required but not ready.
- Do not mark complete while a critical / major review finding remains.
- Do not resolve by weakening tests, skipping them, or loosening expected values to match the implementation.
- Call helper scripts from `${HARNESS_PLUGIN_ROOT}/scripts/`, not the host project's `scripts/`.
- When multiple Plans.md exist, do not switch plans within a single run. If needed, start a new run with an explicit `--plan NAME`.

> **Token Optimization (v2.1.69+)**: For lightweight tasks that do not involve git operations,
> you can reduce prompt tokens by enabling `includeGitInstructions: false` in the plugin settings.

> **Prompt Cache (CC 2.1.108+)**: For longer implementations or work that uses `--resume` heavily,
> prefer `ENABLE_PROMPT_CACHING_1H=1`.

## Scope dialog (when no argument is given)

```
/harness-work
How far should I go?
1) Next task: the next incomplete task in Plans.md → run as Solo
2) Everything (recommended): complete all remaining tasks → auto mode selection by task count
3) By number: enter task numbers (e.g., 3, 5-7) → auto mode selection by count
```

With an argument, run immediately (skip the dialog):
- `/harness-work all` → all tasks, auto mode selection
- `/harness-work 3-6` → 4 tasks, so Breezing is auto-selected

## Effort level control (Opus 4.8 / v2.1.111+)

Effort is the official knob for choosing the model's reasoning intensity. It has 4 levels `low(○)/medium(◐)/high(●)/xhigh`,
and you can reset to the default with `/effort auto` (`max` was removed in v2.1.72; `xhigh` is its successor).

In Opus 4.8, thinking is off by default and effort is the main lever for reasoning depth (effort has a larger impact than in any prior Opus).
If you observe "shallow reasoning," do not work around it in the prompt — raise the effort.
Therefore, to strengthen complex tasks we **retire the approach of injecting a free-text marker (the old `ultrathink`) into the spawn prompt**
and standardize on **choosing the Worker spawn's effort tier from a complexity score**.
This is consistent with `docs/model-routing-policy.md` (do not infer effort from free text) and
condition 5 of `.claude/rules/opus-4-7-prompt-audit.md` (`xhigh` is chosen by the caller).

### Multi-factor scoring

At task start, sum up the following scores.

| Factor | Condition | Score |
|------|------|--------|
| File count | 4 or more files changed | +1 |
| Directory | Includes core/, guardrails/, security/ | +1 |
| Keyword | Includes architecture, security, design, migration | +1 |
| Failure history | Agent memory has a failure record for the same task | +2 |
| Explicit designation | The PM template has `effort: high` / `effort: xhigh` (the old `ultrathink` is also accepted for compatibility) | +3 (auto-adopted) |

### How to decide the effort tier (do not inject)

Decide the effort tier from the score as an **escalation signal** (do **not** write a marker string like `ultrathink` into the spawn prompt).
The only two levers to apply are:

- **session `/effort`**: before entering a batch of complex tasks, the host sets `/effort high` / `/effort xhigh` (a reliable lever that works per session).
- **worker frontmatter**: the `effort` in `agents/worker.md` (default `medium`) is the floor. Because CC's Agent / Task spawn API does not expose a per-spawn effort setting, there is no mechanism to raise effort per individual worker. Record the score in `task_complexity_note` of `worker-report.v1`, giving the Lead material for deciding whether to raise the session effort.

| Score | code-risk (includes core/guardrails/security/architecture/migration) | effort tier |
|--------|-----------------------------------|-------------|
| 0-2 | n/a | `medium` (Worker frontmatter default unchanged) |
| ≥ 3 | no | `high` |
| ≥ 3 | yes | `xhigh` |

The same logic applies in breezing mode as well (harness-work manages it in one place).
Since the Worker is Sonnet 4.6, `xhigh` is effectively downgraded to `high`, but raising the tier itself is still effective (`docs/effort-level-policy.md`).

## Execution mode details

### Harness helper script root

Helper scripts bundled with Harness must always be called from the plugin bundle root, not from the target project's `scripts/`.

```bash
HARNESS_PLUGIN_ROOT="${HARNESS_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ] && [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
  probe="$(cd "${CLAUDE_SKILL_DIR}" && pwd)"
  while [ "$probe" != "/" ] && [ ! -d "$probe/scripts" ]; do
    probe="$(cd "$probe/.." && pwd)"
  done
  [ -d "$probe/scripts" ] && HARNESS_PLUGIN_ROOT="$probe"
fi
```

The subsequent `node "${HARNESS_PLUGIN_ROOT}/scripts/..."` / `bash "${HARNESS_PLUGIN_ROOT}/scripts/..."` calls assume this resolved root.

### Solo mode (auto-selected for 1 task)

1. Load Plans.md and identify the target task
   - **If Plans.md does not exist**: auto-call `harness-plan create --ci` → generate Plans.md and continue
   - If the header lacks DoD / Depends columns: `Plans.md is in the old format. Please regenerate it with harness-plan create.` → **Stop**
   - **If the conversation contains tasks not recorded in Plans.md**: extract the requirements from the recent conversation context and auto-append them to Plans.md as `cc:TODO`
     - Extraction logic: detect action verbs ("add ~", "fix ~", "implement ~") in the user's utterances
     - When appending, conform to the v2 format (Task / Content / DoD / Depends / Status)
     - After appending, show the user "The following was appended to Plans.md" (prompt with a 5-second timeout, default: continue)
1.5. **Task background check** (30 seconds):
   - From the task's "Content" and "DoD", infer and display the **purpose** (the problem this task solves) in one line
   - Use `git grep` / `Glob` to infer and display the **scope of impact** (files/modules the change reaches)
   - If confident in the inference: proceed directly to implementation (no flow delay)
   - If not confident in the inference: ask the user just one question ("Is this understanding correct?")
1.6. **Spec SSOT preflight**:
   - Look for an existing project spec SSOT (e.g., `docs/spec/00-project-spec.md`, `docs/ARCHITECTURE.md`, `docs/HANDOFF.md`, `docs/oem/PROJECT_COMPASS.md`, `docs/specs/`)
   - If the task changes product behavior / API / data model / permissions / billing / integrations / tenant boundaries and no spec exists, create `docs/spec/00-project-spec.md`
   - If the spec is stale or contradicts the task, update the spec before implementation
   - For typo / format / dependency bump / docs-only / behavior-preserving refactor, record the skip reason and continue
   - Include `spec_path` or `spec_skip_reason` in the context passed to Worker / Reviewer
1.7. **Load plan-time pre-approvals**:
   - At the start of the run, if `.claude/state/plan-preapprovals.json` exists, read it and validate against `templates/schemas/plan-preapproval.v1.json` (helper: `bash "${HARNESS_PLUGIN_ROOT}/scripts/plan-preapproval.sh" validate .claude/state/plan-preapprovals.json`).
   - Treat only items matching the target task's `scope.phase` / `scope.task` and with `decision: approved` as pre-declared items for this run.
   - For a pre-declared `secret-read`, reflect it per-run into `runtimefloor.secretAllow` of the project config `.harness.config.json` via `bash "${HARNESS_PLUGIN_ROOT}/scripts/plan-preapproval.sh" apply-secret-allow "$PROJECT_ROOT"` before proceeding to implementation. This is a procedure that connects to the project-config-based runtime floor of 108.2; it is not a broad, permanent env allow.
   - Pass pre-declared external sends / destructive operations to the worker briefing and sprint-contract context as "plan-approved," and do not emit an AskUserQuestion during work for the same items.
   - Confirmation happens only once at plan-approval time. Reduce `AskUserQuestion` triggered by pre-declared items during work to zero.
   - Any unplanned secret-read / external send / destructive operation not in the record stops via the runtime floor / ask as usual. Do not silently add undeclared items to the allowlist.
2. Update the task to `cc:WIP`
3. **TDD phase** (when there is no `[skip:tdd]` and a test framework exists):
   a. Create the test file first (Red)
   b. Confirm it fails
   c. Leave FAIL evidence in `.claude/state/tdd-red-log/<task-id>.jsonl` via `bash "${HARNESS_PLUGIN_ROOT}/scripts/log-tdd-red.sh"`. In environments where the script is unavailable, attach the literal failing test output to the worker-report's `self_review` evidence
   d. When using `--tdd-bypass`, explicitly set `HARNESS_TDD_BYPASS=1` and `HARNESS_TDD_BYPASS_REASON="<reason>"`, and record the reason for skipping TDD in the sprint-contract / worker-report
4. Generate `sprint-contract.json` with `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" <task-id>`
5. Add Reviewer-perspective enrichment with `bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh"`, and confirm it is approved with `bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh"`
6. **Advisor consult (only when needed)**:
   - For high-risk tasks (`needs-spike` / `security-sensitive` / `state-migration`), consult once before the first run
   - If the same cause fails twice in a row, consult before entering the third attempt
   - When plateau detection (stuck detection) returns `PIVOT_REQUIRED`, consult once before stopping and escalating to the user
   - Receive the consult result as `advisor-response.v1`, and treat `PLAN` as reorganizing the approach, `CORRECTION` as a local fix, and `STOP` as immediate escalation
   - Consult only once per `trigger_hash`. The consult budget per task is at most 3 times
7. Implement code via the local / native Read/Write/Edit/Bash path (Green)
8. Auto-Refinement with `/simplify` (can be skipped with `--no-simplify`)
9. **Automatic review stage** (see "Review loop"):
   - Run review with the internal Reviewer agent
   - If `reviewer_profile` in `sprint-contract.json` is `runtime`, run `bash "${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh"`
   - On REQUEST_CHANGES: fix based on the findings → re-review (`MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3`)
   - On APPROVE, move to the next step. A self-check alone does not finalize completion
10. Normalize and save the review artifact with `bash "${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh"` (for the browser profile, pass `--browser-result`, and when `browser_verdict == PENDING_BROWSER`, adopt the static verdict)
11. Auto-commit with `git commit` (can be skipped with `--no-commit`)
12. Update the task to `cc:done` (with the commit hash)
   - Get the latest commit hash (7-char short form) with `git log --oneline -1`
   - Update Plans.md Status in the form `cc:done [a1b2c3d]`
   - If there is no commit (with `--no-commit`), just `cc:done` without a hash
13. **Rich completion report** (see "Completion report format")
14. **Automatic re-planning on failure** (only on test/CI failure):
    - Check the test run results
    - If it failed: save the fix task proposal to state and add it to Plans.md via the approval command (see "Automatic reticketing of failed tasks")
    - If it succeeded: proceed to the next task

### Parallel mode (auto-selected for 2–3 tasks / forced with `--parallel N`)

Run `[P]`-marked tasks in parallel across N workers.
When explicitly specified with `--parallel N`, use this mode regardless of task count.
Separate with git worktrees when writes to the same file would conflict.
Each task spawns a native Worker.

### Breezing mode (auto-selected for 4+ tasks / forced with `--breezing`)

Run as a team with role separation of Lead / Worker / Advisor / Reviewer.

**Permission policy**:
- The current shipped default is `bypassPermissions`
- Treat `--auto-mode` as an opt-in rollout flag for compatible parent sessions
- Do not write the undocumented `autoMode` value into `permissions.defaultMode` or agent frontmatter `permissionMode`

> **CC v2.1.69+**: Since nested teammates are forbidden by the platform,
> do not add verbose nesting-prevention wording to Worker/Reviewer prompts.

```
Lead (this agent)
├── Worker (task-worker agent) — implementation
├── Advisor (harness:advisor) — direction advice
└── Reviewer (code-reviewer agent) — review
```

**Phase A: Pre-delegate (preparation)**:
1. Load Plans.md and identify the target tasks
2. Analyze the dependency graph and decide the execution order (the Depends column)
3. Read `.claude/state/plan-preapprovals.json`, and if it exists, validate it with `bash "${HARNESS_PLUGIN_ROOT}/scripts/plan-preapproval.sh" validate .claude/state/plan-preapprovals.json`
4. Pass the `decision: approved` items of the target tasks to the worker briefing. For `secret-read`, reflect per-run into `runtimefloor.secretAllow` of the project config via `bash "${HARNESS_PLUGIN_ROOT}/scripts/plan-preapproval.sh" apply-secret-allow "$PROJECT_ROOT"`. Do not stop midway for pre-declared items, and do not emit an `AskUserQuestion` triggered by the same items
5. Any unplanned secret-read / external send / destructive operation not in the record stops via the runtime floor / ask as usual
6. Effort scoring for each task (effort tier decision — high/xhigh)
7. Generate `sprint-contract.json` with `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js"`
8. Add the Reviewer perspective with `bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh"`, and stop if unapproved with `bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh"`

**Phase B: Delegate (Worker spawn → Advisor when needed → review → cherry-pick)**:

Run the following **sequentially** for each task (in dependency order):

```
for task in execution_order:
    # B-1. Generate the sprint-contract
    contract_path = bash("node \"${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js\" {task.number}")
    contract_path = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh\" {contract_path} --check \"Verify DoD from a reviewer's perspective\" --approve")
    bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh\" {contract_path}")

    # B-2. Worker spawn (foreground, worktree-isolated)
    # The Agent tool return value includes agentId — used with SendMessage in the correction loop
    Plans.md: task.status = "cc:WIP"  # Update on start (untouched tasks stay cc:TODO)

    # Propagate universal violations even when running /harness-work repeatedly and sequentially
    # (assume universal_violations = [] is initialized on the first run)
    briefing_header = ""
    if universal_violations:
        briefing_header = (
            "🚨 Universal violations already detected in this session (do not repeat):\n"
            + "\n".join(f"- {v}" for v in universal_violations)
            + "\n\n"
        )

    worker_result = Agent(
        subagent_type="harness:worker",
        prompt=briefing_header + "Task: {task.Content}\nDoD: {task.DoD}\ncontract_path: {contract_path}\nmode: breezing",
        isolation="worktree",
        run_in_background=false  # Run in the foreground → wait until the Worker completes
    )
    worker_id = worker_result.agentId  # Keep for SendMessage
    # worker_result includes {commit, worktreePath, files_changed, summary}

    # B-3. Only when the Worker returns an advice request does the Lead call the Advisor
    if worker_result.type == "advisor-request.v1":
        advisor_result = Advisor(
            prompt=worker_result.request_json
        )
        worker_result = SendMessage(
            to=worker_id,
            message="advisor-response.v1: {advisor_result}"
        )

    # B-3.5. self_review gate (before Reviewer spawn, verified mechanically by the Lead)
    # The Worker's worker-report.v1 must have the active self_review rules complete, all verified=true and evidence non-empty
    # When tdd.enforce.enabled=true and tdd_required=true, `tdd-red-evidence-attached` is also required as an active rule
    # If even one has verified=false or evidence=="", do not spawn the Reviewer; send it back to the Worker
    self_review_failures = 0
    MAX_SELF_REVIEW_RETRIES = 2  # The Lead escalates on the 3rd time (retries=2)
    while True:
        unverified = [
            r for r in worker_result.self_review
            if (not r.get("verified")) or (not r.get("evidence"))
        ]
        if not unverified:
            break  # All rules verified → proceed to B-4 (actual review)
        self_review_failures += 1
        if self_review_failures > MAX_SELF_REVIEW_RETRIES:
            # Still unverified items on the 3rd time → escalate to the Lead
            Plans.md: task.status = "cc:TODO"  # Revert to not-started
            raise EscalationError(f"self_review still unverified after 3 send-backs (rules: {[u['rule'] for u in unverified]})")
        # Send back to the Worker (do not spawn the Reviewer)
        SendMessage(
            to=worker_id,
            message=f"self_review has unverified rules: {[u['rule'] for u in unverified]}. Fill each rule's evidence with actual command output or literal test results, and when TDD is required, attach .claude/state/tdd-red-log/<task-id>.jsonl or literal failing test output, then set verified=true and amend"
        )
        worker_result = wait_for_response(worker_id)

    # B-4. The Lead runs the review
    diff_text = git("-C", worker_result.worktreePath, "show", worker_result.commit)
    verdict = reviewer_agent_review(diff_text)
    profile = jq(contract_path, ".review.reviewer_profile")
    review_input = "review-output.json"
    if profile == "runtime":
        review_input = bash("cd {worker_result.worktreePath} && bash \"${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh\" {contract_path}")
        runtime_verdict = jq(review_input, ".verdict")
        if runtime_verdict == "REQUEST_CHANGES":
            verdict = "REQUEST_CHANGES"
        elif runtime_verdict == "DOWNGRADE_TO_STATIC":
            pass  # No runtime validation command → use the static verdict as-is
    browser_result = ""
    if profile == "browser":
        # Reuse route / browser_mode / execution_instructions from the browser artifact to launch the browser runner.
        browser_artifact = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/generate-browser-review-artifact.sh\" {contract_path}")
        browser_result = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/browser-review-runner.sh\" {browser_artifact}")
        browser_verdict = jq(browser_result, ".browser_verdict")
        if browser_verdict == "REQUEST_CHANGES":
            verdict = "REQUEST_CHANGES"
        elif browser_verdict == "APPROVE" and verdict != "REQUEST_CHANGES":
            verdict = "APPROVE"
        # When browser_verdict == PENDING_BROWSER, keep the static verdict
    # When review_input is DOWNGRADE_TO_STATIC, use the static review result
    if review_input != "review-output.json" and jq(review_input, ".verdict") == "DOWNGRADE_TO_STATIC":
        review_input = "review-output.json"  # Fall back to the static review result
    bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh\" {review_input} {latest_commit} --browser-result {browser_result}")

    # B-5. Correction loop (on REQUEST_CHANGES, up to the contract's max_iterations)
    # The Worker completed in the foreground but can be resumed with SendMessage
    # (CC: SendMessage(to: agentId))
    review_count = 0
    # Read max_iterations only when the sprint-contract exists. Otherwise 3 (backward compat)
    MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3
    latest_commit = worker_result.commit
    while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
        SendMessage(to=worker_id, message="Findings: {issues}\nFix and amend")
        # Worker fixes → amend → returns the updated commit hash
        updated_result = wait_for_response(worker_id)
        latest_commit = updated_result.commit
        diff_text = git("-C", worker_result.worktreePath, "show", latest_commit)
        verdict = reviewer_agent_review(diff_text)
        review_count++

    # B-6. APPROVE → cherry-pick onto trunk (via the feature branch)
    # Assume the Worker's Branch Guard kept trunk HEAD unmoved and the commit is on the feature branch
    if verdict == "APPROVE":
        TRUNK=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
        git checkout "$TRUNK"  # safety: no-op if already on trunk
        # Check whether the feature branch's commit is already on trunk (fallback if Branch Guard failed)
        if git("merge-base", "--is-ancestor", latest_commit, "HEAD"):
            pass  # Already on trunk — no cherry-pick needed (re-entry guard)
        else:
            git cherry-pick --no-commit {latest_commit}  # feature branch → trunk
            git commit -m "{task.Content}"
        # Remove the Worker's worktree, then delete the feature branch
        if worker_result.worktreePath:
            git worktree remove {worker_result.worktreePath} --force
        if worker_result.branch and worker_result.branch not in ["main", "master"] and worker_result.branch != TRUNK:
            git branch -D {worker_result.branch}
        Plans.md: task.status = "cc:done [{hash}]"
        # auto-checkpoint recording (idempotency guard (c))
        # Call right after rewriting Plans.md. Even on failure, fail-open (|| true) does not stop the loop
        HASH=$(git rev-parse --short HEAD)
        REVIEW_RESULT_PATH=".claude/state/review-results/${task.number}.review-result.json"
        bash "${HARNESS_PLUGIN_ROOT}/scripts/auto-checkpoint.sh" \
            "${task.number}" "${HASH}" "${contract_path}" "${REVIEW_RESULT_PATH}" \
            || true  # fail-open: continue even where harness-mem is not running
    else:
        → escalate to the user

    # B-7. Progress feed
    print("📊 Progress: Task {completed}/{total} done — {task.Content}")
```

### Advisor Protocol (common to all modes)

The Advisor is neither an "implementer" nor a "reviewer."
It steps in only when stuck, as a consultant to help the executor decide the next step.

1. The Worker does not add generic subagents; it returns `advisor-request.v1` only when needed
2. The Lead calls the advisor exactly once
3. The Advisor returns one of `PLAN` / `CORRECTION` / `STOP`
4. The Lead returns that advice to the same Worker to continue
5. The Reviewer looks only at the final deliverable. It does not issue APPROVE / REQUEST_CHANGES on the advisor's reply

### Advisor in Solo mode

In a solo run, the parent session doubles as the Lead.
That is, it takes the form of "implement it yourself, consult the advisor yourself, and send it to an independent review at the end."

- The consult conditions are the same as loop / breezing
- The consult budget is also the same: at most 3 times per task
- `STOP` stops on the spot and escalates to the user for a decision
- The review artifact gate is not skipped

### Sprint Contract

A `sprint-contract` is a small contract file that expresses "what makes this task pass" so that both machines and humans read it with the same meaning.
The default save location is `.claude/state/contracts/<task-id>.sprint-contract.json`.

```bash
node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" 32.1.1
```

The output includes the following.

- `checks`: verification items broken down from the DoD
- `non_goals`: what will not be done this time
- `runtime_validation`: validation commands such as test, lint, typecheck
- `browser_validation`: UI flow verification items the browser reviewer should leave
- `browser_mode`: `scripted` or `exploratory`
- `route`: which of `playwright` / `agent-browser` / `chrome-devtools` the browser reviewer uses
- `risk_flags`: `needs-spike`, `security-sensitive`, `ux-regression`, etc.
- `reviewer_profile`: `static`, `runtime`, `browser`

**Required metadata (lane / stage / evidence)** — the sprint contract input passed to Worker / Scaffolder / Reviewer:

| Field | Meaning | Example |
|-----------|------|-----|
| `spec_path` | Path to the root `spec.md` (or nearest sub-spec) | `spec.md`, `docs/spec/00-project-spec.md` |
| `lane` | The task's lane taxonomy | `fast`, `gate`, `release` |
| `stage` | The current stage of the 5-stage gate | `research`, `plan`, `impl`, `review`, `closeout` |
| `research_evidence` | Link / commit / file of the research result | `docs/research/phase-72-evidence.md`, commit hash |
| `tdd_red_log` | RED evidence for `[tdd:required]` tasks (commit hash or log path) | `.claude/state/tdd-red-log/72.1.3.jsonl`, `abc1234` |
| `review_artifact` | Review verdict and findings | `{ verdict: "APPROVE", findings: [...] }` |
| `pr_closeout` | Closeout artifact (base/head refs + evidence pack) | `{ base_ref, head_ref, evidence_pack }` |

When running `generate-sprint-contract.js`, the Lead loads `spec_path` / `lane` / `stage` into the contract from the Plans metadata, and appends `research_evidence` after research completes. After TDD Red, load `tdd_red_log`; after review, `review_artifact`; after PR closeout, `pr_closeout`.

**TDD completion gate**: For `[tdd:required]` tasks, do not treat as complete unless the sprint contract has `tdd_red_log` or an explicit `skip_tdd_reason` (this applies to `cc:done` update, cherry-pick, and PR closeout alike).

### PR Closeout (after review APPROVE)

After review APPROVE, build the PR title/body from the evidence pack with `bash "${HARNESS_PLUGIN_ROOT}/scripts/harness-pr-closeout.sh"`. **The default is a `dry-run` preview** (`git push` / `gh pr create` happen only via the `push` subcommand plus confirmation or `--yes`).

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/harness-pr-closeout.sh" build \
  --base origin/main --head "$(git branch --show-current)" \
  --evidence .claude/state/evidence-pack.json \
  --out .claude/state/pr-payload.json
bash "${HARNESS_PLUGIN_ROOT}/scripts/harness-pr-closeout.sh" dry-run --payload .claude/state/pr-payload.json
# Explicit push only (confirmation required, can be skipped with --yes):
bash "${HARNESS_PLUGIN_ROOT}/scripts/harness-pr-closeout.sh" push --payload .claude/state/pr-payload.json
```

Automatic push / PR / merge from the `harness-review` path is forbidden (read-only boundary). In a detached HEAD state, a branch must be created before `push`.

**The lightening boundary for the fast lane**: `lane: fast` may skip the full review, but it does not skip the unknown data contract of `not_observed != absent` or the focused checks (the DoD breakdown of `runtime_validation` / `checks`).

**Phase C: Post-delegate (integration / report)**:
1. Aggregate the commit logs of all tasks
2. Output the **rich completion report** (the Breezing template in "Completion report format")
3. Final check of Plans.md (whether all tasks are `cc:done`)

## Responding to CI failures

When CI fails:

1. Check the logs and identify the error
2. Apply the fix
3. Stop the auto-fix loop after 3 failures from the same cause
4. Escalate with a summary of the failure log, attempted fixes, and remaining open questions

## Automatic reticketing of failed tasks

When a test/CI fails after task completion, auto-generate a fix task proposal and, after approval, reflect it into Plans.md:

### Trigger conditions

| Condition | Action |
|------|----------|
| Test fails after `cc:done` | Save the fix task proposal to state and wait for approval |
| CI failure (fewer than 3 times) | Apply the fix and increment the failure count |
| CI failure (3rd time) | Present the fix task proposal + escalate |

### Automatic generation of the fix task

1. Classify the failure cause (syntax_error / import_error / type_error / assertion_error / timeout / runtime_error)
2. Save the fix task proposal to `.claude/state/pending-fix-proposals.jsonl`:
   - Number: original task number + `.fix` suffix (e.g., `26.1.fix`)
   - Content: `fix: [original task name] - [failure cause category]`
   - DoD: tests/CI pass
   - Depends: original task number
3. When the user sends `approve fix <task_id>`, add it to Plans.md as `cc:TODO`
4. Discard the proposal with `reject fix <task_id>`. When there is only one pending item, you can also respond with `yes` / `no`

## Review loop

The quality verification stage that runs automatically after implementation completes (after step 5).
It applies uniformly **across all modes** (Solo / Parallel / Breezing).
In Parallel mode, each Worker runs the same loop as step 10 (accepting external review).

### Review execution

The internal Reviewer agent performs the review.

### APPROVE / REQUEST_CHANGES criteria

Give the reviewer the following threshold criteria and have it decide the verdict using **these criteria only**.
Improvement suggestions outside the criteria are returned as `recommendations` but do not affect the verdict.

| Severity | Definition | Effect on verdict |
|--------|------|-----------------|
| **critical** | Security vulnerability, data loss risk, possibility of a production outage | Even one → REQUEST_CHANGES |
| **major** | Breakage of existing functionality, a clear contradiction with the spec, test failure | Even one → REQUEST_CHANGES |
| **minor** | Naming improvement, missing comments, style inconsistency | Does not affect the verdict |
| **recommendation** | Best-practice suggestion, future improvement idea | Does not affect the verdict |

> **Important**: When there are only minor / recommendation items, **always return APPROVE**.
> A "nice-to-have improvement" is not a reason for REQUEST_CHANGES.

### AI Residuals scan

Keep the HEAD at task start as `BASE_REF`, and make the diff against that ref the review target.

```bash
# Record the base ref at task start (run before the Step 2 cc:WIP update)
BASE_REF=$(git rev-parse HEAD)
```

Run the AI Residuals scan with `bash "${HARNESS_PLUGIN_ROOT}/scripts/review-ai-residuals.sh"`,
and decide the final verdict combined with the Reviewer agent result.

```bash
# AI Residuals scan (can run in parallel with the review)
AI_RESIDUALS_JSON="$(bash "${HARNESS_PLUGIN_ROOT}/scripts/review-ai-residuals.sh" --base-ref "${BASE_REF}" --include-untracked 2>/dev/null || echo '{"tool":"review-ai-residuals","scan_mode":"diff","base_ref":null,"include_untracked":true,"files_scanned":[],"untracked_files_scanned":[],"summary":{"verdict":"APPROVE","major":0,"minor":0,"recommendation":0,"total":0},"observations":[]}')"
```

### Internal Reviewer agent

```
Agent tool: subagent_type="reviewer"
prompt: "Please review the following changes. Criteria: critical/major → REQUEST_CHANGES; minor/recommendation only → APPROVE. diff: {git diff ${BASE_REF}}"
```

The Reviewer agent runs the review safely as Read-only (Write/Edit/Bash disabled).

### Correction loop (on REQUEST_CHANGES)

```
review_count = 0
# Read max_iterations only when the sprint-contract exists. Otherwise 3 (backward compat)
contract_path = get_sprint_contract_path()  # e.g., .claude/state/contracts/<task-id>.sprint-contract.json
MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3

while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    1. Analyze the review findings (critical / major only)
    2. Implement a fix for each finding
    3. Run the review again (same criteria, same priority)
    review_count++

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    → escalate to the user
    → "I fixed MAX_REVIEWS times, but the following critical/major findings remain" + show the findings list
    → wait for the user's decision (continue / abort)
```

### Application in Breezing mode

In Breezing mode, the **Lead** runs the review loop (see Phase B above):

1. The Worker implements and commits in the worktree → returns the result to the Lead
2. The Lead reviews with the Reviewer agent
3. REQUEST_CHANGES → the Lead instructs the Worker to fix via SendMessage → the Worker amends
4. After the fix, re-review (up to `MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3` times)
5. APPROVE → the Lead cherry-picks onto trunk (the default branch) → updates Plans.md to `cc:done [{hash}]`

## Completion report format

A visual summary output automatically at task completion (after `cc:done` + commit).
Its purpose is to convey the change and its impact even to non-experts.

### Template

```
┌─────────────────────────────────────────────┐
│  ✓ Task {N} done: {task name}                 │
├─────────────────────────────────────────────┤
│                                              │
│  ■ What was done                             │
│    • {change 1}                               │
│    • {change 2}                               │
│                                              │
│  ■ What changes                              │
│    Before: {old behavior}                     │
│    After:  {new behavior}                     │
│                                              │
│  ■ Changed files ({N} files)                 │
│    {file path 1}                              │
│    {file path 2}                              │
│                                              │
│  ■ Remaining work                            │
│    • Task {X} ({status}): {content}  ← Plans.md  │
│    • Task {Y} ({status}): {content}  ← Plans.md  │
│    ({M} incomplete tasks remain in Plans.md)  │
│                                              │
│  commit: {hash} | review: {APPROVE}           │
└─────────────────────────────────────────────┘
```

### Generation rules

1. **What was done**: auto-extracted from `git diff --stat HEAD~1` and the commit message. Keep technical terms to a minimum and start with a verb
2. **What changes**: infer Before/After from the task's "Content" and "DoD." Emphasize the change in user experience
3. **Changed files**: obtained from `git diff --name-only HEAD~1`. If more than 5 files, omit and show the count
4. **Remaining work**: list the `cc:TODO` / `cc:WIP` tasks in Plans.md. Make explicit whether they are recorded in Plans.md
5. **review**: show the review result (APPROVE / REQUEST_CHANGES → APPROVE)

### Reporting in Parallel mode

- **1 task** (when `--parallel` is forced): use the Solo template
- **Multiple tasks**: use the Breezing aggregate template (see below)

### Reporting in Breezing mode

Output all at once after all tasks complete. List each task in a simplified form (what was done + commit hash only),
and output an overall summary at the end (total changed file count + remaining work):

```
┌─────────────────────────────────────────────┐
│  ✓ Breezing done: {N}/{M} tasks              │
├─────────────────────────────────────────────┤
│                                              │
│  1. ✓ {task name 1}          [{hash1}]      │
│  2. ✓ {task name 2}          [{hash2}]      │
│  3. ✓ {task name 3}          [{hash3}]      │
│                                              │
│  ■ Overall changes                           │
│    {N} files changed, {A} insertions(+),     │
│    {D} deletions(-)                          │
│                                              │
│  ■ Remaining work                            │
│    {K} incomplete tasks remain in Plans.md   │
│    • Task {X}: {content}                      │
│                                              │
└─────────────────────────────────────────────┘
```

## Progress visualization (for non-engineers)

While tasks run, `harness-progress` summarizes the progress counts and drift alerts into a single HTML.
Because it is regenerated automatically by a PostToolUse hook, the requester can see the latest progress board without learning how to invoke it
(`posttool-progress-regen.sh` regenerates at most once per minute).

## Related skills

- `harness-plan` — plan the tasks to execute
- `harness-sync` — sync the implementation and Plans.md
- `harness-review` — review the implementation
- `harness-release` — version bump / release
- `harness-progress` — progress board HTML (for non-engineers, auto-regenerated during a run)
