#!/bin/bash
# test-breezing-advisor-protocol.sh
# Pin the advisor protocol and mirror sync of the breezing / harness-work skills

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  grep -q "$pattern" "$file" || fail "${label}: ${pattern}"
}

SHARED_WORK="${PROJECT_ROOT}/skills/harness-work/SKILL.md"
SHARED_BREEZING="${PROJECT_ROOT}/skills/breezing/SKILL.md"

for file in \
  "${SHARED_WORK}" "${SHARED_BREEZING}"
do
  [ -f "${file}" ] || fail "missing file: ${file}"
done

assert_contains "${SHARED_WORK}" 'advisor-request.v1' "shared harness-work"
assert_contains "${SHARED_WORK}" 'advisor-response.v1' "shared harness-work"
assert_contains "${SHARED_WORK}" 'at most 3 times' "shared harness-work"
assert_contains "${SHARED_BREEZING}" 'Worker → `advisor-request.v1`' "shared breezing"
assert_contains "${SHARED_BREEZING}" 'consultation count per task is at most 3' "shared breezing"

echo "test-breezing-advisor-protocol: ok"
