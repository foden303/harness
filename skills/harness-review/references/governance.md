# Review Governance

## In one line

Return `APPROVE` only when you can say, with evidence, that there is no serious problem.

## Clear acceptance bar

Conditions for `APPROVE`:

- 0 critical / major
- root `spec.md` alignment: no contradiction with the higher-level product contract. Even when a sub-spec (`spec_path`) exists, confirm the root contract first. Allow `spec_skip_reason` only for unnecessary tasks
- `Plans.md` alignment: no contradiction with task / DoD / Depends. `[lane:fast|gate|release]` and stage gate metadata match the contract
- TDD evidence: for `[tdd:required]` tasks, there is a `tdd_red_log`, literal failing output, or an explicit `skip_tdd_reason`
- unknown data contract: do not `APPROVE` an evidence-free "no issue" / "no data". `not_observed != absent` — report the unobserved as `unknown` / `not observed`
- regression safety: no evidence of regression in existing behavior, existing tests, existing UX, existing CLI, existing settings, existing docs, or distribution mirrors
- evidence pack: the report contains accepted findings / rejected findings, focused tests, and how `release-preflight` warnings were handled
- no unresolved TeamAgent Debate disagreements

## Severity

| severity | Meaning | verdict |
|---|---|---|
| critical | directly leads to secret leak, data destruction, permission breakage, or a release incident | REQUEST_CHANGES |
| major | DoD unmet, spec-contract violation, lane/stage mismatch, missing TDD evidence, clear regression, or dangerous without tests run | REQUEST_CHANGES |
| minor | improves quality but not enough to block shipping | APPROVE allowed |
| recommendation | optional improvement | APPROVE allowed |

If only minor / recommendation remain, you do not necessarily stop.
If you do stop, explain concretely why it is major.

## AskUserQuestion / decision_needed

For judgments that break if decided by guesswork, use `decision_needed` rather than `REQUEST_CHANGES`.

Examples of `decision_needed`:

- The spec contract needs to change
- The `Plans.md` DoD / Depends / lane / stage needs to change
- The user needs to choose the priority between security and UX
- A business decision is needed on whether to keep or drop backward compatibility

Use AskUserQuestion when available.
When it is unavailable, emit `decision_needed.v1` to stdout and do not proceed on guesswork.

## Side effects

review default read-only boundary:

- Do not auto-commit even on `APPROVE`
- `APPROVE` is not a command to commit / push / create a PR
- Do not push just to review
- commit / push / release are the responsibility of `harness-work` / `harness-release` / an explicit user request

## Output evidence

Required:

- scope
- the review command run
- the tests run
- accepted findings
- rejected findings
- release-preflight warnings and how they were handled
- clean result or remaining issues
- the acceptance bar for root `spec.md` / `Plans.md` lane-stage / regression / TDD / unknown data

If the evidence pack is empty despite an `APPROVE`, that `APPROVE` is invalid.
