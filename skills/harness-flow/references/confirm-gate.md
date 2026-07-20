# Confirm gate (Step 8)

The single operator decision in the flow: is the reviewed work OK to commit?

The operator here is a backend engineer driving the flow, so the **default is a
`decision_needed.v1` CLI gate** — instantly answerable in-terminal. The
`harness-accept` ship/wait/reject HTML is an opt-in (`--accept-html`) for when a
richer, non-engineer-facing surface is wanted.

## Default: `decision_needed.v1`

Present a compact summary and ask OK / not-OK. Include:

- Requirement title + JIRA key (`PROJ-123`).
- Per-criterion **verified / unverified**, mapped from the review evidence
  (`acceptance_criteria` against `review-result.v1` accepted findings / verification).
- The review verdict (`APPROVE` / `REQUEST_CHANGES`).
- Changed-file summary (`git diff --stat` across the produced commits).
- The commit message(s) that will be created (preview, `[PROJ-123] ...`).

Emit the gate as `decision_needed.v1` (the inline stdout contract used across
`harness-review` governance):

```json
{
  "decision_needed": {
    "required": true,
    "ask_tool": "AskUserQuestion",
    "question": "Commit the reviewed work for PROJ-123?",
    "options": ["OK — create the commits", "Not OK — describe what to fix"],
    "context": { "verdict": "APPROVE", "verified": 3, "total": 4, "commits_preview": ["[PROJ-123] ..."] }
  }
}
```

When `AskUserQuestion` is available, ask it; otherwise print the
`decision_needed.v1` block and halt for the operator to re-run with a decision.

- **OK** → Step 9 (commit).
- **Not OK** (with a reason) → Step 10 (fix/rework). The reason becomes the
  fix-task Content.

This gate is exactly the external-transmission / request-shape boundary from
`.claude/rules/autonomous-confirmation-scope.md` — do not auto-decide it.

## Opt-in: `--accept-html`

Render the `harness-accept` surface (ship / wait / reject) instead of the CLI
gate. Map:

- `requirement.acceptance_criteria` → the accept skill's `verified_criteria`
  (each marked verified/unverified from review evidence),
- the review verdict + changed files → the evidence shown per criterion.

`harness-accept` computes the recommendation by verified ratio
(≥0.8 ship / ≥0.5 wait / else reject) and records the operator's choice as
`acceptance-decision.v1`. A `ship` maps to OK (Step 9); `wait` / `reject` map to
not-OK (Step 10). Because this flow starts from a JIRA requirement (not a
`harness-plan-brief` `personal-preference.v1`), pass the criteria explicitly —
do not rely on a `user_request_hash` join.
