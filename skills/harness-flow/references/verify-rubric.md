# Verify rubric (Step 2)

Score the ingested `requirement.v1` against six binary gates. All must pass to
proceed to planning. Any failure (or any open question) routes to the BA loop
(Step 3). Record the result in `requirement.json.verification`.

## The six gates

| id | Gate | Pass when | Fail when |
|----|------|-----------|-----------|
| `goal-present` | Goal / why is stated | There is a clear "what and why", not just a title | Only a title, or a vague one-liner |
| `acceptance-criteria-testable` | Acceptance criteria present and testable | ≥1 criterion, each decidable Yes/No | Zero criteria, or criteria like "works fine" / "looks good" |
| `actionable-scope` | Scope is actionable | The target area/system is identifiable and bounded | Open-ended research ask, or scope not identifiable |
| `no-blocking-ambiguity` | No blocking ambiguity | No contradictory or `TBD` requirements that change interpretation | Contradictions, placeholders that block a decision |
| `constraints-stated` | Constraints / non-goals | Inputs, out-of-scope, and dependencies are stated or safely inferable from the repo | A material constraint is unknown and would change the design |
| `unknowns-marked` | Unknowns marked, not assumed | Missing info is recorded as `unknown` | The requirement (or the ingester) asserted something `absent` without evidence |

The testability bar reuses the Plans.md DoD standard: reject non-decidable
phrasing ("works fine", "is fast", "user-friendly"). A criterion must be
checkable by a command, an observable output, or a clear yes/no inspection.

## Output

Write into `requirement.json`:

```json
"verification": {
  "verdict": "ok" | "needs-clarification",
  "checks": [
    {"id": "goal-present", "pass": true,  "note": "..."},
    {"id": "acceptance-criteria-testable", "pass": false, "note": "no criteria on the ticket"},
    ...
  ],
  "open_questions": [
    "What are the acceptance criteria for the X endpoint (status codes, payload)?"
  ],
  "verified_at": "<utc>"
}
```

Rules:
- `verdict = "needs-clarification"` if **any** gate fails **or** `open_questions`
  is non-empty; otherwise `"ok"`.
- Each failing gate must contribute at least one concrete, answerable question to
  `open_questions` — this is exactly what the BA comment will contain.
- Questions target the BA, not the operator. Keep them specific and answerable in
  a single comment reply.

Use `jq` (or `flow-session`'s sibling pattern) to merge the verification block
into `requirement.json`, e.g.:
```
tmp="$(mktemp)"
jq --argjson v '<verification json>' '.verification = $v' \
   .claude/state/flow/<id>/requirement.json > "$tmp" \
   && mv "$tmp" .claude/state/flow/<id>/requirement.json
```

Then set the session status: `ok` → `flow-session.sh status <session.json>
planning` (Step 4); `needs-clarification` → `awaiting-ba` (Step 3).

## Routing note

A failed verification is **not** a rejection of the ticket — it is a request for
information. Only the clarification-round cap (Step 3) or an operator decision
turns `needs-clarification` into an escalation.
