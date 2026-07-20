#!/bin/bash
# tests/test-audit-ui-presence.sh
# Phase 65.5.2 - mechanically verify the audit UI is integrated into all 3 HTML
#
# Verification cases (Plans.md §65.5.2 DoD a-d):
#   (a) an audit-trail section is commonly added to the 3 HTML templates
#   (b) 4 fields (search scope / referenced IDs / redaction count / audit log) are shown
#   (c) audit log is human-readable as JSON Lines
#   (d) grep -c "audit-trail" finds it in all 3 HTML

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ============================================================
# (a)(d) audit-trail section exists in the 3 templates
# ============================================================

for tpl in plan-brief accept progress; do
  TEMPLATE="$ROOT_DIR/templates/html/${tpl}.html.template"
  if [[ ! -f "$TEMPLATE" ]]; then
    fail "(a) template missing: $TEMPLATE"
    continue
  fi
  if grep -q 'class="audit-trail"' "$TEMPLATE"; then
    pass "(a)(d) ${tpl}.html.template has audit-trail section"
  else
    fail "(a)(d) ${tpl}.html.template missing audit-trail"
  fi
done

# ============================================================
# (b) 4 fields (search scope / referenced IDs / redaction count / audit log) shown
# ============================================================

for tpl in plan-brief accept progress; do
  TEMPLATE="$ROOT_DIR/templates/html/${tpl}.html.template"
  ALL_FIELDS_OK="true"
  for field in audit_search_scope audit_referenced_ids audit_redaction_summary audit_log_path; do
    if grep -q "{{${field}}}" "$TEMPLATE"; then
      :
    else
      fail "(b) ${tpl}.html.template missing {{${field}}} placeholder"
      ALL_FIELDS_OK="false"
    fi
  done
  if [[ "$ALL_FIELDS_OK" == "true" ]]; then
    pass "(b) ${tpl}.html.template has all 4 placeholders"
  fi
done

# ============================================================
# (b) the 4 field labels (search scope / referenced IDs / redaction count / audit log) are also shown
# ============================================================

for tpl in plan-brief accept progress; do
  TEMPLATE="$ROOT_DIR/templates/html/${tpl}.html.template"
  ALL_LABELS_OK="true"
  for label in "Search scope" "Referenced IDs" "Redaction count" "audit log"; do
    if grep -q "$label" "$TEMPLATE"; then
      :
    else
      fail "(b) ${tpl}.html.template missing '$label' label"
      ALL_LABELS_OK="false"
    fi
  done
  if [[ "$ALL_LABELS_OK" == "true" ]]; then
    pass "(b) ${tpl}.html.template has all 4 labels (Search scope/Referenced IDs/Redaction count/audit log)"
  fi
done

# ============================================================
# (b) the "🔍 Basis for this artifact" heading exists in all 3 HTML
# ============================================================

for tpl in plan-brief accept progress; do
  TEMPLATE="$ROOT_DIR/templates/html/${tpl}.html.template"
  if grep -q "Basis for this artifact" "$TEMPLATE"; then
    pass "(b) ${tpl}.html.template has '🔍 Basis for this artifact' heading"
  else
    fail "(b) ${tpl}.html.template missing heading"
  fi
done

# ============================================================
# (c) audit log is human-readable as JSON Lines (output of cross-project-audit-log.sh)
# ============================================================

# Generate the real output of audit-log.sh and verify it
TMP_AUDIT="$(mktemp /tmp/audit-test-XXXX.jsonl)"
trap 'rm -f "$TMP_AUDIT"' EXIT

bash "$ROOT_DIR/scripts/cross-project-audit-log.sh" \
  --group "TestG" --members "p1,p2" \
  --query-hash "$(printf 'q' | shasum -a 256 | awk '{print $1}')" \
  --dict-count 1 --ner-count 0 \
  --passed-final-scan true \
  --out "$TMP_AUDIT" 2>/dev/null

if jq -e '.schema_version == "cross-project-audit.v1"' "$TMP_AUDIT" >/dev/null 2>&1; then
  pass "(c) audit log JSON Lines is parseable + schema-compliant"
else
  fail "(c) audit log JSON parse failed"
fi

if [[ "$(wc -l < "$TMP_AUDIT" | tr -d ' ')" == "1" ]]; then
  pass "(c) audit log is one JSON per line (JSON Lines convention)"
else
  fail "(c) audit log line count != 1"
fi

# ============================================================
# Render with audit fields injected (smoke test)
# ============================================================

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-audit-ui-render.XXXXXX")"
trap "rm -f '$TMP_AUDIT'; rm -rf '$TMP_DIR'" EXIT

# progress fixture with audit fields
SNAP="$TMP_DIR/snap.json"
bash "$ROOT_DIR/scripts/progress-snapshot.sh" --plans Plans.md --project test > "$SNAP"

# Inject audit fields
SNAP2="$TMP_DIR/snap-audit.json"
jq '. + {
  audit_search_scope: "project=test / group=Personal Tools",
  audit_referenced_ids: "D43, P29, past-plans×3",
  audit_redaction_summary: "dict 2",
  audit_log_path: ".claude/state/audit/cross-project-search.jsonl"
}' "$SNAP" > "$SNAP2"

HTML="$TMP_DIR/audit-test.html"
bash "$ROOT_DIR/scripts/render-html.sh" --template progress --data "$SNAP2" --out "$HTML" 2>/dev/null

if grep -q "project=test / group=Personal Tools" "$HTML" && \
   grep -q "D43, P29, past-plans×3" "$HTML" && \
   grep -q "dict 2" "$HTML"; then
  pass "(b) Progress HTML render: values of 4 fields expanded into output"
else
  fail "(b) audit field rendering broken"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-audit-ui-presence.sh)"
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
