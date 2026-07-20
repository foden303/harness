#!/bin/bash
# test-terminal-notify.sh
# Test for the CC 2.1.141+ hook `terminalSequence` output contract (Phase 69.1.5)
#
# Checks:
#   1. HARNESS_TERMINAL_NOTIFY unset -> emit no terminalSequence
#   2. bell mode -> BEL (\x07) only
#   3. osc9 mode -> ESC ]9; <text> BEL
#   4. title mode -> ESC ]0; <text> BEL
#   5. notify mode -> ESC ]777;notify; <title>; <body> BEL
#   6. unknown mode -> silent (empty string)
#   7. empty title -> empty string
#   8. title with control chars -> sanitized
#   9. JSON encoding is valid
#   10. webhook-notify.sh returns JSON containing terminalSequence
#   11. notification-handler.sh returns terminalSequence for permission_prompt
#   12. notification-handler.sh returns no terminalSequence for unknown type

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

pass() {
  echo "  ✓ $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  ✗ $1" >&2
  FAIL=$((FAIL + 1))
}

# ============================================================
# Direct helper tests
# ============================================================
echo "1. Direct test of the terminal-notify.sh helper"

# source so the functions can be called
unset HARNESS_TERMINAL_NOTIFY
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/terminal-notify.sh"

# Test 1: unset → empty
unset HARNESS_TERMINAL_NOTIFY
out="$(build_terminal_sequence "title" "body")"
if [ -z "${out}" ]; then
  pass "1.1 HARNESS_TERMINAL_NOTIFY unset → empty string"
else
  fail "1.1 HARNESS_TERMINAL_NOTIFY unset produced output: [${out}]"
fi

# Test 2: "0" → empty
export HARNESS_TERMINAL_NOTIFY=0
out="$(build_terminal_sequence "title")"
if [ -z "${out}" ]; then
  pass "1.2 HARNESS_TERMINAL_NOTIFY=0 → empty string"
else
  fail "1.2 HARNESS_TERMINAL_NOTIFY=0 produced output"
fi

# Test 3: bell → BEL only
export HARNESS_TERMINAL_NOTIFY=bell
out="$(build_terminal_sequence "title")"
expected="$(printf '\x07')"
if [ "${out}" = "${expected}" ]; then
  pass "1.3 bell mode → BEL only (1 byte)"
else
  fail "1.3 bell mode differs from expected: byte count=${#out}"
fi

# Test 4: osc9 → ESC ]9; ... BEL
export HARNESS_TERMINAL_NOTIFY=osc9
out="$(build_terminal_sequence "Build complete")"
expected="$(printf '\x1b]9;Build complete\x07')"
if [ "${out}" = "${expected}" ]; then
  pass "1.4 osc9 mode → ESC ]9; ... BEL"
else
  fail "1.4 osc9 mode differs from expected"
fi

# Test 5: title → ESC ]0; ... BEL
export HARNESS_TERMINAL_NOTIFY=title
out="$(build_terminal_sequence "My Session")"
expected="$(printf '\x1b]0;My Session\x07')"
if [ "${out}" = "${expected}" ]; then
  pass "1.5 title mode → ESC ]0; ... BEL"
else
  fail "1.5 title mode differs from expected"
fi

# Test 6: notify with body → OSC 777;notify; ... ; ... BEL
export HARNESS_TERMINAL_NOTIFY=notify
out="$(build_terminal_sequence "Build complete" "all tests pass")"
expected="$(printf '\x1b]777;notify;Build complete;all tests pass\x07')"
if [ "${out}" = "${expected}" ]; then
  pass "1.6 notify mode (with body) → OSC 777;notify;title;body;BEL"
else
  fail "1.6 notify mode differs from expected"
fi

# Test 7: notify without body → OSC 777;notify;title;BEL
export HARNESS_TERMINAL_NOTIFY=notify
out="$(build_terminal_sequence "Build complete")"
expected="$(printf '\x1b]777;notify;Build complete\x07')"
if [ "${out}" = "${expected}" ]; then
  pass "1.7 notify mode (no body) → OSC 777;notify;title;BEL"
else
  fail "1.7 notify mode (no body) differs from expected"
fi

# Test 8: unknown mode → silent
export HARNESS_TERMINAL_NOTIFY=unknown
out="$(build_terminal_sequence "title")"
if [ -z "${out}" ]; then
  pass "1.8 unknown mode → empty string (silent ignore)"
else
  fail "1.8 unknown mode produced output"
fi

# Test 9: empty title (osc9) → empty
export HARNESS_TERMINAL_NOTIFY=osc9
out="$(build_terminal_sequence "" "body only")"
if [ -z "${out}" ]; then
  pass "1.9 empty title (osc9) → empty string"
else
  fail "1.9 empty title (osc9) still produced output"
fi

# Test 9.5: empty title (bell) → BEL (bell needs no title)
export HARNESS_TERMINAL_NOTIFY=bell
out="$(build_terminal_sequence "")"
expected="$(printf '\x07')"
if [ "${out}" = "${expected}" ]; then
  pass "1.9.5 bell mode fires BEL even with an empty title"
else
  fail "1.9.5 bell mode did not fire with an empty title (over-aggressive empty-title guard)"
fi

# Test 9.6: empty title (mode=1, alias for bell) → BEL
export HARNESS_TERMINAL_NOTIFY=1
out="$(build_terminal_sequence "")"
if [ "${out}" = "${expected}" ]; then
  pass "1.9.6 mode=1 alias fires BEL even with an empty title"
else
  fail "1.9.6 mode=1 alias did not fire with an empty title"
fi

# Test 10: control chars stripped
export HARNESS_TERMINAL_NOTIFY=osc9
# input contains \n, \x1b, \x07 — all should be stripped
raw_input="$(printf 'bad\ntitle\x1b\x07evil')"
out="$(build_terminal_sequence "${raw_input}")"
# expected: after control-char removal "badtitleevil" + ESC ]9; ... BEL
expected="$(printf '\x1b]9;badtitleevil\x07')"
if [ "${out}" = "${expected}" ]; then
  pass "1.10 control chars (\\n, ESC, BEL) are stripped from the title"
else
  fail "1.10 control-char stripping differs from expected"
fi

# ============================================================
# JSON encoding tests
# ============================================================
echo ""
echo "2. JSON encoding test"

export HARNESS_TERMINAL_NOTIFY=osc9
seq="$(build_terminal_sequence "Build")"
encoded="$(encode_terminal_sequence_json "${seq}")"
# if jq is present, verify it is a valid JSON string literal
if command -v jq >/dev/null 2>&1; then
  decoded="$(printf '%s' "${encoded}" | jq -r . 2>/dev/null)" || decoded=""
  if [ "${decoded}" = "${seq}" ]; then
    pass "2.1 encode_terminal_sequence_json: round-trips through jq"
  else
    fail "2.1 jq round-trip failed: encoded=${encoded}, decoded=[${decoded}]"
  fi
else
  echo "  (skip 2.1: jq absent)"
fi

# Empty input
out="$(encode_terminal_sequence_json "")"
if [ -z "${out}" ]; then
  pass "2.2 encode_terminal_sequence_json('') → empty"
else
  fail "2.2 empty input produced output"
fi

# ============================================================
# webhook-notify.sh integration
# ============================================================
echo ""
echo "3. webhook-notify.sh integration test"

# Test: HARNESS_TERMINAL_NOTIFY set, HARNESS_WEBHOOK_URL unset → local notify only
unset HARNESS_WEBHOOK_URL
export HARNESS_TERMINAL_NOTIFY=osc9
out="$(echo '{}' | bash "${REPO_ROOT}/scripts/hook-handlers/webhook-notify.sh" build-complete 2>/dev/null)"
if command -v python3 >/dev/null 2>&1; then
  has_ts="$(printf '%s' "${out}" | python3 -c "import sys, json
try:
    d = json.loads(sys.stdin.read())
    print('yes' if 'terminalSequence' in d else 'no')
except Exception:
    print('parse-fail')" 2>/dev/null)"
  if [ "${has_ts}" = "yes" ]; then
    pass "3.1 HARNESS_TERMINAL_NOTIFY=osc9 + URL unset → JSON containing terminalSequence"
  else
    fail "3.1 terminalSequence not present in JSON: ${out}"
  fi
fi

# Test: unset → no terminalSequence (existing behavior preserved)
unset HARNESS_TERMINAL_NOTIFY
unset HARNESS_WEBHOOK_URL
out="$(echo '{}' | bash "${REPO_ROOT}/scripts/hook-handlers/webhook-notify.sh" some-event 2>/dev/null)"
if command -v python3 >/dev/null 2>&1; then
  has_ts="$(printf '%s' "${out}" | python3 -c "import sys, json
try:
    d = json.loads(sys.stdin.read())
    print('yes' if 'terminalSequence' in d else 'no')
except Exception:
    print('parse-fail')" 2>/dev/null)"
  if [ "${has_ts}" = "no" ]; then
    pass "3.2 HARNESS_TERMINAL_NOTIFY unset → existing behavior preserved (no terminalSequence)"
  else
    fail "3.2 existing behavior broke (terminalSequence leaked): ${out}"
  fi
fi

# ============================================================
# notification-handler.sh integration
# ============================================================
echo ""
echo "4. notification-handler.sh integration test"

export HARNESS_TERMINAL_NOTIFY=osc9
out="$(echo '{"notification_type":"permission_prompt","agent_type":"worker","session_id":"t1"}' \
  | bash "${REPO_ROOT}/scripts/hook-handlers/notification-handler.sh" 2>/dev/null)"
if command -v python3 >/dev/null 2>&1; then
  has_ts="$(printf '%s' "${out}" | python3 -c "import sys, json
try:
    d = json.loads(sys.stdin.read())
    print('yes' if 'terminalSequence' in d else 'no')
except Exception:
    print('parse-fail')" 2>/dev/null)"
  if [ "${has_ts}" = "yes" ]; then
    pass "4.1 permission_prompt + HARNESS_TERMINAL_NOTIFY=osc9 → contains terminalSequence"
  else
    fail "4.1 permission_prompt does not contain terminalSequence: ${out}"
  fi
fi

# unknown notification_type → no terminalSequence (silent)
export HARNESS_TERMINAL_NOTIFY=osc9
out="$(echo '{"notification_type":"unknown_xyz"}' \
  | bash "${REPO_ROOT}/scripts/hook-handlers/notification-handler.sh" 2>/dev/null)"
if [ -z "${out}" ]; then
  pass "4.2 unknown notification_type → no output (silent)"
else
  fail "4.2 unknown notification_type produced output: ${out}"
fi

# unset → existing behavior (silent)
unset HARNESS_TERMINAL_NOTIFY
out="$(echo '{"notification_type":"permission_prompt"}' \
  | bash "${REPO_ROOT}/scripts/hook-handlers/notification-handler.sh" 2>/dev/null)"
if [ -z "${out}" ]; then
  pass "4.3 HARNESS_TERMINAL_NOTIFY unset → existing behavior preserved (silent)"
else
  fail "4.3 existing behavior broke: ${out}"
fi

# ============================================================
# Rule presence checks
# ============================================================
echo ""
echo "5. Rule / docs presence check"

# NOTE: The version-pinned rule .claude/rules/hooks-2.1.139-plus.md was removed in
# Phase 91.7 (version-pinned rules superseded by capability detection). The terminal
# notify runtime behavior is still validated above (sections 1-4); only the rule-file
# presence assertion is dropped.

policy_file="${REPO_ROOT}/docs/agent-view-policy.md"
if [ -f "${policy_file}" ]; then
  required_anchors=(
    'claude agents'
    '--dangerously-skip-permissions'
    'permission mode'
    'breezing'
  )
  missing=0
  for anchor in "${required_anchors[@]}"; do
    if ! grep -qF -- "${anchor}" "${policy_file}"; then
      fail "5.x ${policy_file} is missing '${anchor}'"
      missing=$((missing + 1))
    fi
  done
  if [ "${missing}" -eq 0 ]; then
    pass "5.2 agent-view-policy.md contains all 4 required anchors"
  fi
else
  fail "5.2 ${policy_file} does not exist"
fi

# ============================================================
# Template baseline checks
# ============================================================
echo ""
echo "6. Template baseline check"

template_file="${REPO_ROOT}/templates/claude/settings.security.json.template"
if [ -f "${template_file}" ]; then
  # parse JSON and strictly verify values (not just key presence, but contents)
  if python3 - "${template_file}" >/dev/null 2>&1 <<'PY'
import json, sys
expected_hard_deny = {
    "Bash(sudo:*)",
    "Bash(rm -rf:*)",
    "Bash(rm -fr:*)",
    "Bash(git push -f:*)",
    "Bash(git push --force:*)",
    "Bash(git reset --hard:*)",
    "mcp__codex__*",
}
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
assert data.get('worktree', {}).get('baseRef') == 'fresh', \
    f"worktree.baseRef expected 'fresh', got {data.get('worktree', {}).get('baseRef')!r}"
actual = set(data.get('autoMode', {}).get('hard_deny', []))
assert actual == expected_hard_deny, \
    f"autoMode.hard_deny mismatch: missing={expected_hard_deny - actual}, extra={actual - expected_hard_deny}"
PY
  then
    pass "6.1 template worktree.baseRef='fresh' + autoMode.hard_deny baseline of 7 match expected"
  else
    fail "6.1 template worktree.baseRef or autoMode.hard_deny baseline does not match expected"
  fi

  # JSON validity (redundant with above but keeps a discrete check)
  if python3 -m json.tool "${template_file}" >/dev/null 2>&1; then
    pass "6.2 template is valid JSON"
  else
    fail "6.2 template is not valid JSON"
  fi
else
  fail "6.1 ${template_file} does not exist"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=========================================="
echo "Test results"
echo "=========================================="
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"

if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
