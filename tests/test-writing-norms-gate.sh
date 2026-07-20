#!/usr/bin/env bash
# test-writing-norms-gate.sh — TDD proof for HOTL Phase 101 U6 (Plans.md 101.7).
#
# Proves the rule↔check↔execution chain end-to-end:
#   RED   : a fixture containing a §7 banned phrase makes the gate exit 1.
#   GREEN : a clean fixture makes it exit 0.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GATE="$ROOT/scripts/check-writing-norms.sh"

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1"; fail=1; }

[ -x "$GATE" ] || chmod +x "$GATE" 2>/dev/null || true

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- RED: planted banned phrase must trip the gate (exit 1) ---
cat > "$tmp/dirty.md" <<'EOF'
# Sample

If we delve into this feature, the key point is design consistency.
EOF
if bash "$GATE" "$tmp/dirty.md" >/dev/null 2>&1; then
  die "RED case: gate passed on a file containing banned phrases (expected exit 1)"
else
  pass "RED case: gate exits non-zero on planted banned phrase"
fi

# --- GREEN: clean fixture must pass (exit 0) ---
cat > "$tmp/clean.md" <<'EOF'
# Sample

This feature keeps design consistent. As a concrete example, it passes 3 tests.
EOF
if bash "$GATE" "$tmp/clean.md" >/dev/null 2>&1; then
  pass "GREEN case: gate exits zero on clean fixture"
else
  die "GREEN case: gate failed on a clean file (expected exit 0)"
fi

# --- default-surface invocation must not error ---
if bash "$GATE" >/dev/null 2>&1; then
  pass "default-surface invocation exits zero"
else
  die "default-surface invocation errored"
fi

if [ "$fail" -ne 0 ]; then
  echo "test-writing-norms-gate: FAIL"
  exit 1
fi
echo "test-writing-norms-gate: all PASS"
exit 0
