#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEX="${ROOT_DIR}/docs/onboarding/index.md"
INSTALL="${ROOT_DIR}/docs/onboarding/install.md"
README="${ROOT_DIR}/README.md"

fail() {
  echo "test-tool-first-onboarding: FAIL: $1" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing $1"
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

section_for() {
  local host="$1"
  awk -v heading="### ${host} " '
    /^### / { in_section = (index($0, heading) == 1) }
    in_section { print }
  ' "$INSTALL"
}

assert_section_contains() {
  local host="$1"
  local needle="$2"
  section_for "$host" | grep -Fq "$needle" || fail "missing '$needle' in ${host} section"
}

assert_section_regex() {
  local host="$1"
  local pattern="$2"
  section_for "$host" | grep -Eq "$pattern" || fail "missing pattern '$pattern' in ${host} section"
}

assert_file "$INDEX"
assert_file "$INSTALL"

assert_contains "$INDEX" "tool you are using now"
assert_contains "$INDEX" "tool you are using now"
assert_contains "$INSTALL" "tool you are using now"
assert_contains "$INSTALL" "tool you are using now"
assert_contains "$INDEX" "not_observed != absent"
assert_contains "$INSTALL" "not_observed != absent"

HOST_TIERS=$(
  cat <<'HOSTS'
Claude Code|supported
HOSTS
)

while IFS='|' read -r host tier; do
  assert_contains "$INDEX" "| ${host} | \`${tier}\` |"
  assert_contains "$INSTALL" "### ${host} (\`${tier}\`)"
  assert_section_contains "$host" "First prompt:"
  assert_section_contains "$host" "First command:"
  assert_section_contains "$host" "Verification command:"
  assert_section_contains "$host" "Success look:"
  assert_section_regex "$host" "(Install:|Unsupported reason:)"
  assert_section_regex "$host" "(Update:|Unsupported reason:)"
  assert_section_regex "$host" "(Uninstall:|Unsupported reason:)"
done <<EOF
$HOST_TIERS
EOF

assert_section_contains "Claude Code" "/plugin install harness@harness-marketplace"
assert_section_contains "Claude Code" "/plugin update harness"
# One supported host, and the docs must still say what happens for the rest.
assert_contains "$INSTALL" "### Other hosts"
assert_contains "$INDEX" "| Any other CLI | no claim |"

assert_contains "$README" "docs/onboarding/index.md"

echo "test-tool-first-onboarding: ok"
