#!/usr/bin/env bash
# test-prompt-cache-1h.sh
# Behavior verification test for enable-1h-cache.sh
#
# Test contents:
#   1. Append to new env.local (ENABLE_PROMPT_CACHING_1H=1 is written)
#   2. Idempotency (running twice leaves only one such line)
#   3. No interference with existing other-key lines (other keys preserved)
#   4. Warn and exit 1 when the same key exists with a different value
#   5. env.local with ENABLE_PROMPT_CACHING_1H=1 propagates to env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_SCRIPT="${ROOT_DIR}/scripts/enable-1h-cache.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass_test() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail_test() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Temporary directory for tests (git init needed to mimic a git repo)
setup_tmp_repo() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  git -C "${tmp_dir}" init -q
  echo "${tmp_dir}"
}

cleanup_tmp() {
  local dir="$1"
  rm -rf "${dir}"
}

# ---------- Test 1: script exists and is executable ----------
echo "--- Test 1: script existence and executable permission ---"
if [[ -f "${TARGET_SCRIPT}" ]]; then
  pass_test "enable-1h-cache.sh exists"
else
  fail_test "enable-1h-cache.sh does not exist (path: ${TARGET_SCRIPT})"
fi

if [[ -x "${TARGET_SCRIPT}" ]]; then
  pass_test "enable-1h-cache.sh is executable"
else
  fail_test "enable-1h-cache.sh is not executable"
fi

# ---------- Test 2: append to new env.local ----------
echo "--- Test 2: append to new env.local ---"
TMP_REPO="$(setup_tmp_repo)"

# Run with env.local absent
if (cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1); then
  if [[ -f "${TMP_REPO}/env.local" ]]; then
    pass_test "env.local was newly created"
  else
    fail_test "env.local was not created"
  fi

  if grep -qE "^export ENABLE_PROMPT_CACHING_1H=1$" "${TMP_REPO}/env.local"; then
    pass_test "ENABLE_PROMPT_CACHING_1H=1 was written to env.local"
  else
    fail_test "ENABLE_PROMPT_CACHING_1H=1 not found in env.local"
  fi
else
  fail_test "script execution failed (new env.local)"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Test 3: idempotency (run twice) ----------
echo "--- Test 3: idempotency ---"
TMP_REPO="$(setup_tmp_repo)"

(cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1)
(cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1)

COUNT=$(grep -cE "^export ENABLE_PROMPT_CACHING_1H=1$" "${TMP_REPO}/env.local" 2>/dev/null || echo "0")
if [[ "${COUNT}" -eq 1 ]]; then
  pass_test "ENABLE_PROMPT_CACHING_1H=1 stays a single line after running twice (idempotent)"
else
  fail_test "idempotency violation: ENABLE_PROMPT_CACHING_1H=1 exists on ${COUNT} lines"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Test 4: no interference with existing other-key lines ----------
echo "--- Test 4: no interference with existing other-key lines ---"
TMP_REPO="$(setup_tmp_repo)"
echo "SOME_OTHER_KEY=hello" > "${TMP_REPO}/env.local"

(cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1)

if grep -qE "^SOME_OTHER_KEY=hello$" "${TMP_REPO}/env.local"; then
  pass_test "existing key SOME_OTHER_KEY was preserved"
else
  fail_test "existing key SOME_OTHER_KEY disappeared"
fi

if grep -qE "^export ENABLE_PROMPT_CACHING_1H=1$" "${TMP_REPO}/env.local"; then
  pass_test "ENABLE_PROMPT_CACHING_1H=1 was appended"
else
  fail_test "ENABLE_PROMPT_CACHING_1H=1 was not appended"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Test 5: exit 1 when same key exists with a different value ----------
echo "--- Test 5: exit 1 when same key has a different value ---"
TMP_REPO="$(setup_tmp_repo)"
echo "ENABLE_PROMPT_CACHING_1H=0" > "${TMP_REPO}/env.local"

if (cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1); then
  fail_test "exit 0 even for same key with different value (expected exit 1)"
else
  pass_test "exit 1 returned for same key with different value"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Test 6: env propagation simulation ----------
# When env.local is sourced, ENABLE_PROMPT_CACHING_1H should be set
echo "--- Test 6: env propagation when env.local is sourced ---"
TMP_REPO="$(setup_tmp_repo)"
(cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1)

# Source env.local and check the variable is set
SOURCED_VALUE=$(bash -c "source '${TMP_REPO}/env.local' 2>/dev/null; echo \"\${ENABLE_PROMPT_CACHING_1H:-UNSET}\"")
if [[ "${SOURCED_VALUE}" == "1" ]]; then
  pass_test "sourcing env.local sets ENABLE_PROMPT_CACHING_1H=1 as an environment variable"
else
  fail_test "after sourcing env.local, ENABLE_PROMPT_CACHING_1H is '${SOURCED_VALUE}' instead of expected '1'"
fi

# Critical: verify a sourced env.local propagates as env to subprocesses (e.g. claude)
# Without the `export KEY=VALUE` form it is not inherited by subprocesses (stays shell-local)
CHILD_VALUE=$(bash -c "source '${TMP_REPO}/env.local' 2>/dev/null; bash -c 'echo \"\${ENABLE_PROMPT_CACHING_1H:-UNSET}\"'")
if [[ "${CHILD_VALUE}" == "1" ]]; then
  pass_test "after sourcing env.local, ENABLE_PROMPT_CACHING_1H=1 also propagates to subprocess (child bash) (export confirmed)"
else
  fail_test "in subprocess after sourcing env.local, ENABLE_PROMPT_CACHING_1H is '${CHILD_VALUE}' instead of expected '1' — missing export"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Result summary ----------
echo ""
echo "========================================"
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "========================================"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi

exit 0
