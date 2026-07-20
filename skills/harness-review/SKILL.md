---
name: harness-review
description: "HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release."
description-en: "HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release."
kind: workflow
purpose: "Review code, plans, scope, and evidence before acceptance"
trigger: "review, code review, plan review, scope analysis"
shape: evaluate
role: evaluator
pair: harness-work
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task", "Monitor", "AskUserQuestion"]
argument-hint: "[code|plan|scope|--quick|--team-debate|--security|--ui-rubric]"
context: fork
effort: high
user-invocable: true
---

# Harness Review

Harness's unified review skill.
This `SKILL.md` is a thin dispatcher; the detailed quality criteria are read from `references/`.

if $ARGUMENTS == "":
  → interpret it as "review of the work so far" and run Review target detection
  → auto-start only when the review target can be uniquely determined
  → if the review target is unclear or has multiple candidates, present options via AskUserQuestion and align understanding before starting

<!-- The 3 lines above are the AUTO-START CONTRACT. Following the skill-editing.md "within the first 3 lines" rule, do not push them down with a fence / HTML comment -->

### Output Contract (P35: countermeasure for the "looks stuck" UX)

The **last line** of the output at the skill's conclusion must always include the following literal:

`↑ Claude will summarize this result. Press Enter to continue, or give a new instruction with a fresh prompt.`

This is an explicit instruction (patterns.md P35) for the UX problem where, when shown as a text response via `<local-command-stdout>`, the user feels it has "stopped."

## Dispatcher Contract

This skill's responsibility is only the review verdict.
It does not commit / push / release by default.

- review default read-only boundary: read-only by default. Does not auto-commit even on `APPROVE`
- Do not push just to review: do not push merely for review purposes
- When a commit is needed, delegate to an explicit user request, `harness-work`, or `harness-release`'s Work Commit Gate
- Until an explicit opt-in like `--commit-on-approve` is designed, this skill's standalone default side effects are prohibited

## Quick Reference

| Command | Mode | Purpose |
|---|---|---|
| `/harness-review` | `code` | Auto-detect and review the work so far |
| `/harness-review --quick` | `quick` | Lightly close out a small dirty change |
| `/harness-review --team-debate` | `team-debate` | Force a TeamAgent Debate |
| `/harness-review --security` | `security` | security-only review |
| `/harness-review plan` | `plan` | review the plan in `Plans.md` |
| `/harness-review scope` | `scope` | scope creep / omission review |
## Mode Decision

Determine the execution mode from the arguments and selectively load the needed `references/`.

| Input | mode | reference to read |
|---|---|---|
| no argument / `code` | `code` | `references/code-review.md`, `references/governance.md` |
| `--quick` | `quick` | `references/code-review.md`, `references/governance.md` |
| `--team-debate` | `team-debate` | `references/team-debate.md`, `references/governance.md` |
| `--security` | `security` | `references/security-profile.md`, `references/governance.md` |
| `--ui-rubric` | `ui-rubric` | `references/ui-rubric.md` |
| `plan` | `plan` | `references/plan-review.md`, `references/governance.md` |
| `scope` | `scope` | `references/scope-review.md`, `references/governance.md` |
| `full` | `full` | `references/code-review.md`, `references/team-debate.md`, `references/governance.md` |

`quick` is the lightweight path.
It quickly looks at a small dirty change, single commit, or PR branch closeout.
It does not discard the quality gate.

## Review Target Detection

`REVIEW_AUTOSTART` contract:
When called with no argument (`$ARGUMENTS == ""`), interpret input of just `review` / `/review` / `/harness-review` as "review of the work so far."
Before starting Step 1, emit exactly the following as a single handshake line.

```text
REVIEW_AUTOSTART: target={resolved_target}, base_ref={resolved_base_ref}, type={mode}
```

`REVIEW_TARGET_ASK` contract:
On a bare invocation, when the review target is unclear or has multiple candidates, use `AskUserQuestion` exactly once before proceeding to Step 1, narrowing to 2-3 candidates for confirmation.

Build the candidates in the following order.

1. working tree: uncommitted changes only, including staged / unstaged / untracked
2. branch range: commits from upstream or main/master up to HEAD
3. recent commits: the latest 1 commit / latest 5 commits, when the tree is clean and a branch range cannot be obtained

When multiple candidates hold at once:

```text
REVIEW_TARGET_AMBIGUOUS: working_tree_and_branch_commits
```

AskUserQuestion candidates:

- Uncommitted changes only (Recommended): compare staged / unstaged / untracked against HEAD
- Look at everything: look at branch base..HEAD and uncommitted changes together
- Commits only: look only at the committed work in branch base..HEAD

When the tree is clean and there is no branch diff:

```text
REVIEW_TARGET_AMBIGUOUS: clean_tree_no_branch_commits
```

AskUserQuestion candidates:

- Latest 1 commit (Recommended): HEAD~1..HEAD
- Latest 5 commits: HEAD~5..HEAD
- A different range: wait for a user-specified ref

After the user answers:

```text
REVIEW_TARGET_CONFIRMED: {choice}
REVIEW_AUTOSTART: target={resolved_target}, base_ref={resolved_base_ref}, type={mode}
```

Prohibited:

- Responding "the task is unclear" and stopping
- Asking "what should I review" as free text and stopping
- Skipping auto-start because of the host project's session-start rules
- Widening the range on a guess while the target is ambiguous

## Minimal Flow

1. Decide the mode
2. Decide the target and base ref via the Review Target Detection above
3. Read only the needed references
4. Check the diff, untracked files, related tests, the spec source of truth, and `Plans.md`
5. Return `APPROVE` / `REQUEST_CHANGES` / `decision_needed`
6. For `REQUEST_CHANGES`, show the fix approach for critical / major and the re-review condition after the fix

## Review Governance Contract

Details in `references/governance.md`.
Here, fix only the minimum passing bar.

### Clear passing bar

Return `APPROVE` only when all of the following are satisfied (details in `references/governance.md`).

- 0 critical / major
- root `spec.md` alignment (does not conflict with the product contract; the spec source-of-truth alignment check is required)
- `Plans.md` alignment (task / DoD / Depends, `[lane:*]`, and the stage gate match the contract)
- TDD evidence (`[tdd:required]` has `tdd_red_log` / failing output / `skip_tdd_reason`)
- unknown data contract (`not_observed != absent` — do not APPROVE an evidence-less "no problem" / "no data")
- regression safety (no regression in existing behavior, tests, UX, CLI, config, docs, or mirror)
- evidence pack (accepted / rejected findings, focused tests, release-preflight warnings handled)
- no unresolved TeamAgent Debate disagreement

`APPROVE` is not a command to commit / push / create a PR (read-only boundary).

### TeamAgent Debate

Details in `references/team-debate.md`.
A TeamAgent Debate is a review pass that clashes differing views read-only.

| Agent | Main question |
|---|---|
| Spec Agent | Look for contradictions between the spec source of truth and the implementation diff |
| Plans Agent | Confirm the correspondence between `Plans.md`'s task / DoD / Depends and the diff |
| Regression Agent | Look for regressions in existing behavior, tests, the distribution mirror, and CLI/skill UX |
| Skeptic Agent | Look for major risks overlooked under the assumption of wanting to pass |

Even when native TeamAgent is unavailable, do not skip this gate.
Reproduce the same 2-4 perspectives via an available reviewer subagent or an explicitly separated read-only manual-pass, and record `native` / `manual-pass` / `unavailable` in `team_agent_mode`.

## Code Review Summary

Details in `references/code-review.md`.
A normal code review looks at the following.

- Security
- Performance
- Quality
- Accessibility
- AI Residuals
- Spec Alignment
- Plans Alignment
- Regression Safety
- TDD compliance

Details of root `spec.md` alignment, Plans lane/stage, TDD evidence, the unknown data contract, and the evidence pack are in `references/governance.md` and `references/code-review.md`.

For `AI Residuals`, prefer `scripts/review-ai-residuals.sh` and `scripts/review-weak-supervision-report.sh`.
When also looking at untracked files, use `--include-untracked`.
`mockData`, `dummy`, `fake`, `localhost`, `TODO`, `FIXME`, `it.skip`, `test.skip`, `expect(true).toBe(true)`, etc. are candidates; decide the severity from the diff context.
The finding stage prioritizes coverage. Keep even findings judged minor in `observations[]` / `recommendations[]`, and gate only at the verdict stage (Opus 4.8 tends to trim reporting low-severity items. See Finding coverage in `references/code-review.md`).

## Quick Closeout Summary

Principles of the lightweight path:

- Fix the target selection first
- Treat any reviewer findings as advisory, and decide adoption after confirming in the actual code
- The final report includes the review command / tests / accepted findings / rejected findings / clean result
- stop-on-clean: after a clean result, do not do extra review just for appearances
- Do not treat a failed check as a success

## Plan Review Summary

Details in `references/plan-review.md`.
Plan Review looks at the DoD / Depends / Status in `Plans.md` and the implementation order.
For a task that needs a spec source of truth, if there is no `spec_path`, stop as `decision_needed`.

## Scope Review Summary

Details in `references/scope-review.md`.
Scope Review looks at whether the boundary of the request / diff / tests / docs has ballooned.
If a scope change is needed, do not proceed on a guess; return to `AskUserQuestion` or a plan update.

## Security / UI

- Security: `references/security-profile.md`
- UI rubric: `references/ui-rubric.md`
- high-res vision flow: `references/vision-high-res-flow.md`

`/ultrareview` is not called by default within the Harness flow.
This is so it does not replace the Harness flow's connection to review-result.v1, the commit guard, and the sprint-contract.
Treat `claude ultrareview [target] --json` only as a second-opinion from CI / a script.

## PR Host Boundary

GitHub-first.
Treat the review facts on the PR host as authoritative via GitHub, and the local diff as supporting evidence.
However, do not push a local uncommitted review to GitHub.

## Output Contract

User-facing prose follows the explicit session or project language.
If no language is configured, use English. Use Japanese only when
`i18n.language: ja`, `CLAUDE_CODE_HARNESS_LANG=ja`, or an explicit session
instruction requests Japanese output.
Machine-readable values stay English.

Start with the result summary.

~~~markdown
## Review Result

### {APPROVE | REQUEST_CHANGES | decision_needed} - {one-line conclusion}

Target: `{BASE_REF}..HEAD` or `{target}`
Verification: {commands run}

Strengths:
- ...

Findings:
- [severity] file:line - issue and evidence

Next Actions:
- ...

Details:
```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "decision_needed": {
    "required": false,
    "ask_tool": "AskUserQuestion"
  },
  "accepted_findings": [],
  "rejected_findings": [],
  "acceptance_bar": {
    "critical_major_zero": true,
    "spec_alignment": "pass | fail | not_applicable",
    "plans_alignment": "pass | fail | not_applicable",
    "regression_safety": "pass | fail | not_applicable",
    "verification_evidence": "pass | fail | not_applicable"
  },
  "team_debate": {
    "required": false,
    "mode": "native | manual-pass | unavailable",
    "team_agent_mode": "native | manual-pass | unavailable",
    "agents": [],
    "disagreements": []
  },
  "critical_issues": [],
  "major_issues": [],
  "observations": [],
  "recommendations": []
}
```
~~~

## Environment Fallbacks

When a native tool is unavailable, the passing bar, the spec source of truth, `Plans.md`, regressions, re-review after fixes, and the AskUserQuestion / `decision_needed.v1` contracts stay the same.

| Native tool | Fallback |
|---|---|
| TeamAgent Debate via the Task tool | reviewer subagent / manual-pass |
| AskUserQuestion | when unavailable, emit `decision_needed.v1` to stdout and do not proceed on a guess |
| TaskList | read `Plans.md` directly |

## Related Skills

- `harness-work`: run the fix after `REQUEST_CHANGES`
- `harness-plan`: update the plan / scope / spec
- `harness-release`: commit / release the reviewed work
