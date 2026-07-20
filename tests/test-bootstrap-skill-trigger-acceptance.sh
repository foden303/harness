#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/onboarding/skill-trigger-acceptance.md"
RELEASE_PREFLIGHT="${ROOT_DIR}/scripts/release-preflight.sh"

fail() {
  echo "test-bootstrap-skill-trigger-acceptance: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

[ -f "$DOC" ] || fail "missing $DOC"
assert_contains "$DOC" "Phase 73 treats installation as incomplete"
assert_contains "$DOC" "not_observed != absent"
assert_contains "$DOC" "Claimed hosts without smoke evidence are release blockers"

required_skills=(
  harness-plan
  harness-work
  harness-review
  harness-release
  harness-setup
  harness-sync
  breezing
)

for skill in "${required_skills[@]}"; do
  [ -f "${ROOT_DIR}/skills/${skill}/SKILL.md" ] || fail "missing Claude skill ${skill}"
done

assert_contains "$RELEASE_PREFLIGHT" "tests/test-bootstrap-skill-trigger-acceptance.sh"

echo "test-bootstrap-skill-trigger-acceptance: ok"
