#!/bin/bash
# test-record-review-calibration.sh
# smoke test for record-review-calibration.sh
#
# Test list:
#   1. arg parsing: exit 1 when no input file
#   2. arg parsing: exit 3 for a nonexistent file
#   3. arg parsing: normal exit without calibration (exit 0, no output)
#   4. arg parsing: exit 4 for an invalid label
#   5. arg parsing: --review-result flag does not pollute positionals
#   6. count both critical_issues[] and gaps[severity:critical]
#   7. findings[severity:high] x2 -> major_count = 2
#   8. gaps[severity:major] x1 + findings[severity:high] x1 -> major_count = 2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="${PROJECT_ROOT}/scripts/record-review-calibration.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

pass=0
fail=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL: $desc"
    echo "        expected: $expected"
    echo "        actual:   $actual"
    fail=$((fail + 1))
  fi
}

# ---- Prepare shared input files ----

# Minimal input with calibration
cat > "${TMP_DIR}/with-cal.json" <<'EOF'
{
  "schema_version": "review-result.v1",
  "verdict": "REQUEST_CHANGES",
  "reviewer_profile": "static",
  "calibration": {
    "label": "false_positive",
    "source": "manual",
    "notes": "test note",
    "prompt_hint": "",
    "few_shot_ready": true
  },
  "gaps": []
}
EOF

# Input without calibration
cat > "${TMP_DIR}/no-cal.json" <<'EOF'
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE",
  "reviewer_profile": "static"
}
EOF

# Invalid-label input
cat > "${TMP_DIR}/bad-label.json" <<'EOF'
{
  "schema_version": "review-result.v1",
  "verdict": "REQUEST_CHANGES",
  "reviewer_profile": "static",
  "calibration": {
    "label": "unknown_label",
    "source": "manual",
    "notes": "",
    "prompt_hint": "",
    "few_shot_ready": true
  }
}
EOF

# ---- Test 1: exit 1 when no input file ----
actual_exit=0
"$SCRIPT" 2>/dev/null || actual_exit=$?
assert_eq "test-1: no args → exit 1" "1" "$actual_exit"

# ---- Test 2: exit 3 for a nonexistent file ----
actual_exit=0
"$SCRIPT" "${TMP_DIR}/nonexistent.json" "${TMP_DIR}/out.jsonl" 2>/dev/null || actual_exit=$?
assert_eq "test-2: nonexistent file → exit 3" "3" "$actual_exit"

# ---- Test 3: exit 0 without calibration ----
actual_exit=0
"$SCRIPT" "${TMP_DIR}/no-cal.json" "${TMP_DIR}/out3.jsonl" 2>/dev/null || actual_exit=$?
assert_eq "test-3: no calibration → exit 0" "0" "$actual_exit"
# Output file must not be created
if [ ! -f "${TMP_DIR}/out3.jsonl" ]; then
  echo "  PASS: test-3b: output file is not created"
  pass=$((pass + 1))
else
  echo "  FAIL: test-3b: output file was created"
  fail=$((fail + 1))
fi

# ---- Test 4: exit 4 for an invalid label ----
actual_exit=0
"$SCRIPT" "${TMP_DIR}/bad-label.json" "${TMP_DIR}/out4.jsonl" 2>/dev/null || actual_exit=$?
assert_eq "test-4: invalid label → exit 4" "4" "$actual_exit"

# ---- Test 5: --review-result flag does not pollute positionals ----
# INPUT_FILE is recognized correctly even with --review-result placed before the input
actual_exit=0
"$SCRIPT" --review-result "${TMP_DIR}/with-cal.json" "${TMP_DIR}/with-cal.json" "${TMP_DIR}/out5.jsonl" 2>/dev/null || actual_exit=$?
assert_eq "test-5: --review-result flag does not pollute positionals → exit 0" "0" "$actual_exit"

# ---- Test 6: count both critical_issues[] and gaps[severity:critical] ----
cat > "${TMP_DIR}/dual-critical.json" <<'EOF'
{
  "schema_version": "review-result.v1",
  "verdict": "REQUEST_CHANGES",
  "reviewer_profile": "static",
  "calibration": {
    "label": "missed_bug",
    "source": "manual",
    "notes": "",
    "prompt_hint": "",
    "few_shot_ready": true
  },
  "critical_issues": [
    "legacy-format critical issue"
  ],
  "gaps": [
    {"severity": "critical", "issue": "normalized critical gap"},
    {"severity": "major",    "issue": "normalized major gap"}
  ]
}
EOF

OUT6="${TMP_DIR}/out6.jsonl"
"$SCRIPT" "${TMP_DIR}/dual-critical.json" "$OUT6" >/dev/null
actual_critical="$(jq -r '.critical_count' "$OUT6")"
actual_major="$(jq -r '.major_count' "$OUT6")"
assert_eq "test-6a: critical_issues[1] + gaps[critical][1] → critical_count = 2" "2" "$actual_critical"
assert_eq "test-6b: gaps[major][1] → major_count = 1" "1" "$actual_major"

# ---- Test 7: findings[severity:high] x2 -> major_count = 2 ----
cat > "${TMP_DIR}/high-findings.json" <<'EOF'
{
  "schema_version": "review-result.v1",
  "verdict": "REQUEST_CHANGES",
  "reviewer_profile": "static",
  "calibration": {
    "label": "false_negative",
    "source": "manual",
    "notes": "",
    "prompt_hint": "",
    "few_shot_ready": true
  },
  "findings": [
    {"severity": "high",   "title": "blocking finding 1"},
    {"severity": "high",   "title": "blocking finding 2"},
    {"severity": "medium", "title": "non-blocking finding"}
  ]
}
EOF

OUT7="${TMP_DIR}/out7.jsonl"
"$SCRIPT" "${TMP_DIR}/high-findings.json" "$OUT7" >/dev/null
actual_major7="$(jq -r '.major_count' "$OUT7")"
actual_critical7="$(jq -r '.critical_count' "$OUT7")"
assert_eq "test-7a: findings[high][2] → major_count = 2" "2" "$actual_major7"
assert_eq "test-7b: findings[medium] → critical_count = 0" "0" "$actual_critical7"

# ---- Test 8: gaps[major] x1 + findings[high] x1 -> major_count = 2 (sum of each source) ----
cat > "${TMP_DIR}/mixed-major.json" <<'EOF'
{
  "schema_version": "review-result.v1",
  "verdict": "REQUEST_CHANGES",
  "reviewer_profile": "static",
  "calibration": {
    "label": "overstrict_rule",
    "source": "manual",
    "notes": "",
    "prompt_hint": "",
    "few_shot_ready": true
  },
  "gaps": [
    {"severity": "major", "issue": "normalized major from gaps"}
  ],
  "findings": [
    {"severity": "high", "title": "raw high from companion"}
  ]
}
EOF

OUT8="${TMP_DIR}/out8.jsonl"
"$SCRIPT" "${TMP_DIR}/mixed-major.json" "$OUT8" >/dev/null
actual_major8="$(jq -r '.major_count' "$OUT8")"
assert_eq "test-8: gaps[major][1] + findings[high][1] → major_count = 2" "2" "$actual_major8"

# ---- Aggregate results ----
echo ""
echo "test-record-review-calibration: ${pass} passed, ${fail} failed"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
