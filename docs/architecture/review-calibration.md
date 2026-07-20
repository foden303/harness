# Review Calibration

Storage format and operational rules for suppressing review drift.

## Storage

- `.claude/state/review-result.json`
- `.claude/state/review-calibration.jsonl`
- `.claude/state/review-few-shot-bank.json`

## Recording Rules

When `review-result.json` includes `calibration`, `record-review-calibration.sh`
appends one line to `review-calibration.jsonl`.

`calibration.label` is limited to one of the following:

- `false_positive`
- `false_negative`
- `missed_bug`
- `overstrict_rule`

Do not mix Phase 61 weak-supervision observations into `review-calibration.jsonl`.
Record `weak_label`, `judge_verdict`, `eval_result`, and `counterexample` separately in
`.claude/state/elicitation/events.jsonl` as `elicitation-event.v1`.
Review calibration corrects the Reviewer's verdict drift; the elicitation ledger serves as an evidence cue for the next Advisor/Reviewer. Keep these roles separate.

## few-shot Updates

`build-review-few-shot-bank.sh` extracts the latest samples from the calibration log and
regenerates the JSON bank for few-shot use.

## Quality Stance

- Mark only critical defects as `REQUEST_CHANGES`
- Keep concerns without evidence at `minor` or `recommendation`
- Write findings short and specific enough to reuse later as few-shot examples
