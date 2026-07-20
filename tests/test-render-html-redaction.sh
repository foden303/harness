#!/bin/bash
# tests/test-render-html-redaction.sh
# Phase 65.3.4 - machine verification of render-html.sh --with-redaction
#
# Verification cases (corresponds to Plans.md §65.3.4 DoD d):
#   1. all clean       - nothing to redact -> exit 0, HTML generated
#   2. dict hit only   - dict-matching word -> exit 0, HTML generated (redacted)
#   3. no flag         - without --with-redaction -> existing behavior preserved

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT="$ROOT_DIR/scripts/render-html.sh"
TEMPLATE="test-fixture"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

if [[ ! -x "$SCRIPT" ]]; then
  fail "render-html.sh not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "render-html.sh exists and is executable"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-render-redaction.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# ============================================================
# Case 1: all clean - nothing to redact, exit 0, HTML generated
# ============================================================

DATA1="$TMP_DIR/data1-clean.json"
cat > "$DATA1" <<'JSON'
{
  "title": "Hello World",
  "sections": [
    {"name": "Foo"},
    {"name": "Bar"}
  ]
}
JSON

OUT1="$TMP_DIR/out1.html"
if bash "$SCRIPT" --template "$TEMPLATE" --data "$DATA1" --out "$OUT1" --with-redaction 2>"$TMP_DIR/c1-stderr.txt"; then
  pass "Case 1 (all clean): exit 0"
else
  fail "Case 1: unexpected non-zero exit"
fi

if [[ -f "$OUT1" ]]; then
  pass "Case 1: HTML file generated"
else
  fail "Case 1: HTML file not created"
fi

if grep -q "Hello World" "$OUT1" 2>/dev/null; then
  pass "Case 1: title present unchanged"
else
  fail "Case 1: title missing or changed"
fi

# ============================================================
# Case 2: dict hit only - uses a custom client dict
# ============================================================

DICT2="$TMP_DIR/dict2-test.yaml"
cat > "$DICT2" <<'YAML'
schema_version: client-redaction.v1
clients:
  - rule_id: c-test-001
    name: NoraiCorp
    replace_with: "[Client_TestA]"
people: []
domains: []
YAML

DATA2="$TMP_DIR/data2-dict-hit.json"
cat > "$DATA2" <<'JSON'
{
  "title": "Project NoraiCorp Plan",
  "sections": [
    {"name": "Foo"}
  ]
}
JSON

OUT2="$TMP_DIR/out2.html"
if bash "$SCRIPT" --template "$TEMPLATE" --data "$DATA2" --out "$OUT2" --with-redaction --client-dict "$DICT2" 2>"$TMP_DIR/c2-stderr.txt"; then
  pass "Case 2 (dict hit): exit 0"
else
  fail "Case 2: unexpected non-zero exit. stderr: $(cat "$TMP_DIR/c2-stderr.txt")"
fi

if grep -q "\[Client_TestA\]" "$OUT2" 2>/dev/null; then
  pass "Case 2: dict replacement [Client_TestA] present in HTML"
else
  fail "Case 2: dict replacement missing"
fi

if grep -q "NoraiCorp" "$OUT2" 2>/dev/null; then
  fail "Case 2: original 'NoraiCorp' should NOT appear in HTML"
else
  pass "Case 2: original 'NoraiCorp' redacted (not in HTML)"
fi

# ============================================================
# Case 3 (additional): without --with-redaction -> existing behavior preserved
# ============================================================

OUT5="$TMP_DIR/out5.html"
if bash "$SCRIPT" --template "$TEMPLATE" --data "$DATA1" --out "$OUT5" 2>"$TMP_DIR/c5-stderr.txt"; then
  pass "Case 3 (no flag): backward-compat — exit 0 without --with-redaction"
else
  fail "Case 3: backward-compat broken"
fi

if [[ -f "$OUT5" ]] && grep -q "Hello World" "$OUT5" 2>/dev/null; then
  pass "Case 3: HTML generated normally without redaction"
else
  fail "Case 3: HTML missing or content lost"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-render-html-redaction.sh)"
echo "============================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi

exit 0
