# Triage rubric (Steps 1-2) — verify a bug against the current source code

Unlike a feature requirement (which is checked for completeness), a bug is
checked **against the current code**: is the reported behavior actually a defect
right now?

## Ingest (Step 1)

1. `git fetch origin` and note the up-to-date base (main/HEAD). Each bug fix
   starts from the freshest base — see `sequential-batch.md`.
2. MCP health probe (`flow-mcp-health.sh`); `not-configured`/`unreachable` →
   `decision_needed.v1` and stop.
3. `getJiraIssue` for the bug key. Extract into `bug-report.v1`:
   - `title` ← summary
   - `description` ← description
   - `steps_to_reproduce` ← the repro steps (one per line)
   - `expected_behavior` / `actual_behavior` ← the expected/actual fields or text
   - `environment` ← env/version field if present
   - `reporter_account_id` ← `fields.reporter.accountId` (this is the QA target)
   - `labels`, `status`
4. Persist:
   ```
   bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-ingest-bug.sh" \
     --source jira --source-ref BUG-123 --title "<summary>" \
     --description-file "$TMP/desc.txt" --steps-file "$TMP/steps.txt" \
     --expected-file "$TMP/exp.txt" --actual-file "$TMP/act.txt" \
     --environment "<env>" --reporter-account-id "<qa-acct>" \
     --mcp-available true --out ".claude/state/flow/<bug-key>/bug.json"
   ```

## Triage (Step 2) — decide bug / not-a-bug / needs-info

Investigate the current source, then pick exactly one verdict:

| Verdict | When |
|---------|------|
| `bug` | The reported behavior is reproduced or clearly wrong per the current code, and the code should behave differently |
| `not-a-bug` | Working as intended / already fixed on the current base / a config or environment issue / user error / a duplicate of a resolved issue |
| `needs-info` | Cannot decide without more from QA (missing repro steps, unknown environment, cannot locate the reported screen/endpoint) |

### How to check against the source

1. **Locate the code path** for the reported behavior (`Grep`/`Glob`/`Read`).
   Record `file:line` references in `triage.code_refs[]`.
2. **Reproduce if feasible**: write a failing test that encodes the reported
   `expected_behavior` vs `actual_behavior`. A passing repro test = strong `bug`
   evidence and becomes the TDD RED log when the fix runs (Step 4). Set
   `triage.reproduced` accordingly.
3. **Rule out non-bugs**: is the behavior actually specified (spec/DoD)? Was it
   already fixed after the reporter's version? Is it environment/config specific?
4. **Unknown data contract**: if you cannot locate or reproduce, that is
   `needs-info` (unknown) — never assert `not-a-bug` just because you could not
   find it.

### Write the verdict

```json
"triage": {
  "verdict": "bug",
  "evidence": "handler at api/user.go:88 returns 200 without checking ownership; repro test fails",
  "code_refs": ["api/user.go:88", "api/user.go:120"],
  "reproduced": true,
  "open_questions": [],
  "triaged_at": "<utc>"
}
```

Merge it into `bug.json` (jq `.triage = $v`). Then set the session status:
- `bug` → `flow-session.sh status <session.json> working` (Step 4)
- `not-a-bug` → `not-a-bug` (Step 3a)
- `needs-info` → `awaiting-ba` (Step 3b) with `open_questions` populated
