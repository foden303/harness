# Execution Modes

`harness-work` chooses the lightest execution mode that still preserves review
and validation.

## Shared Preflight

1. Read `Plans.md` and identify the selected task set.
2. Stop if the task table lacks `Task`, `DoD`, `Depends`, or `Status`.
3. Check whether a project spec SSOT exists when product behavior can drift.
   Prefer existing project-level docs, then `docs/spec/00-project-spec.md`.
4. If the task changes product behavior, API, data model, permissions, billing,
   integrations, or tenant boundaries and no stable spec exists, create or
   update the spec before implementation.
5. Skip spec creation only for mechanical work such as typo, formatting,
   dependency bump, docs-only, or behavior-preserving refactor tasks. Record
   the skip reason in the task context or sprint contract.
6. Resolve helper scripts through `HARNESS_PLUGIN_ROOT`, not the caller
   project's `scripts/` directory.
7. Mark only the selected task as `cc:WIP`.
8. Generate and approve a sprint contract before implementation when the task
   needs reviewable DoD checks.

## Solo

Use for one task. The parent session implements directly, validates, runs the
review loop, commits unless `--no-commit` is set, and marks `Plans.md`
`cc:done [hash]`.

## Parallel

Use for two or three independent tasks, or when `--parallel N` is explicit.
Workers may use isolated worktrees when file ownership can conflict. The Lead
still owns final integration and status updates.

## Breezing

Use for four or more tasks, or when `--breezing` is explicit. Lead coordinates
Workers, Advisor, and Reviewer while preserving the implementation/review
boundary.

## Lane and Stage Contract

Sprint contract generation passes `spec_path`, `lane`, `stage`, and evidence
fields to Worker / Reviewer. See the "Sprint Contract" section in
`skills/harness-work/SKILL.md` for the full field list.

### Stage gate (5 stages)

| stage | Purpose |
|-------|------|
| `research` | Investigate current state and collect evidence. Report un-obtained data as `unknown` |
| `plan` | Freeze scope / DoD / lane into Plans |
| `impl` | TDD Red→Green implementation. `[tdd:required]` requires `tdd_red_log` |
| `review` | Attach `review_artifact` (`APPROVE` / `REQUEST_CHANGES`) to the contract |
| `closeout` | Attach `pr_closeout` (`base_ref` / `head_ref` / evidence pack) |

### Lane: what to lighten vs what to keep

| lane | What to lighten | What must be kept |
|------|-------------|-------------|
| `fast` | full review (major-only or advisory is acceptable), PR body detail, release preflight | `spec_path`, unknown data contract (`not_observed != absent`), focused checks (`runtime_validation` / `checks`), `tdd_red_log` or `skip_tdd_reason` (when `[tdd:required]`) |
| `gate` | — (no lightening) | spec alignment, TDD when required, major-only or full review, re-review until clean, `research_evidence` |
| `release` | — (no lightening) | version/tag/GitHub Release/CI validation, `pr_closeout` + release preflight, full evidence pack |

Regardless of lane, a `[tdd:required]` task is not treated as complete unless the sprint contract contains a `tdd_red_log` or an explicit `skip_tdd_reason`.
