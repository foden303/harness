#!/bin/bash
# test-render-html.sh
# Phase 65.1.1 - machine verification of the HTML rendering infrastructure
#
# DoD:
#   (a) scripts/render-html.sh works with the 3 args --template / --data / --out
#   (b) templates/html/test-fixture.html.template can expand {{title}} and
#       {{#sections}}{{name}}{{/sections}}
#   (c) machine-verify 4 cases (normal / empty sections / invalid JSON / nonexistent template)
#   (d) output HTML has a text structure readable by lynx -dump (fall back to HTML structure when lynx is absent)
#   (e) CSS palette uses the Claude Harness brand (#FAFAFA / #0F0F0F / #F58A4A)
#
# Usage: ./tests/test-render-html.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/render-html.sh"
TEMPLATE_DIR="$PROJECT_ROOT/templates/html"

PASS=0
FAIL=0

pass() {
  echo "  [PASS] $1"
  PASS=$(( PASS + 1 ))
}

fail() {
  echo "  [FAIL] $1"
  FAIL=$(( FAIL + 1 ))
}

# Temporary work area (always removed when the test ends)
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-render-html.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== machine verification of render-html.sh / test-fixture.html.template ==="
echo ""

# ---- Precondition: script and template exist ----
echo "--- Preconditions ---"
if [ -x "$SCRIPT" ]; then
  pass "scripts/render-html.sh is executable"
else
  fail "scripts/render-html.sh not found or not executable"
fi

if [ -f "$TEMPLATE_DIR/test-fixture.html.template" ]; then
  pass "templates/html/test-fixture.html.template exists"
else
  fail "templates/html/test-fixture.html.template does not exist"
fi

# The template itself must contain the Claude Harness palette (DoD (e))
if [ -f "$TEMPLATE_DIR/test-fixture.html.template" ]; then
  for hex in "#FAFAFA" "#0F0F0F" "#F58A4A"; do
    if grep -qi "$hex" "$TEMPLATE_DIR/test-fixture.html.template"; then
      pass "template contains Claude Harness palette color $hex"
    else
      fail "template does not contain Claude Harness palette color $hex"
    fi
  done
fi
echo ""

# Verification helper: fall back to an HTML structure check when lynx is absent
verify_text_readable() {
  local label="$1"
  local html_path="$2"
  local must_contain="$3"

  if ! [ -f "$html_path" ]; then
    fail "$label: output file does not exist, cannot verify text structure"
    return
  fi

  if command -v lynx >/dev/null 2>&1; then
    local dump
    dump="$(lynx -dump -nolist "$html_path" 2>/dev/null || true)"
    if echo "$dump" | grep -q "$must_contain"; then
      pass "$label: '$must_contain' is readable via lynx -dump"
    else
      fail "$label: '$must_contain' is not readable via lynx -dump"
    fi
  else
    # When lynx is absent, substitute an HTML-structure sanity check
    if grep -qi '<html' "$html_path" \
      && grep -qi '</html>' "$html_path" \
      && grep -qi '<body' "$html_path" \
      && grep -q "$must_contain" "$html_path"; then
      pass "$label: HTML structure sound + contains '$must_contain' (fallback since lynx absent)"
    else
      fail "$label: HTML structure or expected string '$must_contain' missing (lynx-absent fallback)"
    fi
  fi
}

# ---- Case 1: normal (title + 2 sections) ----
echo "--- Case 1: normal data ---"
CASE1_DATA="$TMP_DIR/case1.json"
CASE1_OUT="$TMP_DIR/case1.html"
cat > "$CASE1_DATA" <<'JSON'
{
  "kind": "plan-brief",
  "project": "test-render-html",
  "generated_at": "2026-05-09T00:00:00Z",
  "title": "Plan Brief Test",
  "sections": [
    {"name": "Section Alpha"},
    {"name": "Section Beta"}
  ]
}
JSON

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE1_DATA" --out "$CASE1_OUT" >/dev/null 2>"$TMP_DIR/case1.err" \
  || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  pass "Case 1: exit 0"
else
  fail "Case 1: expected exit 0 but got $actual_exit (stderr: $(cat "$TMP_DIR/case1.err"))"
fi

if [ -f "$CASE1_OUT" ]; then
  pass "Case 1: output HTML was generated"

  if grep -q "Plan Brief Test" "$CASE1_OUT"; then
    pass "Case 1: {{title}} expanded to 'Plan Brief Test'"
  else
    fail "Case 1: {{title}} expansion not confirmed"
  fi

  if grep -q "Section Alpha" "$CASE1_OUT" && grep -q "Section Beta" "$CASE1_OUT"; then
    pass "Case 1: {{#sections}}{{name}}{{/sections}} expanded 2 items"
  else
    fail "Case 1: sections expansion not confirmed"
  fi

  # No leftover mustache markers
  if grep -qE '\{\{[^}]+\}\}' "$CASE1_OUT"; then
    fail "Case 1: leftover {{...}} marker detected"
  else
    pass "Case 1: no unexpanded {{...}} residue"
  fi

  verify_text_readable "Case 1" "$CASE1_OUT" "Plan Brief Test"
else
  fail "Case 1: output HTML not generated"
fi
echo ""

# ---- Case 2: empty sections ----
echo "--- Case 2: empty sections ---"
CASE2_DATA="$TMP_DIR/case2.json"
CASE2_OUT="$TMP_DIR/case2.html"
cat > "$CASE2_DATA" <<'JSON'
{
  "kind": "plan-brief",
  "project": "test-render-html",
  "generated_at": "2026-05-09T00:00:00Z",
  "title": "Empty Sections Page",
  "sections": []
}
JSON

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE2_DATA" --out "$CASE2_OUT" >/dev/null 2>"$TMP_DIR/case2.err" \
  || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  pass "Case 2: exit 0 (empty sections is a normal case)"
else
  fail "Case 2: expected exit 0 but got $actual_exit"
fi

if [ -f "$CASE2_OUT" ]; then
  if grep -q "Empty Sections Page" "$CASE2_OUT"; then
    pass "Case 2: title was expanded"
  else
    fail "Case 2: title not expanded"
  fi

  # Section block fully removed (Section Alpha etc. not included)
  if grep -q "Section Alpha" "$CASE2_OUT" || grep -q "Section Beta" "$CASE2_OUT"; then
    fail "Case 2: sections empty but previous item string still shows"
  else
    pass "Case 2: no section item output for empty array"
  fi

  if grep -qE '\{\{[^}]+\}\}' "$CASE2_OUT"; then
    fail "Case 2: leftover {{...}} marker detected"
  else
    pass "Case 2: no unexpanded {{...}} residue"
  fi
else
  fail "Case 2: output HTML not generated"
fi
echo ""

# ---- Case 3: invalid JSON ----
echo "--- Case 3: invalid JSON ---"
CASE3_DATA="$TMP_DIR/case3.json"
CASE3_OUT="$TMP_DIR/case3.html"
echo "{not valid json" > "$CASE3_DATA"

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE3_DATA" --out "$CASE3_OUT" >/dev/null 2>"$TMP_DIR/case3.err" \
  || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  pass "Case 3: non-zero exit on invalid JSON ($actual_exit)"
else
  fail "Case 3: exit 0 even with invalid JSON"
fi

if [ -f "$CASE3_OUT" ]; then
  fail "Case 3: output file generated despite invalid JSON"
else
  pass "Case 3: no output file generated (no side effects on failure)"
fi
echo ""

# ---- Case 4: nonexistent template ----
echo "--- Case 4: nonexistent template ---"
CASE4_DATA="$TMP_DIR/case4.json"
CASE4_OUT="$TMP_DIR/case4.html"
echo '{"title":"x","sections":[]}' > "$CASE4_DATA"

actual_exit=0
"$SCRIPT" --template definitely-does-not-exist-xyz --data "$CASE4_DATA" --out "$CASE4_OUT" \
  >/dev/null 2>"$TMP_DIR/case4.err" || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  pass "Case 4: non-zero exit for nonexistent template ($actual_exit)"
else
  fail "Case 4: exit 0 even for nonexistent template"
fi

if [ -f "$CASE4_OUT" ]; then
  fail "Case 4: output file generated despite nonexistent template"
else
  pass "Case 4: no output file generated"
fi
echo ""

# ---- Case 5: data value contains {{...}} - must not double-expand ----
echo "--- Case 5: avoid double-expansion when a value contains a {{var}} string ---"
CASE5_DATA="$TMP_DIR/case5.json"
CASE5_OUT="$TMP_DIR/case5.html"
cat > "$CASE5_DATA" <<'JSON'
{
  "kind": "plan-brief",
  "project": "test-render-html",
  "generated_at": "2026-05-09T00:00:00Z",
  "title": "Literal {{title}} Should Stay Literal",
  "sections": [
    {"name": "{{title}} should NOT recurse"},
    {"name": "Plain section"}
  ]
}
JSON

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE5_DATA" --out "$CASE5_OUT" >/dev/null 2>"$TMP_DIR/case5.err" \
  || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  pass "Case 5: exit 0"
else
  fail "Case 5: expected exit 0 but got $actual_exit"
fi

if [ -f "$CASE5_OUT" ]; then
  # The title itself contains the literal {{title}}, which should remain as-is in the output
  if grep -q "Literal {{title}} Should Stay Literal" "$CASE5_OUT"; then
    pass "Case 5: literal '{{title}}' inside title preserved without recursive expansion"
  else
    fail "Case 5: literal '{{title}}' inside title lost or recursively expanded"
  fi

  if grep -q "{{title}} should NOT recurse" "$CASE5_OUT"; then
    pass "Case 5: literal '{{title}}' inside section value preserved without recursive expansion"
  else
    fail "Case 5: literal '{{title}}' inside section value lost or recursively expanded"
  fi

  if grep -q "Plain section" "$CASE5_OUT"; then
    pass "Case 5: normal section also expanded (no regression)"
  else
    fail "Case 5: normal section expansion failed"
  fi
else
  fail "Case 5: output HTML not generated"
fi
echo ""

# ---- Case 6: value contains control char \x01 - verify sentinel collision avoidance ----
echo "--- Case 6: sentinel collision avoidance when a data value contains control char \\x01 ---"
CASE6_DATA="$TMP_DIR/case6.json"
CASE6_OUT="$TMP_DIR/case6.html"
# The data value embeds an ASCII SOH (0x01). A 3-byte sentinel does not collide with \x01 in data values.
# Pass value "alpha[SOH]beta" and verify \x01 remains as-is in the output,
# and that a `{` is not erroneously mixed in.
printf '{"title": "alpha\\u0001beta", "sections": []}' > "$CASE6_DATA"

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE6_DATA" --out "$CASE6_OUT" >/dev/null 2>"$TMP_DIR/case6.err" \
  || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  pass "Case 6: exit 0"
else
  fail "Case 6: expected exit 0 but got $actual_exit"
fi

if [ -f "$CASE6_OUT" ]; then
  # Whether the \x01 byte in the title is preserved (= not turned into `{` by a sentinel collision)
  if grep -F "alpha"$'\x01'"beta" "$CASE6_OUT" >/dev/null 2>&1; then
    pass "Case 6: \\x01 byte inside data value preserved (no sentinel collision)"
  else
    fail "Case 6: \\x01 inside data value possibly mis-converted (sentinel collision)"
  fi

  # Not erroneously turned into `{` (alpha{beta must not appear in the output)
  if grep -F "alpha{beta" "$CASE6_OUT" >/dev/null 2>&1; then
    fail "Case 6: \\x01 inside data value mis-converted to `{` (sentinel collision occurred)"
  else
    pass "Case 6: mis-converted 'alpha{beta' does not appear in output"
  fi
else
  fail "Case 6: output HTML not generated"
fi
echo ""

# ---- Results ----
TOTAL=$(( PASS + FAIL ))
echo "=== Result: $PASS/$TOTAL PASS ==="
if [ "$FAIL" -gt 0 ]; then
  echo "FAILED: $FAIL tests failed"
  exit 1
fi
echo "All tests passed."
exit 0
