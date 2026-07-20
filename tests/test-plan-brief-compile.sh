#!/bin/bash
# tests/test-plan-brief-compile.sh
# Phase 65.1.3 - machine verification of plan-brief-compile.sh
#
# Verification cases (corresponds to Phase 105.3):
#   confidence keeps the display-compatible name but limits its meaning to plan_readiness.
#   Score is only DoD clarity 60 pts + dependency-resolution rate 40 pts; D/P counts not added.
#
# Common verification:
#   (a) --query / --project required, exit 2 if missing
#   (b) confidence is an integer 0-100
#   (c) confidence_evidence explains plan_readiness / DoD clarity / dependency-resolution rate
#   (d) options / risks / acceptance_criteria are non-empty
#   (e) each related D/P element is passed to related_decisions (count matches)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COMPILE_SCRIPT="$ROOT_DIR/scripts/plan-brief-compile.sh"
FIX_DIR="$ROOT_DIR/tests/fixtures/plan-brief-compile"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- pre-checks ----

if [[ ! -x "$COMPILE_SCRIPT" ]]; then
  fail "plan-brief-compile.sh not executable: $COMPILE_SCRIPT"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "plan-brief-compile.sh exists and is executable"

# ---- (a) required-argument check ----

set +e
bash "$COMPILE_SCRIPT" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Compile script exits 2 when --query and --project missing"
else
  fail "Compile script should exit 2 when args missing (got $exit_code)"
fi

set +e
bash "$COMPILE_SCRIPT" --query "test" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Compile script exits 2 when --project missing"
else
  fail "Compile script should exit 2 when --project missing (got $exit_code)"
fi

# ---- helper: run one case ----
# args: <case_label> <fixture_path> <expected_confidence_min> <expected_confidence_max>
#       <query_text> <expected_decisions_count> <expected_plans_count>

run_case() {
  local label="$1"
  local fixture="$2"
  local conf_min="$3"
  local conf_max="$4"
  local query="$5"
  local exp_decisions="$6"
  local exp_plans="$7"

  local out
  out="$(bash "$COMPILE_SCRIPT" --query "$query" --project "demo" --mem-results "$fixture" 2>&1)" || {
    fail "[$label] compile script failed: $out"
    return
  }

  # schema check
  local schema
  schema="$(printf '%s' "$out" | jq -r '.schema')"
  if [[ "$schema" == "plan-brief-context.v1" ]]; then
    pass "[$label] schema = plan-brief-context.v1"
  else
    fail "[$label] schema mismatch: $schema"
  fi

  # confidence in expected range
  local conf
  conf="$(printf '%s' "$out" | jq -r '.confidence')"
  if [[ "$conf" -ge "$conf_min" && "$conf" -le "$conf_max" ]]; then
    pass "[$label] confidence = $conf (expected ${conf_min}-${conf_max})"
  else
    fail "[$label] confidence out of range: $conf (expected ${conf_min}-${conf_max})"
  fi

  # confidence is integer 0-100
  if [[ "$conf" -ge 0 && "$conf" -le 100 ]]; then
    pass "[$label] confidence is in [0, 100]"
  else
    fail "[$label] confidence out of [0, 100]: $conf"
  fi

  # confidence_evidence explains the single-axis plan_readiness score.
  local evidence_text
  evidence_text="$(printf '%s' "$out" | jq -r '.confidence_evidence | join("\n")')"
  if printf '%s' "$evidence_text" | grep -q 'plan_readiness DoD clarity' && \
     printf '%s' "$evidence_text" | grep -q 'plan_readiness dependency resolution rate' && \
     printf '%s' "$evidence_text" | grep -q 'not added to the readiness score'; then
    pass "[$label] confidence_evidence explains plan_readiness single-axis scoring"
  else
    fail "[$label] confidence_evidence does not explain plan_readiness scoring"
  fi

  # related_decisions length matches fixture
  local rd_count
  rd_count="$(printf '%s' "$out" | jq -r '.related_decisions | length')"
  if [[ "$rd_count" == "$exp_decisions" ]]; then
    pass "[$label] related_decisions count = $exp_decisions"
  else
    fail "[$label] related_decisions count: got $rd_count, expected $exp_decisions"
  fi

  # similar_past_plans length matches fixture
  local sp_count
  sp_count="$(printf '%s' "$out" | jq -r '.similar_past_plans | length')"
  if [[ "$sp_count" == "$exp_plans" ]]; then
    pass "[$label] similar_past_plans count = $exp_plans"
  else
    fail "[$label] similar_past_plans count: got $sp_count, expected $exp_plans"
  fi

  # Phase 105.3: generated arrays must not be empty.
  for section in options risks acceptance_criteria; do
    local section_count
    section_count="$(printf '%s' "$out" | jq -r --arg section "$section" '.[$section] | length')"
    if [[ "$section_count" -ge 1 ]]; then
      pass "[$label] $section is non-empty"
    else
      fail "[$label] $section should be non-empty"
    fi
  done

  # confidence_evidence_items derived field present (for template iteration)
  local items_count
  items_count="$(printf '%s' "$out" | jq -r '.confidence_evidence_items | length')"
  if [[ "$items_count" -eq 3 ]]; then
    pass "[$label] confidence_evidence_items has 3 items (DoD + dependency + context)"
  else
    fail "[$label] confidence_evidence_items count: got $items_count, expected 3"
  fi
}

# ---- Case 1: empty mem results ----
# query: 1 sentence with 1 number → DoD 100% × 30 = 30
# 0 past items → 0, 0 D/P → 0
# expected confidence: 30 (only DoD contributes)
run_case "empty" "$FIX_DIR/case-empty.json" 78 82 "Create 1 Plan Brief" 0 0

# ---- Case 2: 5 all done + D 4 + P 2 (= 6 D/P) ----
# 5 past items all done → 40
# query: 1 sentence, 1 number → 30
# 6+ D/P → 30
# expected: 100
run_case "5-all-done" "$FIX_DIR/case-5-all-done.json" 98 100 "Complete all 5 tasks" 4 5

# ---- Case 3: 5 half failed + D 2 + P 1 (= 3 D/P) ----
# 2 of 5 past items done (40%) → 16
# query: 1 sentence, has number → 30
# 3 D/P → 20
# expected: 66 (allow 64-68 for rounding)
run_case "5-half-failed" "$FIX_DIR/case-5-half-failed.json" 74 78 "Advance 5 tasks" 2 5

# ---- Case 4: 5 all done + 0 D/P ----
# 5 past items all done → 40
# query: 1 sentence, has number → 30
# 0 D/P → 0
# expected: 70
run_case "5-all-done-no-dp" "$FIX_DIR/case-5-all-done-no-dp.json" 98 100 "Advance 5 tasks" 0 5

# ---- Summary ----

echo ""
echo "============================================"
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "FAIL details:" >&2
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
echo "All assertions passed."
exit 0
