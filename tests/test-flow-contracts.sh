#!/usr/bin/env bash
# test-flow-contracts.sh — harness-flow Phase 1 contracts.
#
# Proves the requirement.v1 + flow-session.v1 schemas and their shell helpers:
#   - flow-session.sh init/status/set/validate round-trips
#   - additionalProperties:false rejects unknown keys
#   - invalid status is rejected
#   - flow-ingest-requirement.sh writes a schema-valid requirement.v1
#   - bad ingest input is rejected
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQ_SCHEMA="${ROOT}/templates/schemas/requirement.v1.json"
SESS_SCHEMA="${ROOT}/templates/schemas/flow-session.v1.json"
SESS="${ROOT}/scripts/flow-session.sh"
INGEST="${ROOT}/scripts/flow-ingest-requirement.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1" >&2; fail=1; }

# --- presence ---
[ -f "${REQ_SCHEMA}" ]  || die "requirement.v1 schema missing"
[ -f "${SESS_SCHEMA}" ] || die "flow-session.v1 schema missing"
[ -x "${SESS}" ]   || die "flow-session.sh missing/not executable"
[ -x "${INGEST}" ] || die "flow-ingest-requirement.sh missing/not executable"

# --- flow-session init + validate ---
SFILE="$(PROJECT_ROOT="${TMP}" bash "${SESS}" init --session-id t1 --source jira --source-ref PROJ-1 --out "${TMP}/session.json")"
if [ -f "${SFILE}" ] && [ "$(jq -r .status "${SFILE}")" = "ingesting" ]; then
  pass "init creates session with status=ingesting"
else
  die "init did not create expected session"
fi
if bash "${SESS}" validate "${SFILE}" >/dev/null 2>&1; then
  pass "fresh session validates"
else
  die "fresh session failed validation"
fi

# --- status transition + updated_at bump ---
before="$(jq -r .updated_at "${SFILE}")"
sleep 1
bash "${SESS}" status "${SFILE}" verifying
after="$(jq -r .updated_at "${SFILE}")"
if [ "$(jq -r .status "${SFILE}")" = "verifying" ] && [ "${before}" != "${after}" ]; then
  pass "status transition applies and bumps updated_at"
else
  die "status transition did not apply / did not bump updated_at"
fi

# --- invalid status rejected ---
if bash "${SESS}" status "${SFILE}" bogus-state >/dev/null 2>&1; then
  die "invalid status was accepted (expected exit 1)"
else
  pass "invalid status is rejected"
fi

# --- set / set-json ---
bash "${SESS}" set-json "${SFILE}" plans '["main"]'
bash "${SESS}" set "${SFILE}" requirement_path "${TMP}/requirement.json"
if [ "$(jq -r '.plans[0]' "${SFILE}")" = "main" ] && [ "$(jq -r .requirement_path "${SFILE}")" = "${TMP}/requirement.json" ]; then
  pass "set/set-json update fields"
else
  die "set/set-json did not update fields"
fi

# --- additionalProperties:false rejects unknown key ---
BADSESS="${TMP}/bad-session.json"
jq '. + {bogus_field: "x"}' "${SFILE}" > "${BADSESS}"
if bash "${SESS}" validate "${BADSESS}" >/dev/null 2>&1; then
  die "session with unknown key passed validation (additionalProperties not enforced)"
else
  pass "unknown key rejected by validation"
fi

# --- flow-ingest happy path ---
printf 'As a user I want X.\n' > "${TMP}/desc.txt"
printf 'Given A when B then C\nReturns 200 on success\n' > "${TMP}/ac.txt"
RFILE="$(bash "${INGEST}" \
  --source jira --source-ref PROJ-1 --title "Add X endpoint" \
  --description-file "${TMP}/desc.txt" \
  --acceptance-criteria-file "${TMP}/ac.txt" \
  --labels backend,api --issue-type Story --status "To Do" \
  --reporter-account-id acct-1 --mcp-available true \
  --out "${TMP}/requirement.json")"
if [ -f "${RFILE}" ] \
  && [ "$(jq -r .schema_version "${RFILE}")" = "requirement.v1" ] \
  && [ "$(jq -r '.acceptance_criteria | length' "${RFILE}")" = "2" ] \
  && [ "$(jq -r '.labels | length' "${RFILE}")" = "2" ]; then
  pass "ingest writes a valid requirement.v1 with criteria + labels"
else
  die "ingest output malformed"
fi

# --- flow-ingest merged multi-ticket feature ---
cat > "${TMP}/sources.json" <<'JSON'
[
  {"source":"jira","source_ref":"PROJ-1","title":"Part A"},
  {"source":"jira","source_ref":"PROJ-2","title":"Part B"}
]
JSON
MFILE="$(bash "${INGEST}" \
  --source jira --source-ref PROJ-1 --title "Feature (PROJ-1, PROJ-2)" \
  --description-file "${TMP}/desc.txt" \
  --acceptance-criteria-file "${TMP}/ac.txt" \
  --sources-file "${TMP}/sources.json" \
  --out "${TMP}/merged.json")"
if [ "$(jq -r '.sources | length' "${MFILE}")" = "2" ] \
  && [ "$(jq -r '.sources[1].source_ref' "${MFILE}")" = "PROJ-2" ] \
  && [ "$(jq -r .source_ref "${MFILE}")" = "PROJ-1" ]; then
  pass "merged multi-ticket ingest records sources[] with primary source_ref"
else
  die "merged ingest malformed"
fi

# --- flow-ingest rejects a malformed sources file ---
printf '{"not":"an array"}' > "${TMP}/badsources.json"
if bash "${INGEST}" --source jira --source-ref PROJ-1 --title Y \
  --sources-file "${TMP}/badsources.json" --out "${TMP}/z.json" >/dev/null 2>&1; then
  die "ingest accepted a malformed --sources-file (expected exit 1)"
else
  pass "ingest rejects a malformed --sources-file"
fi

# --- flow-ingest rejects bad source ---
if bash "${INGEST}" --source notreal --source-ref X --title Y --out "${TMP}/x.json" >/dev/null 2>&1; then
  die "ingest accepted an invalid --source (expected exit 1)"
else
  pass "ingest rejects invalid --source"
fi

if [ "${fail}" -ne 0 ]; then
  echo "test-flow-contracts: FAIL"
  exit 1
fi
echo "test-flow-contracts: all PASS"
exit 0
