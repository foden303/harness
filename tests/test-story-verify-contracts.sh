#!/usr/bin/env bash
# test-story-verify-contracts.sh — harness-story-verify contracts.
#
# Proves the story-verification.v1 schema and its two shell helpers:
#   - story-verify-record.sh writes a schema-valid story-verification.v1
#   - the verdict is DERIVED from the gates and overrides a wrong hand-written one
#   - n-a without a note (silent skip) is rejected
#   - invalid severity / result / unknown gate id / unknown key are rejected
#   - `verdict --in FILE` prints the derived verdict without writing
#   - --set-clarification merges and the result still validates
#   - story-verify-batch.sh init/re-init/set-state/next/summary contracts
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/story-verification.v1.json"
RECORD="${ROOT}/scripts/story-verify-record.sh"
BATCH="${ROOT}/scripts/story-verify-batch.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1" >&2; fail=1; }

# The record helper validates with jsonschema when it is importable and falls
# back to a minimal hand-rolled check otherwise. Assertions that only the full
# schema can catch are gated on this flag so the suite is valid on both paths.
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  HAS_JSONSCHEMA=1
else
  HAS_JSONSCHEMA=0
fi

# --- presence ---
[ -f "${SCHEMA}" ] || die "story-verification.v1 schema missing"
[ -x "${RECORD}" ] || die "story-verify-record.sh missing/not executable"
[ -x "${BATCH}" ]  || die "story-verify-batch.sh missing/not executable"

# Everything below runs inside TMP so no repo state is touched.
cd "${TMP}"

# draft_with VERDICT BLOCKER_RESULT QUESTIONS_JSON > FILE
draft_with() {
  jq -n \
    --arg verdict "$1" \
    --arg blocker_result "$2" \
    --argjson questions "$3" \
    '{
      issue_key: "PROJ-1",
      title: "As a user I want X",
      issue_type: "Story",
      verdict: $verdict,
      checks: [
        {id: "story-format",       severity: "blocker",  result: "pass", evidence: "As a user..."},
        {id: "ac-present-testable", severity: "blocker", result: $blocker_result, note: "n"},
        {id: "invest-sizing",      severity: "advisory", result: "pass"}
      ],
      questions: $questions
    }'
}

# --- happy path: all blockers pass, no questions -> clear ---
draft_with clear pass '[]' > "${TMP}/clear.json"
OUT="$(bash "${RECORD}" --in "${TMP}/clear.json" --out "${TMP}/out-clear.json")"
if [ -f "${OUT}" ] \
  && [ "$(jq -r .schema_version "${OUT}")" = "story-verification.v1" ] \
  && [ "$(jq -r .verdict "${OUT}")" = "clear" ] \
  && [ -n "$(jq -r .verified_at "${OUT}")" ]; then
  pass "record writes a schema-valid story-verification.v1 stamped verdict=clear"
else
  die "record output malformed for the clear happy path"
fi

# --- derivation overrides a wrong hand-written verdict ---
draft_with clear fail '[]' > "${TMP}/lying.json"
bash "${RECORD}" --in "${TMP}/lying.json" --out "${TMP}/out-lying.json" >/dev/null
if [ "$(jq -r .verdict "${TMP}/out-lying.json")" = "needs-clarification" ]; then
  pass "declared verdict=clear with a failing blocker is persisted as needs-clarification"
else
  die "hand-written verdict was not overridden by the failing blocker gate"
fi

# --- all blockers pass but questions[] non-empty -> needs-clarification ---
draft_with clear pass '[{"gate":"scope-boundaries","text":"Is X in scope?","why":"cannot size"}]' \
  > "${TMP}/questions.json"
bash "${RECORD}" --in "${TMP}/questions.json" --out "${TMP}/out-questions.json" >/dev/null
if [ "$(jq -r .verdict "${TMP}/out-questions.json")" = "needs-clarification" ]; then
  pass "passing blockers with a non-empty questions[] yields needs-clarification"
else
  die "non-empty questions[] did not force needs-clarification"
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
rm -f "${TMP}/never-written.json"
V="$(bash "${RECORD}" verdict --in "${TMP}/lying.json")"
if [ "${V}" = "needs-clarification" ] && [ ! -f "${TMP}/never-written.json" ]; then
  pass "verdict --in prints the derived verdict without writing a record"
else
  die "verdict subcommand did not print the derived verdict cleanly (got '${V}')"
fi

# --- silent-skip guard: n-a without a note ---
jq '.checks[1] = {id: "design-reference", severity: "advisory", result: "n-a"}' \
  "${TMP}/clear.json" > "${TMP}/na-nonote.json"
if bash "${RECORD}" --in "${TMP}/na-nonote.json" --out "${TMP}/out-na.json" >/dev/null 2>&1; then
  die "a check with result=n-a and no note was accepted (silent skip)"
else
  pass "n-a without a note is rejected (silent-skip guard)"
fi

# n-a WITH a note is fine.
jq '.checks[1] = {id: "design-reference", severity: "advisory", result: "n-a", note: "backend-only ticket"}' \
  "${TMP}/clear.json" > "${TMP}/na-note.json"
if bash "${RECORD}" --in "${TMP}/na-note.json" --out "${TMP}/out-na-ok.json" >/dev/null 2>&1; then
  pass "n-a with a note is accepted"
else
  die "n-a with a note was rejected"
fi

# --- invalid severity / result (caught on both validation paths) ---
jq '.checks[2].severity = "critical"' "${TMP}/clear.json" > "${TMP}/bad-sev.json"
if bash "${RECORD}" --in "${TMP}/bad-sev.json" --out "${TMP}/out-sev.json" >/dev/null 2>&1; then
  die "an invalid severity was accepted (expected exit 1)"
else
  pass "invalid severity is rejected"
fi

jq '.checks[2].result = "maybe"' "${TMP}/clear.json" > "${TMP}/bad-res.json"
if bash "${RECORD}" --in "${TMP}/bad-res.json" --out "${TMP}/out-res.json" >/dev/null 2>&1; then
  die "an invalid result was accepted (expected exit 1)"
else
  pass "invalid result is rejected"
fi

# --- schema-only assertions (enum of gate ids + additionalProperties:false) ---
if [ "${HAS_JSONSCHEMA}" -eq 1 ]; then
  jq '.checks[2].id = "not-a-real-gate"' "${TMP}/clear.json" > "${TMP}/bad-gate.json"
  if bash "${RECORD}" --in "${TMP}/bad-gate.json" --out "${TMP}/out-gate.json" >/dev/null 2>&1; then
    die "an unknown gate id was accepted (expected exit 1)"
  else
    pass "unknown gate id is rejected by the schema enum"
  fi

  jq '. + {bogus_field: "x"}' "${TMP}/clear.json" > "${TMP}/bad-key.json"
  if bash "${RECORD}" --in "${TMP}/bad-key.json" --out "${TMP}/out-key.json" >/dev/null 2>&1; then
    die "an unknown top-level key was accepted (additionalProperties not enforced)"
  else
    pass "unknown top-level key rejected by additionalProperties:false"
  fi
else
  echo "PASS: (skipped) unknown gate id / additionalProperties assertions — python jsonschema not installed"
fi

# --- --set-clarification merges and still validates ---
printf '{"nonce":"abc123","posted_comment_id":"10001","rounds":1}\n' > "${TMP}/clarif.json"
bash "${RECORD}" --in "${TMP}/questions.json" --out "${TMP}/out-clarif.json" \
  --set-clarification "${TMP}/clarif.json" >/dev/null
if [ "$(jq -r .clarification.nonce "${TMP}/out-clarif.json")" = "abc123" ] \
  && [ "$(jq -r .clarification.rounds "${TMP}/out-clarif.json")" = "1" ] \
  && [ "$(jq -r .verdict "${TMP}/out-clarif.json")" = "needs-clarification" ]; then
  pass "--set-clarification merges the clarification block and the record still validates"
else
  die "--set-clarification did not merge correctly"
fi

# --- batch: init ---
BFILE="$(bash "${BATCH}" init --batch-id b1 --mode epic --root PROJ-100 \
  --keys PROJ-1,PROJ-2,PROJ-3 --out "${TMP}/batch.json")"
if [ -f "${BFILE}" ] \
  && [ "$(jq -r '.tickets | length' "${BFILE}")" = "3" ] \
  && [ "$(jq -r '[.tickets[] | select(.state == "pending")] | length' "${BFILE}")" = "3" ]; then
  pass "init creates a batch with every ticket pending and returns the path"
else
  die "init did not create the expected batch"
fi

# --- batch: re-init preserves states and adds new keys as pending ---
bash "${BATCH}" set-state "${BFILE}" PROJ-1 clear
bash "${BATCH}" set-state "${BFILE}" PROJ-2 awaiting-ba
bash "${BATCH}" init --batch-id b1 --mode epic --root PROJ-100 \
  --keys PROJ-1,PROJ-2,PROJ-3,PROJ-4 --out "${BFILE}" >/dev/null
if [ "$(jq -r '.tickets[] | select(.key == "PROJ-1") | .state' "${BFILE}")" = "clear" ] \
  && [ "$(jq -r '.tickets[] | select(.key == "PROJ-2") | .state' "${BFILE}")" = "awaiting-ba" ] \
  && [ "$(jq -r '.tickets[] | select(.key == "PROJ-4") | .state' "${BFILE}")" = "pending" ] \
  && [ "$(jq -r '.tickets | length' "${BFILE}")" = "4" ]; then
  pass "re-init preserves existing ticket states and adds the new key as pending"
else
  die "re-init did not preserve existing states / add the new key"
fi

# --- batch: set-state validation ---
if bash "${BATCH}" set-state "${BFILE}" PROJ-3 bogus-state >/dev/null 2>&1; then
  die "set-state accepted an invalid state (expected exit 1)"
else
  pass "set-state rejects an invalid state"
fi

if bash "${BATCH}" set-state "${BFILE}" PROJ-999 clear >/dev/null 2>&1; then
  die "set-state accepted a key that is not in the batch (expected exit 1)"
else
  pass "set-state rejects a key not in the batch"
fi

# --- batch: next returns the first non-terminal ticket ---
# PROJ-1=clear (terminal), PROJ-2=awaiting-ba (non-terminal) -> PROJ-2
if [ "$(bash "${BATCH}" next "${BFILE}")" = "PROJ-2" ]; then
  pass "next returns the first non-terminal ticket"
else
  die "next did not return the first non-terminal ticket"
fi

# Drive every ticket into a terminal state (clear/answered/escalated/blocked).
bash "${BATCH}" set-state "${BFILE}" PROJ-2 answered
bash "${BATCH}" set-state "${BFILE}" PROJ-3 escalated
bash "${BATCH}" set-state "${BFILE}" PROJ-4 blocked
if [ -z "$(bash "${BATCH}" next "${BFILE}")" ]; then
  pass "next returns empty when every ticket is terminal"
else
  die "next returned a ticket even though all states are terminal"
fi

# --- batch: summary counts per state ---
SUM="$(bash "${BATCH}" summary "${BFILE}")"
if [ "${SUM#*total=4}" != "${SUM}" ] \
  && [ "${SUM#*clear=1}" != "${SUM}" ] \
  && [ "${SUM#*answered=1}" != "${SUM}" ] \
  && [ "${SUM#*escalated=1}" != "${SUM}" ] \
  && [ "${SUM#*blocked=1}" != "${SUM}" ]; then
  pass "summary prints per-state counts"
else
  die "summary output missing per-state counts: ${SUM}"
fi

# --- batch: init rejects an invalid mode ---
if bash "${BATCH}" init --batch-id b2 --mode sideways --keys PROJ-1 \
  --out "${TMP}/batch2.json" >/dev/null 2>&1; then
  die "init accepted an invalid --mode (expected exit 1)"
else
  pass "init rejects an invalid --mode"
fi

if [ "${fail}" -ne 0 ]; then
  echo "test-story-verify-contracts: FAIL"
  exit 1
fi
echo "test-story-verify-contracts: all PASS"
exit 0
