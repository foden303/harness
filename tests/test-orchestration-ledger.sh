#!/usr/bin/env bash
# test-orchestration-ledger.sh
# Phase 90.1.1: orchestration ledger schema + delegation emit.
#
# Verifies:
#   - shared lib scripts/lib/orchestration-ledger.sh emits one fixed-field JSONL line
#   - the 8-field contract (ts, backend, subcommand, write, exit_code, duration_ms,
#     session_id, counts) and nullable exit_code/duration_ms
#   - counts flag derives from subcommand (task/review/adversarial-review -> true)
#   - no prompt/secret leaks into the ledger (orch_emit_ledger has no prompt param)
#   - fail-open: a ledger write failure never changes the caller's exit code

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB="${REPO_ROOT}/scripts/lib/orchestration-ledger.sh"
SCHEMA="${REPO_ROOT}/skills/harness-progress/schemas/orchestration-ledger.v1.schema.json"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/orch-ledger-test.XXXXXX")"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# 1. lib + schema exist
# ---------------------------------------------------------------------------
[ -f "${LIB}" ] && ok "lib exists" || ng "lib missing: ${LIB}"
[ -f "${SCHEMA}" ] && ok "schema exists" || ng "schema missing: ${SCHEMA}"

if [ ! -f "${LIB}" ]; then
  printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
  exit 1
fi

# shellcheck source=/dev/null
. "${LIB}"

# ---------------------------------------------------------------------------
# 2. counts derivation
# ---------------------------------------------------------------------------
[ "$(orch_counts_for task)" = "true" ] && ok "counts task=true" || ng "counts task"
[ "$(orch_counts_for review)" = "true" ] && ok "counts review=true" || ng "counts review"
[ "$(orch_counts_for adversarial-review)" = "true" ] && ok "counts adversarial-review=true" || ng "counts adversarial-review"
[ "$(orch_counts_for status)" = "false" ] && ok "counts status=false" || ng "counts status"
[ "$(orch_counts_for setup)" = "false" ] && ok "counts setup=false" || ng "counts setup"

# ---------------------------------------------------------------------------
# 3. emit writes one valid 8-field JSON line
# ---------------------------------------------------------------------------
LEDGER="${TMP}/ledger.jsonl"
HARNESS_ORCHESTRATION_LEDGER="${LEDGER}" CLAUDE_SESSION_ID="sess-abc" \
  orch_emit_ledger "worker" "task" "1" "0" "123" || true

if [ -f "${LEDGER}" ] && [ "$(wc -l <"${LEDGER}" | tr -d ' ')" = "1" ]; then
  ok "emit wrote exactly one line"
else
  ng "emit did not write exactly one line"
fi

if command -v jq >/dev/null 2>&1 && [ -f "${LEDGER}" ]; then
  line="$(tail -1 "${LEDGER}")"
  keys="$(printf '%s' "${line}" | jq -r 'keys_unsorted | join(",")' 2>/dev/null || echo "")"
  expect="ts,backend,subcommand,write,exit_code,duration_ms,session_id,counts"
  sorted_keys="$(printf '%s' "${line}" | jq -r 'keys | join(",")' 2>/dev/null || echo "")"
  sorted_expect="$(printf '%s\n' "${expect}" | tr ',' '\n' | sort | paste -sd, -)"
  [ "${sorted_keys}" = "${sorted_expect}" ] && ok "ledger has exactly 8 contract fields" || ng "ledger fields mismatch: got [${sorted_keys}]"

  [ "$(printf '%s' "${line}" | jq -r '.backend')" = "worker" ] && ok "field backend" || ng "field backend"
  [ "$(printf '%s' "${line}" | jq -r '.subcommand')" = "task" ] && ok "field subcommand" || ng "field subcommand"
  [ "$(printf '%s' "${line}" | jq -r '.write')" = "true" ] && ok "field write=true" || ng "field write"
  [ "$(printf '%s' "${line}" | jq -r '.exit_code')" = "0" ] && ok "field exit_code=0" || ng "field exit_code"
  [ "$(printf '%s' "${line}" | jq -r '.duration_ms')" = "123" ] && ok "field duration_ms=123" || ng "field duration_ms"
  [ "$(printf '%s' "${line}" | jq -r '.session_id')" = "sess-abc" ] && ok "field session_id" || ng "field session_id"
  [ "$(printf '%s' "${line}" | jq -r '.counts')" = "true" ] && ok "field counts=true" || ng "field counts"
else
  ng "jq unavailable or ledger missing (cannot validate fields)"
fi

# ---------------------------------------------------------------------------
# 4. nullable exit_code / duration_ms (exec-path delegations record null)
# ---------------------------------------------------------------------------
LEDGER2="${TMP}/ledger2.jsonl"
HARNESS_ORCHESTRATION_LEDGER="${LEDGER2}" \
  orch_emit_ledger "worker" "task" "1" "" "" || true
if command -v jq >/dev/null 2>&1 && [ -f "${LEDGER2}" ]; then
  line2="$(tail -1 "${LEDGER2}")"
  [ "$(printf '%s' "${line2}" | jq -r '.exit_code')" = "null" ] && ok "nullable exit_code" || ng "nullable exit_code"
  [ "$(printf '%s' "${line2}" | jq -r '.duration_ms')" = "null" ] && ok "nullable duration_ms" || ng "nullable duration_ms"
  [ "$(printf '%s' "${line2}" | jq -r '.counts')" = "true" ] && ok "worker task counts=true" || ng "worker task counts"
else
  ng "cannot validate nullable fields"
fi

# ---------------------------------------------------------------------------
# 5. fail-open: unwritable ledger path must not change caller exit code
# ---------------------------------------------------------------------------
# Point the ledger at a path whose parent cannot be created (a file used as a dir).
BLOCK="${TMP}/blockfile"
: >"${BLOCK}"
HARNESS_ORCHESTRATION_LEDGER="${BLOCK}/sub/ledger.jsonl" orch_emit_ledger "worker" "task" "0" "1" "5"
rc=$?
[ "${rc}" -eq 0 ] && ok "fail-open: emit returns 0 on unwritable path" || ng "fail-open broken (rc=${rc})"

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
[ "${FAIL}" -eq 0 ]
