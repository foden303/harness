#!/usr/bin/env bash
# test-epic-verify-contracts.sh — ba-epic-verify contracts.
#
# Proves the epic-verification.v1 schema and its two shell helpers:
#   - epic-verify-record.sh writes a schema-valid epic-verification.v1
#   - the verdict is DERIVED from the gates and overrides a wrong hand-written one
#   - n-a without a note (silent skip) is rejected
#   - a question citing a gate that did NOT fail is rejected
#   - a question / clarification with an unknown lens is rejected
#   - clarifications[] are upserted BY LENS (a second round never duplicates)
#   - --set-handoff merges the reporter handoff (assignee + status transition)
#   - jira-status-match.sh picks, prefers, and skips transitions correctly
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/epic-verification.v1.json"
RECORD="${ROOT}/scripts/epic-verify-record.sh"
MATCH="${ROOT}/scripts/jira-status-match.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1" >&2; fail=1; }

# The record helper validates with jsonschema when it is importable and falls
# back to a minimal hand-rolled check otherwise. Assertions only the full schema
# can catch are gated on this flag so the suite is valid on both paths.
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  HAS_JSONSCHEMA=1
else
  HAS_JSONSCHEMA=0
fi

# --- presence ---
[ -f "${SCHEMA}" ] || die "epic-verification.v1 schema missing"
[ -x "${RECORD}" ] || die "epic-verify-record.sh missing/not executable"
[ -x "${MATCH}" ]  || die "jira-status-match.sh missing/not executable"

cd "${TMP}"

# draft_with VERDICT BLOCKER_RESULT QUESTIONS_JSON > stdout
draft_with() {
  jq -n \
    --arg verdict "$1" \
    --arg blocker_result "$2" \
    --argjson questions "$3" \
    '{
      issue_key: "PROJ-100",
      title: "Q3 payments",
      issue_type: "Epic",
      reporter_account_id: "acct-ba",
      child_keys: ["PROJ-101", "PROJ-102"],
      child_count: 2,
      verdict: $verdict,
      checks: [
        {id: "epic-goal-value",     severity: "blocker",  result: "pass", evidence: "from X to Y"},
        {id: "epic-dod-observable", severity: "blocker",  result: $blocker_result, note: "n"},
        {id: "epic-success-metrics", severity: "advisory", result: "pass"}
      ],
      questions: $questions
    }'
}

BE_Q='[{"lens":"be","gate":"epic-dod-observable","text":"What counts as done?","why":"cannot test"}]'

# --- happy path: all blockers pass, no questions -> clear ---
draft_with clear pass '[]' > "${TMP}/clear.json"
OUT="$(bash "${RECORD}" --in "${TMP}/clear.json" --out "${TMP}/out-clear.json")"
if [ -f "${OUT}" ] \
  && [ "$(jq -r .schema_version "${OUT}")" = "epic-verification.v1" ] \
  && [ "$(jq -r .verdict "${OUT}")" = "clear" ] \
  && [ -n "$(jq -r .verified_at "${OUT}")" ]; then
  pass "record writes a schema-valid epic-verification.v1 stamped verdict=clear"
else
  die "record output malformed for the clear happy path"
fi

# --- derivation overrides a wrong hand-written verdict ---
draft_with clear fail "${BE_Q}" > "${TMP}/lying.json"
bash "${RECORD}" --in "${TMP}/lying.json" --out "${TMP}/out-lying.json" >/dev/null
if [ "$(jq -r .verdict "${TMP}/out-lying.json")" = "needs-clarification" ]; then
  pass "declared verdict=clear with a failing blocker is persisted as needs-clarification"
else
  die "hand-written verdict was not overridden by the failing blocker gate"
fi

# --- declared blocked stays blocked ---
draft_with blocked pass '[]' > "${TMP}/blocked.json"
bash "${RECORD}" --in "${TMP}/blocked.json" --out "${TMP}/out-blocked.json" >/dev/null
if [ "$(jq -r .verdict "${TMP}/out-blocked.json")" = "blocked" ]; then
  pass "declared verdict=blocked is preserved"
else
  die "declared verdict=blocked was not preserved"
fi

# --- verdict subcommand prints without writing ---
V="$(bash "${RECORD}" verdict --in "${TMP}/lying.json")"
if [ "${V}" = "needs-clarification" ]; then
  pass "verdict --in prints the derived verdict without writing a record"
else
  die "verdict subcommand did not print the derived verdict (got '${V}')"
fi

# --- silent-skip guard: n-a without a note ---
jq '.checks[2] = {id: "epic-design-reference", severity: "advisory", result: "n-a"}' \
  "${TMP}/clear.json" > "${TMP}/na-nonote.json"
if bash "${RECORD}" --in "${TMP}/na-nonote.json" --out "${TMP}/out-na.json" >/dev/null 2>&1; then
  die "a check with result=n-a and no note was accepted (silent skip)"
else
  pass "n-a without a note is rejected (silent-skip guard)"
fi

# --- a question must trace to a gate that actually failed ---
jq '.questions[0].gate = "epic-goal-value"' "${TMP}/lying.json" > "${TMP}/orphan-q.json"
if bash "${RECORD}" --in "${TMP}/orphan-q.json" --out "${TMP}/out-orphan.json" >/dev/null 2>&1; then
  die "a question citing a passing gate was accepted (BA would be asked a settled question)"
else
  pass "a question citing a non-failing gate is rejected"
fi

# --- lens enum on questions ---
jq '.questions[0].lens = "qa"' "${TMP}/lying.json" > "${TMP}/bad-lens.json"
if bash "${RECORD}" --in "${TMP}/bad-lens.json" --out "${TMP}/out-lens.json" >/dev/null 2>&1; then
  die "an unknown question lens was accepted (expected exit 1)"
else
  pass "unknown question lens is rejected"
fi

# --- invalid severity / result (caught on both validation paths) ---
jq '.checks[2].severity = "critical"' "${TMP}/clear.json" > "${TMP}/bad-sev.json"
if bash "${RECORD}" --in "${TMP}/bad-sev.json" --out "${TMP}/out-sev.json" >/dev/null 2>&1; then
  die "an invalid severity was accepted (expected exit 1)"
else
  pass "invalid severity is rejected"
fi

# --- schema-only assertions (gate id enum + additionalProperties:false) ---
if [ "${HAS_JSONSCHEMA}" -eq 1 ]; then
  jq '.checks[2].id = "ac-present-testable"' "${TMP}/clear.json" > "${TMP}/story-gate.json"
  if bash "${RECORD}" --in "${TMP}/story-gate.json" --out "${TMP}/out-sgate.json" >/dev/null 2>&1; then
    die "a user-story gate id was accepted on an epic record (expected exit 1)"
  else
    pass "story gate ids are rejected by the epic gate enum"
  fi

  jq '. + {bogus_field: "x"}' "${TMP}/clear.json" > "${TMP}/bad-key.json"
  if bash "${RECORD}" --in "${TMP}/bad-key.json" --out "${TMP}/out-key.json" >/dev/null 2>&1; then
    die "an unknown top-level key was accepted (additionalProperties not enforced)"
  else
    pass "unknown top-level key rejected by additionalProperties:false"
  fi
else
  echo "PASS: (skipped) gate-enum / additionalProperties assertions — python jsonschema not installed"
fi

# --- clarifications: --set-clarification requires a lens ---
printf '{"state":"awaiting-ba","nonce":"n1","rounds":1}\n' > "${TMP}/c-be.json"
if bash "${RECORD}" --in "${TMP}/out-lying.json" --out "${TMP}/out-nolens.json" \
  --set-clarification "${TMP}/c-be.json" >/dev/null 2>&1; then
  die "--set-clarification without --lens was accepted"
else
  pass "--set-clarification without --lens is rejected"
fi

if bash "${RECORD}" --in "${TMP}/out-lying.json" --out "${TMP}/out-badlens.json" \
  --lens qa --set-clarification "${TMP}/c-be.json" >/dev/null 2>&1; then
  die "--lens qa was accepted (expected be|fe|ba)"
else
  pass "--lens rejects a lens outside be|fe|ba"
fi

# --- clarifications: upsert BY LENS, never duplicated ---
bash "${RECORD}" --in "${TMP}/out-lying.json" --out "${TMP}/threads.json" \
  --lens be --set-clarification "${TMP}/c-be.json" >/dev/null
printf '{"state":"awaiting-ba","nonce":"n1","rounds":2}\n' > "${TMP}/c-be2.json"
bash "${RECORD}" --in "${TMP}/threads.json" --out "${TMP}/threads.json" \
  --lens be --set-clarification "${TMP}/c-be2.json" >/dev/null
printf '{"state":"skipped"}\n' > "${TMP}/c-ba.json"
bash "${RECORD}" --in "${TMP}/threads.json" --out "${TMP}/threads.json" \
  --lens ba --set-clarification "${TMP}/c-ba.json" >/dev/null

if [ "$(jq '.clarifications | length' "${TMP}/threads.json")" = "2" ] \
  && [ "$(jq -r '.clarifications[] | select(.lens == "be") | .rounds' "${TMP}/threads.json")" = "2" ] \
  && [ "$(jq -r '.clarifications[] | select(.lens == "be") | .nonce' "${TMP}/threads.json")" = "n1" ] \
  && [ "$(jq -r '.clarifications[] | select(.lens == "ba") | .state' "${TMP}/threads.json")" = "skipped" ]; then
  pass "clarifications upsert by lens: a second round updates the thread instead of duplicating it"
else
  die "clarifications were not upserted by lens: $(jq -c .clarifications "${TMP}/threads.json")"
fi

# --- handoff: assignee + transition merge, and a skip is recorded not fatal ---
printf '{"assignee_set_to":"acct-ba","assigned_at":"2026-08-11T09:00:00Z","status_from":"To Do","status_to":"Waiting for BA","transition_id":"31"}\n' \
  > "${TMP}/handoff.json"
bash "${RECORD}" --in "${TMP}/threads.json" --out "${TMP}/handoff-out.json" \
  --set-handoff "${TMP}/handoff.json" >/dev/null
printf '{"transition_skipped_reason":"no-matching-transition"}\n' > "${TMP}/handoff-skip.json"
bash "${RECORD}" --in "${TMP}/handoff-out.json" --out "${TMP}/handoff-out.json" \
  --set-handoff "${TMP}/handoff-skip.json" >/dev/null

if [ "$(jq -r .handoff.assignee_set_to "${TMP}/handoff-out.json")" = "acct-ba" ] \
  && [ "$(jq -r .handoff.status_to "${TMP}/handoff-out.json")" = "Waiting for BA" ] \
  && [ "$(jq -r .handoff.transition_skipped_reason "${TMP}/handoff-out.json")" = "no-matching-transition" ] \
  && [ "$(jq '.clarifications | length' "${TMP}/handoff-out.json")" = "2" ]; then
  pass "--set-handoff merges without dropping earlier handoff fields or the lens threads"
else
  die "--set-handoff did not merge correctly"
fi

# =====================================================================
# jira-status-match.sh — the transition chooser used by the handoff
# =====================================================================

cat > "${TMP}/transitions.json" <<'EOF'
{"transitions":[
  {"id":"11","name":"Start","to":{"name":"In Progress"}},
  {"id":"31","name":"Ask BA","to":{"name":"Waiting for BA"}},
  {"id":"41","name":"Review","to":{"name":"In Review"}}
]}
EOF

M="$(bash "${MATCH}" --transitions "${TMP}/transitions.json")"
if [ "$(printf '%s' "${M}" | jq -r .matched)" = "true" ] \
  && [ "$(printf '%s' "${M}" | jq -r .transition_id)" = "31" ] \
  && [ "$(printf '%s' "${M}" | jq -r .to_status)" = "Waiting for BA" ]; then
  pass "match picks the first available candidate status in order"
else
  die "candidate matching picked the wrong transition: ${M}"
fi

M="$(bash "${MATCH}" --transitions "${TMP}/transitions.json" --prefer "In Review")"
if [ "$(printf '%s' "${M}" | jq -r .transition_id)" = "41" ] \
  && [ "$(printf '%s' "${M}" | jq -r .matched_by)" = "prefer:In Review" ]; then
  pass "--prefer overrides the candidate order"
else
  die "--prefer did not win over the candidate list: ${M}"
fi

# An unavailable --prefer must NOT silently fall back to another status.
M="$(bash "${MATCH}" --transitions "${TMP}/transitions.json" --prefer "Clarification")"
if [ "$(printf '%s' "${M}" | jq -r .matched)" = "false" ] \
  && [ "$(printf '%s' "${M}" | jq -r .reason)" = "preferred-status-not-available" ]; then
  pass "an unavailable --prefer is a skip, never a silent substitution"
else
  die "--prefer fell through to a different status: ${M}"
fi

M="$(bash "${MATCH}" --transitions "${TMP}/transitions.json" --current-status "Waiting for BA")"
if [ "$(printf '%s' "${M}" | jq -r .reason)" = "already-in-target-status" ]; then
  pass "a ticket already in a candidate status is not re-transitioned"
else
  die "already-in-target-status not detected: ${M}"
fi

printf '[{"id":"1","name":"Done","to":{"name":"Done"}}]\n' > "${TMP}/no-clarify.json"
M="$(bash "${MATCH}" --transitions "${TMP}/no-clarify.json")"
if [ "$(printf '%s' "${M}" | jq -r .matched)" = "false" ] \
  && [ "$(printf '%s' "${M}" | jq -r .reason)" = "no-matching-transition" ] \
  && [ "$(printf '%s' "${M}" | jq -r '.available[0]')" = "Done" ]; then
  pass "no clarification transition -> matched=false with the available statuses named"
else
  die "no-match case did not report available statuses: ${M}"
fi

# A workflow with no clarification transition must not fail the run.
if bash "${MATCH}" --transitions "${TMP}/no-clarify.json" >/dev/null 2>&1; then
  pass "a skipped transition exits 0 (the comment still posts)"
else
  die "no-match exited non-zero — it would abort the comment flow"
fi

# Malformed input IS an error (exit 1) — that is a bug, not a workflow shape.
printf '{"foo":1}\n' > "${TMP}/bad-transitions.json"
if bash "${MATCH}" --transitions "${TMP}/bad-transitions.json" >/dev/null 2>&1; then
  die "malformed transitions payload was accepted"
else
  pass "malformed transitions payload exits 1"
fi

if [ "${fail}" -ne 0 ]; then
  echo "test-epic-verify-contracts: FAIL"
  exit 1
fi
echo "test-epic-verify-contracts: all PASS"
exit 0
