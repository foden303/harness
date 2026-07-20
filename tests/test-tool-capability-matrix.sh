#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/tool-capability-matrix.md"

fail() {
  echo "test-tool-capability-matrix: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  if ! grep -Fq "$pattern" "$DOC"; then
    fail "expected '${pattern}' in docs/tool-capability-matrix.md"
  fi
}

[ -f "$DOC" ] || fail "missing docs/tool-capability-matrix.md"

required_capabilities=(
  '`skill_loading`'
  '`bootstrap_notice`'
  '`prompt_routing`'
  '`pre_use_guard`'
  '`post_use_gate`'
  '`review_artifact`'
  '`memory_bridge`'
)

for capability in "${required_capabilities[@]}"; do
  assert_contains "$capability"
done

required_hosts=(
  "Claude Code"
)

for host in "${required_hosts[@]}"; do
  assert_contains "$host"
done

tier_rows=(
  "| Claude Code | \`supported\` |"
)

for host_row in "${tier_rows[@]}"; do
  assert_contains "$host_row"
done

# These assertions must name text that actually exists: three previous ones
# ("contract injection + post quality gate + merge gate", "packaging and
# instruction surface", "CI-gated direct plugin marketplace/install smoke")
# referenced wording absent from the matrix, and the test was never wired into
# validate-plugin.sh, so it failed unnoticed.
assert_contains "False parity is forbidden."
assert_contains "not a marketing support matrix"
assert_contains "not_observed != absent"
assert_contains "does not inherit the safety or"
assert_contains "bootstrap claims of one that has it,"
assert_contains "No other host is given a support tier without its own evidence."

echo "test-tool-capability-matrix: ok"
