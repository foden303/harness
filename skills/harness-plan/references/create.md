# create subcommand — plan creation flow

Interview for ideas and requirements, and generate an executable Plans.md.

**Precedence**: root `spec.md` > sub-spec > Plans.md (the product contract is above the task ledger).

## Step 0: Check the conversation context

When requirements can be extracted from the immediately preceding conversation, confirm them:

> Choose how to create the plan:
> 1. From the preceding conversation — build the plan based on the brainstorm
> 2. From scratch — start from an interview

For "from the preceding conversation": extract the requirements / ideas / decisions and confirm them with the user.
After confirmation, skip to Step 3 (technical research).

## Step 1: Ask what to build

If there is no user input, ask:

> What are you building?
>
> e.g. reservation management system / blog site / task management app / API server
>
> A rough idea is OK!

## Step 2: Raise the resolution (max 3 questions)

> Tell me a bit more:
>
> 1. Who will use it? (just you? a team? the general public?)
> 2. Is there a service you want to reference?
> 3. How far will you build it? (MVP? full feature set?)

## Step 3: Planning quality check

Details: `references/planning-quality.md`

Do not drop the information the user hands over into Plans.md as-is.
When it includes an external product, a competitor, a spec proposal, an improvement idea, or comparison material, verify it via the latest information, existing specs, memory, and multi-perspective TeamAgent / subagent review, and turn only the elements that should be adopted into the task contract.
Planning that is not a one-off, minor task is treated as requiring TeamAgent or subagents.

Minimum checks:

- Latest information: prefer WebSearch / official docs / primary sources, and confirm key points across multiple sources
- Existing specs: check Plans.md, README, docs, CLAUDE.md, related skills, and tests
- Memory: when harness-mem / harness-recall / `.claude/agent-memory/` / `.claude/state/` are available, check them project-scoped and avoid reinventing the wheel
- Discussion: separate adoption value from risk with the Product / Architecture / Security / QA / Skeptic perspectives
- Quality foundation: for a plan with source code changes, check the `formatter_baseline`, and front-load a setup task if lint / formatter is unset
- Implementation plan validation: check product fit, security fit, and works in practice, and capture test / smoke / CI / review / release gates in the DoD
- Scoring: look at Product Fit, Evidence Strength, User Value, Implementation Feasibility, Regression Safety, Strategic Leverage, Security Safety, and Works In Practice out of 5

Do not read the `harness-mem` DB directly. If the search or a documented memory surface is unavailable, state "memory unchecked" explicitly.
When the Task tool is unavailable, state `subagents-not-used` explicitly and evaluate the same perspectives separately on your own.
Emit `team_validation_mode` as one of `not_required_lightweight` / `native` / `subagent` / `manual-pass` / `unavailable`.
For non-trivial planning, use one of `native` / `subagent` / `manual-pass`, and do not mark it Required while it is `unavailable`.
Product / Architecture / Security / QA / Skeptic are perspective names, not agent_type names.
The Security gate does not require actually reading `.env` or secrets.

For a small typo, format, README/CHANGELOG, or marker update only, this step may be handled lightly.

## Lane taxonomy / stage gate / unknown data contract

Fast / Gate / Release are **Plans metadata** (a tag at the start of the Content or DoD), not new skills.
The 5-column template is unchanged.

### Lane taxonomy

| Tag | When to use |
|-----|-------------|
| `[lane:fast]` | low-risk local work (refactor / docs / typo) |
| `[lane:gate]` | spec / workflow / mirror / guardrail / most feature work |
| `[lane:release]` | public artifact / version / tag / GitHub Release |

### Stage gate

Structure the planning output in the following 5 stages:

1. Validation / research — research evidence, state `unknown` data
2. Finalize the implementation plan — fix the lane tag + DoD
3. Implementation (TDD) — `[tdd:required]` / `[tdd:skip:<reason>]`
4. Review — put the review artifact into the DoD
5. PR closeout — evidence pack → PR body

### Unknown data contract

`not_observed != absent`. Failed search / unread file / missing fixture / API unavailable is **`unknown`**.
Assert non-existence only when confirmed by repo evidence.

### Lane examples (minimal samples)

`[lane:fast]`:

```markdown
| 1.1 | `[Docs]` `[lane:fast]` `[tdd:skip:docs-only]` fix CHANGELOG typo | diff confirmed, validate-plugin PASS | - | cc:TODO |
| 1.2 | `[Refactor]` `[lane:fast]` `[tdd:skip:behavior-unchanged]` rename a function (behavior unchanged) | all existing tests PASS | - | cc:TODO |
| 1.3 | `[Format]` `[lane:fast]` `[tdd:skip:style-only]` align markdown table columns | git diff --check PASS | - | cc:TODO |
```

`[lane:gate]`:

```markdown
| 2.1 | `[Contract]` `[lane:gate]` `[tdd:skip:docs-contract]` add an API contract to spec.md | rule stated in spec.md, git diff --check PASS | - | cc:TODO |
| 2.2 | `[Feature]` `[lane:gate]` `[tdd:required]` implement the status marker writer | writer tests PASS, legacy read compatible | 2.1 | cc:TODO |
| 2.3 | `[Guardrail]` `[lane:gate]` `[tdd:required]` update the protected path policy | guardrail tests PASS | 2.1 | cc:TODO |
```

`[lane:release]`:

```markdown
| 3.1 | `[Version]` `[lane:release]` `[tdd:skip:release-prep]` sync VERSION / plugin.json | sync-version.sh --check PASS | 2.2, 2.3 | cc:TODO |
| 3.2 | `[Release]` `[lane:release]` `[tdd:skip:release-automation]` tag + GitHub Release | harness-release complete, Release URL recorded | 3.1 | cc:TODO |
| 3.3 | `[Dependency]` `[lane:release]` `[tdd:skip:dependency-bump]` Dependabot major merge + main CI green | merge commit + main validate-plugin PASS | - | cc:TODO |
```

## Step 4: Technical research (WebSearch)

Do not ask the user; Claude Code researches and proposes.

```
WebSearch:
- "{{project type}} tech stack 2025"
- "{{similar service}} architecture"
```

## Step 4.4: spec.md / Plans.md dual-source check

Plans.md is the task contract that fixes "what should be done."
The root `spec.md` is the product contract that fixes "what is correct."
Do not mix the two. Treat `/harness-plan create` not as a Plans.md generation command, but as the surface that returns the co-required planning output for the spec.md product contract and the Plans.md task contract.
Precedence stays `spec.md > sub-spec > Plans.md`.

The output of `/harness-plan create` is always a set of these 2:

1. `Spec delta` or `Spec skip reason`
2. `Plans.md` task generation

Read the root `spec.md` every time. If the implementation decision could drift, update the root `spec.md` before creating Plans.md.
Do not make the user write the spec from scratch. The `Spec delta` / `Spec skip reason` is generated by Harness; the consumer only approves or amends it.
The agent drafts the minimal delta from the existing spec, repo evidence, memory, tests, and input requirements, and surfaces options only when the judgment splits.

### Conditions to create/update the spec source of truth

- User-visible behavior is added or changed
- It decides an API, data model, permissions, billing, external integration, or tenant boundary
- There are multiple implementation options where the choice changes product behavior
- Past or current conversation shows implementation drift from spec ambiguity
- Plans.md has a task, but the project's correctness conditions are not documented

### Conditions where it can be skipped

- Typo / format / lint only
- Dependency bump only
- README / CHANGELOG only
- docs-only / mechanical task
- A narrow refactor with no behavior change
- The correct answer is clear from an existing spec and tests

Do not omit the `Spec skip reason` even when skipping.
Even for docs-only / mechanical tasks, leave the skip reason in the task context / sprint contract.

### Save location

The top priority is the root `spec.md`.
Only when the consumer repo has no root `spec.md`, update an existing project-level spec as a fallback.
If there is neither a root `spec.md` nor an existing project spec, create:

```text
docs/spec/00-project-spec.md
```

The first spec can be short. At minimum, include Purpose, Users And Workflows, Core Rules, Data And Contracts, Non-Goals, Open Decisions, and Links.

Details: `docs/plans/spec-ssot.md`

## Step 4.6: lint / formatter baseline check

For a plan with source code changes, check the lint / formatter baseline before creating implementation tasks.
This is not a "cleanup task"; it is a gate to first build a foundation for Yes/No quality confirmation after implementation.

What to check:

- JavaScript / TypeScript: the `lint` / `format` scripts in `package.json`, and ESLint / Prettier / Biome / Oxlint / dprint config or dependency
- Python: config for Ruff / Black / isort / mypy, etc. in `pyproject.toml`
- Go: `gofmt` / `go test` / `go vet` / a lint-equivalent CI command
- Rust: `cargo fmt` / `cargo clippy` / `cargo test`
- Existing CI: quality commands in `.github/workflows`, `scripts/ci/*`, `Makefile`, etc.

Leave `formatter_baseline` in the output:

```text
formatter_baseline: configured | missing | not_applicable | unknown
formatter_baseline_evidence: [files / commands examined]
formatter_baseline_action: none | add_setup_task | skip_with_reason | spike
```

If it is unset and includes source code changes, add a setup task before the Plans.md implementation tasks.
The setup task's DoD is that "config / script / validation command are in place, and a broad bulk reformat is explicitly out of scope."
Do not install packages during planning. harness-work performs the installation work as a setup task.

Conditions where it can be skipped:

- docs-only / markdown-only / changelog-only
- An existing lint / formatter / CI command exists and sufficiently covers the languages touched by this change
- When adoption is impossible due to consumer repo constraints. In that case, leave `formatter_baseline_action: spike` or a skip reason

## Step 5: Extract the feature list

Extract a concrete feature list from the requirements.

Example: for a reservation management system
- User registration/login
- Reservation calendar display
- Create/edit/cancel a reservation
- Admin dashboard
- Email notifications
- Payment feature

## Step 5.5: optional brief generation

Attach a brief only when needed. A brief does not replace Plans.md; it is a supporting artifact that briefly fixes the implementation premises.

- For tasks that include UI, a `design brief`
- For tasks that include an API, a `contract brief`
- When UI and API are mixed, split the briefs

### design brief

A brief for a UI task includes at minimum:

- What to achieve
- Who uses it
- Key screen states
- Constraints on look and feel
- Completion conditions

### contract brief

A brief for an API task includes at minimum:

- What it receives / returns
- Input validation conditions
- Behavior on failure
- External dependencies
- Completion conditions

## Step 6: Build the priority matrix (2-axis evaluation)

Evaluate each feature on 2 axes: **Impact × Risk (risk/uncertainty)**:

- **Impact**: user value × number of target users (high/low)
- **Risk**: technical unknowns × external dependencies (high/low)

| Impact＼Risk | Low risk | High risk |
|--------------|----------|-----------|
| **High Impact** | ★ **Required** — top priority (value is certain) | ▲ **Required + [needs-spike]** — needs early validation |
| **Low Impact** | ○ **Recommended** — handle with spare capacity | ✕ **Optional** — defer or reduce scope |

### `[needs-spike]` marker

Automatically attach a `[needs-spike]` marker to high-Impact × high-Risk tasks.
For a task tagged `[needs-spike]`, automatically generate a **spike (technical validation) task** and front-load it:

```markdown
| N.X-spike | [spike] technical validation of {{task name}} | produce a validation report | - | cc:TODO |
| N.X       | {{task name}} [needs-spike] | {{DoD}} | N.X-spike | cc:TODO |
```

The spike task's completion condition is to "leave a validation report (feasible / infeasible / requires design change)."

## Step 6.5: TDD skip decision (enabled by default)

TDD is enabled by default. Attach a `[skip:tdd]` marker and skip only for tasks that match one of the following:

| Skip condition | Reason |
|----------------|--------|
| Documentation/comments only | Does not affect executable code |
| Config files only (JSON, YAML, .env) | No logic under test |
| A simple fix of 1 line or less (typo) | Test cost exceeds the benefit |
| Style/format changes only | Does not affect behavior |
| Dependency update only | No implementation logic change |
| README/CHANGELOG update | Documentation only |
| Refactoring (no behavior change) | Already covered by existing tests |

Tasks that do not match the above get TDD applied automatically (test-first recommended).

## Step 6.7: Plans.md v3 format spec

Plans.md v3 includes the following format extensions:

### Purpose line in the Phase header (optional)

Each Phase header can carry a one-line Purpose. Omit it when there is no input:

```markdown
### Phase N.X: [phase name] [Px]

Purpose: [the problem this phase solves, in one line]
```

- **Default**: do not prompt for input (omit when empty)
- **Effect when present**: shown in the breezing Phase 0 scope confirmation
- **Generation rule**: auto-write only when the user explicitly states the phase's purpose

### Artifact notation (Status column)

Attach the commit hash to Status on task completion:

```markdown
| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 1.1  | ... | ... | - | cc:done [a1b2c3d] |
| 1.2  | ... | ... | 1.1 | cc:TODO |
```

- **Format**: `cc:done [7-char hash]`
- **Timing**: auto-attached in `harness-work` Solo Step 7
- **Backward compatibility**: `cc:done` without a hash is still valid

### Affected file list

Files related to the v3 format:

| File | Impact |
|------|--------|
| `skills/harness-plan/references/create.md` | Add the Purpose line to the Step 6 template |
| `skills/harness-plan/references/sync.md` | Recognize the `cc:done [hash]` format in diff detection |
| `skills/harness-work/SKILL.md` | Attach the hash in Solo Step 7, re-ticket on failure |
| `skills/harness-sync/SKILL.md` | Save a snapshot with --snapshot |
| `skills/breezing/SKILL.md` | Show progress in the Progress Feed |

## Step 7: Generate Plans.md

Emit the `Spec delta` or `Spec skip reason` first, then auto-generate the quality markers + DoD + Depends and generate Plans.md.

### Spec result output

The `Spec delta` / `Spec skip reason` is generated by Harness; the consumer only approves or amends it.

```markdown
Spec delta:
- path: spec.md
- change: [product rule to add/change]
- why: [why it is needed as a premise for this task contract]

Plans.md:
| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
```

```markdown
Spec skip reason:
- path checked: spec.md
- reason: [docs-only / mechanical task / correct answer fixed by existing spec and tests]
- preserve in: task context or sprint contract

Plans.md:
| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
```

### Quality marker attachment logic
```
Analyze the task content
    ↓
├── "auth" "login" "API" → [feature:security]
├── "component" "UI" "screen" → [feature:a11y]
├── "fix" "bug" → [bugfix:reproduce-first]
├── "docs" "comment" "README" "CHANGELOG" → [skip:tdd]
├── "config" "json" "yaml" "env" → [skip:tdd]
├── "style" "format" "lint" → [skip:tdd]
├── "refactor" (no behavior change) → [skip:tdd]
├── "payment" "billing" → [feature:security]
└── otherwise → no marker (TDD enabled by default)
```

### DoD auto-inference logic

Infer the DoD from the task "content" on a keyword basis and auto-fill it:

| Keyword in task content | Inferred DoD |
|-------------------------|--------------|
| "create" "new" "add" | The file exists and has the expected structure |
| "test" | Tests pass (`npm test` / `pytest`, etc.) |
| "fix" "bug" | The issue no longer reproduces |
| "UI" "screen" "component" | Visual confirmation (screenshot or browser) |
| "API" "endpoint" | Confirm the response with curl/httpie |
| "config" | The config value is applied |
| "documentation" "docs" | The file exists with no broken links |
| "migration" "DB" | The migration is runnable |
| "refactoring" | All existing tests pass + 0 lint errors |

The inferred result is only a default value. If the user specifies concrete acceptance conditions, prefer those.

### Depends auto-inference logic

Infer dependencies between tasks within a phase using the following rules:

1. **DB/schema tasks** → depended on by other implementation tasks (predecessor)
2. **UI tasks** → depend on API/logic tasks (successor)
3. **Test/validation tasks** → depend on implementation tasks (last)
4. **Config/environment tasks** → depended on by other tasks (predecessor)
5. **Tasks with no clear dependency** → `-` (can run in parallel)

When not confident in the inference, use `-` and ask the user to confirm.

**Generation template**:

```markdown
# [Project name] Plans.md

Created: YYYY-MM-DD

---

## Phase 1: [phase name]

Purpose: [the phase's purpose (optional)]

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 1.1  | [task description] [feature:security] | [verifiable completion condition] | - | cc:TODO |
| 1.2  | [task description] | [verifiable completion condition] | 1.1 | cc:TODO |
```

**Purpose line**:
- Auto-write only when the user states the phase's purpose
- If there is no input, omit the whole Purpose line (do not leave a blank line)
- Keep it to one line (multiple lines prohibited)

**DoD (Definition of Done) notation**:
- Write it in one verifiable line (e.g. "tests pass," "migration runnable," "0 lint errors")
- "Looks good" and "works fine" are prohibited. Make it decidable as Yes/No

**Depends notation**:
- No dependency: `-`
- Single dependency: task number (e.g. `1.1`)
- Multiple dependencies: comma-separated (e.g. `1.1, 1.2`)
- Phase dependency: phase number (e.g. `Phase 1`)

### Team mode output

Only when the user explicitly requests team mode, also guide the issue bridge dry-run alongside Plans.md.

- Only one tracking issue
- List the sub-issue payload per task
- Keep Plans.md as the source of truth
- Guide the `scripts/plans-issue-bridge.sh --team-mode` dry-run in a form that can be used as-is

## Step 8: Always guide the session startup command and first input

Right after emitting Plans.md, so the user does not hesitate on the next step,
guide, as a set, the **startup command for a new session** and
**the first input to enter right after startup**.

### Rules for presenting

1. Write at least one pair of a concrete startup command + first input
2. If possible, narrow to "the strongest pair + one alternative"
3. Add one line on not just the command but why that combination
4. For long-running tasks, guide `bash scripts/claude-longrun.sh` first

### Recommended mapping

| Situation | Startup command | First input |
|-----------|-----------------|-------------|
| Start from the first task | `claude` | a single-task run like `/harness-work 1.1` |
| Progress multiple tasks together | `claude` | `/breezing all` |
| Want to progress everything serially | `claude` | `/harness-work all` |
| Long-running / re-entry expected | `bash scripts/claude-longrun.sh` | `/harness-loop all` |

### Output example

```text
Next step:
- Startup command for a new session: claude
- First input after startup: /breezing all
- Best suited for: this Plans.md is structured to progress multiple tasks together, so a team run is the most natural
```

```text
Next step:
- Startup command for a new session: bash scripts/claude-longrun.sh
- First input after startup: /harness-loop all
- Best suited for: a long-running task where waits over 5 minutes or resumes are likely
```

## Step 9: Guide to the next action

> Plans.md complete!
>
> Next steps:
> - Start implementing with `harness-work`
> - Or say "start from Phase 1"
> - Add a feature with `harness-plan add [feature name]`
> - Defer a feature with `harness-plan update [task] blocked`

## CI mode (--ci)

No interview. Use the existing Plans.md as-is and only perform task decomposition.

1. Load Plans.md
2. List cc:TODO tasks in priority order
3. Attach a `[P]` mark to tasks that can run in parallel
4. Propose the next task to run
