# Report (Step 3)

The report is the operator's view of the batch. It is produced **before** the
approval gate, so the operator decides what to post while looking at the
evidence — not after.

## Terminal report

Lead with the one line that answers "can we start building?", then the table.

```
PROJ-100 "Q3 payments" — 7 stories verified: 3 clear, 4 need clarification, 0 blocked.

| Ticket   | Verdict             | Failing gates                              | Qs |
|----------|---------------------|--------------------------------------------|----|
| PROJ-101 | clear               | —                                            | 0  |
| PROJ-102 | needs-clarification | ac-present-testable, edge-error-states       | 3  |
| PROJ-103 | clear               | (advisory: design-reference)                 | 0  |
| PROJ-104 | needs-clarification | data-validation-rules, dependencies-identified | 2 |
...

Ready to build now: PROJ-101, PROJ-103, PROJ-105
Blocked on the BA:  PROJ-102, PROJ-104, PROJ-106, PROJ-107
```

Rules:
- **Blocker failures** are listed plainly; **advisory** failures go in parentheses
  so they never look like a hold.
- A `clear` ticket with advisory failures is still `clear` — say so.
- `blocked` tickets (unreadable) are listed separately with the reason, since
  they need access, not answers.
- Then print, per unclear ticket, the actual questions that would be posted. The
  operator must be able to judge the questions themselves before approving —
  a table of counts is not enough.

## HTML report (`--html`)

Render a single-file HTML alongside the terminal report:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/render-html.sh" \
  --template story-verify \
  --data "$TMP/report.json" \
  --out ".claude/state/story-verify/<batch-id>/story-verify-report.html"
```

The renderer is mustache-style (`{{var}}`, `{{#section}}…{{/section}}`), so the
data JSON must be flat scalars plus arrays of flat objects:

```json
{
  "kind": "story-verify",
  "project": "PROJ-100 — Q3 payments",
  "generated_at": "2026-07-20T09:00:00Z",
  "root_ref": "PROJ-100",
  "mode": "epic",
  "total": 7,
  "clear_count": 3,
  "unclear_count": 4,
  "blocked_count": 0,
  "clear_pct": 43,
  "tickets": [
    {
      "key": "PROJ-102",
      "url": "https://<site>/browse/PROJ-102",
      "title": "Export the transaction list to CSV",
      "issue_type": "Story",
      "verdict": "needs-clarification",
      "verdict_class": "unclear",
      "failing_blockers": "ac-present-testable, edge-error-states",
      "failing_advisories": "nonfunctional-stated",
      "question_count": 3
    }
  ],
  "questions": [
    {
      "key": "PROJ-102",
      "gate": "ac-present-testable",
      "text": "AC-2 says the export 'should be quick' — what is the acceptable wait for a 10k-row export, and what does the user see while it runs?",
      "why": "Without a number there is no way to write a passing test or size the work."
    }
  ]
}
```

`verdict_class` is one of `clear` / `unclear` / `blocked` and drives the styling;
keep it in sync with `verdict`. Build the JSON by folding the per-ticket
`story-verification.v1` records with `jq` — never hand-type numbers that the
records already carry.

## Redaction

Ticket titles and question text can carry client names. If the host project has
`.claude/rules/client-redaction.yaml`, pass the rendered HTML through
`scripts/redact-by-dictionary.sh` before sharing it (see
`.claude/rules/cross-repo-handoff.md` Layer 2a). The terminal report stays
unredacted — it never leaves the operator's machine.

## Final summary (after the loop)

End a completed run with the batch counts and the single next action:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/story-verify-batch.sh" \
  summary ".claude/state/story-verify/<batch-id>/batch.json"
```

Then state the next action explicitly, e.g.:

> 4 questions posted across PROJ-102/104/106/107. I'll re-check in 30 minutes.
> The 3 clear stories (PROJ-101, 103, 105) can go to `/harness-flow` now.
