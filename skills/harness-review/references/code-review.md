# Code Review Flow

## In one line

Collect the diff, inspect implementation, spec, Plans, regressions, and tests, and stop only the problems that must be stopped.

## Step 1: collect diff

What to check:

```bash
git status --short
git diff --stat "${BASE_REF:-HEAD}"
git diff "${BASE_REF:-HEAD}"
git ls-files --others --exclude-standard
```

Untracked files do not appear in `git diff`.
Always include them in scope.

## Step 2: static scans

AI Residuals:

```bash
bash scripts/review-ai-residuals.sh --base "${BASE_REF:-HEAD}"
bash scripts/review-weak-supervision-report.sh
```

Candidates:

- `mockData`
- `dummy`
- `fake`
- `localhost`
- `TODO`
- `FIXME`
- `it.skip`
- `describe.skip`
- `test.skip`
- `expect(true).toBe(true)`

Finding a candidate alone does not make it major.
Judge severity by whether it "directly leads to a shipping incident or misconfiguration" in the diff context.
But do not silently discard what you judge as minor either — record it as an observation (see Finding coverage below).

## Step 3: eight review lenses

| Lens | What to look at |
|---|---|
| Security | SQL injection, cross-site scripting, secret leak, permission bypass |
| Performance | N+1, needless heavy IO, blocking work |
| Quality | duplicate logic, unclear boundary, fragile parsing |
| Accessibility | labels, focus, contrast, keyboard path |
| AI Residuals | fake success, skipped tests, mock-only implementation |
| Spec Alignment | contradictions between the root `spec.md` product contract and the sub-spec (`spec_path`) |
| Plans Alignment | consistency with `Plans.md` task / DoD / Depends / `[lane:*]` / stage gate |
| Regression Safety | regressions in existing behavior, mirrors, or CLI/skill UX |

## TDD compliance

For `[tdd:required]` tasks, confirm `tdd_red_log`, literal failing test output, or an explicit `skip_tdd_reason`.
When TDD is excessive, such as docs-only or refactor-only changes, recording `[tdd:skip:<reason>]` is sufficient.
Do not `APPROVE` without evidence.

## Unknown data contract

`not_observed != absent` — do not assert that unobserved data "does not exist" or is "fine".
When a file / API / CI / memory / fixture is not visible, report it as `unknown` / `not observed`.

## Evidence pack

Before `APPROVE`, confirm the evidence pack: accepted findings, rejected findings, focused tests, how `release-preflight` warnings were handled, and residual risk.

## Finding coverage (Opus 4.8)

Separate the finding stage from the verdict stage.

- The finding stage prioritizes **completeness**. Record every issue you find with its severity and confidence, including low-confidence and minor findings (keep them in `observations[]` / `recommendations[]` of `review-result.v1`).
- Only the verdict stage gates (`REQUEST_CHANGES` for critical / major, `APPROVE` for minor-only).
- "Does it directly lead to a shipping incident or misconfiguration?" is **a severity judgment**, not **a judgment about whether to record it**. Even when you judge something as minor, do not silently discard it.

Opus 4.8 tends to faithfully obey "do not report low-severity" and, even when it investigates, narrows its reporting and lowers recall.
Narrowing findings is the responsibility of the verdict stage; do not discard findings during the investigation stage.

## Verdict

1. critical / major exists → `REQUEST_CHANGES`
2. root `spec.md` / `Plans.md` lane-stage / regression gate fails → `REQUEST_CHANGES`
3. TDD evidence missing, unknown data asserted, empty evidence pack → `REQUEST_CHANGES`
4. a decision is required → `decision_needed`
5. minor / recommendation only → `APPROVE`
6. insufficient evidence → `REQUEST_CHANGES` or `decision_needed`

## Re-review after fixes

After `REQUEST_CHANGES`, always re-review once the fixes are made.
If the same issue is missed twice in a row, TeamAgent Debate is mandatory.
