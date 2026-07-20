#!/usr/bin/env bash
# Phase 64.1.3: 4-state unit test for the grep_plans_or_archive helper
#
# Pin the behavior of the archive-aware Plans.md grep helper introduced in
# Phase 64.1.1 across the 4 states (Plans only / archive only / both / miss).
# To prevent helper divergence, source tests/lib/grep_plans_or_archive.sh
# directly and verify its behavior.
#
# Test strategy:
# - Create a tmp dir with mktemp and place Plans.md and archive/Plans-XXX.md as fixtures
# - Override GPOA_PLANS_FILE / GPOA_ARCHIVE_DIR and call the helper
# - Assert the return code in each case
#
# Usage: bash tests/test-grep-plans-or-archive.sh
# Expected: PASS=4 FAIL=0 with exit 0

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=lib/grep_plans_or_archive.sh
. "${ROOT_DIR}/tests/lib/grep_plans_or_archive.sh"

PASS=0
FAIL=0

assert_returns() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [ "${expected}" = "${actual}" ]; then
        echo "  ✓ ${label} (returned ${actual})"
        PASS=$((PASS + 1))
    else
        echo "  ✗ ${label} (expected ${expected}, got ${actual})"
        FAIL=$((FAIL + 1))
    fi
}

# Setup: tmp fixture
TMPDIR_FIX="$(mktemp -d /tmp/test-gpoa.XXXXXX)"
trap 'rm -rf "${TMPDIR_FIX}"' EXIT

PLANS_FIX="${TMPDIR_FIX}/Plans.md"
ARCHIVE_FIX="${TMPDIR_FIX}/archive"
mkdir -p "${ARCHIVE_FIX}"

export GPOA_PLANS_FILE="${PLANS_FIX}"
export GPOA_ARCHIVE_DIR="${ARCHIVE_FIX}"

echo "=== Test 1: PlansHit (pattern in Plans.md only) ==="
echo "Phase 99.1.1 | unique-pattern-plans-only" > "${PLANS_FIX}"
rm -f "${ARCHIVE_FIX}"/Plans-*.md
set +e
grep_plans_or_archive 'unique-pattern-plans-only'
RC=$?
set -e
assert_returns "PlansHit returns 0" 0 "${RC}"

echo ""
echo "=== Test 2: ArchiveHit (pattern in archive only) ==="
echo "Phase 47.1.1 | something-else" > "${PLANS_FIX}"
echo "Phase 51.1.1 | unique-pattern-archive-only" > "${ARCHIVE_FIX}/Plans-2026-05-08-phase47-61.md"
set +e
grep_plans_or_archive 'unique-pattern-archive-only'
RC=$?
set -e
assert_returns "ArchiveHit returns 0" 0 "${RC}"

echo ""
echo "=== Test 3: BothHit (pattern in both) ==="
echo "shared-pattern-both" > "${PLANS_FIX}"
echo "shared-pattern-both" > "${ARCHIVE_FIX}/Plans-2026-05-08-phase47-61.md"
set +e
grep_plans_or_archive 'shared-pattern-both'
RC=$?
set -e
assert_returns "BothHit returns 0" 0 "${RC}"

echo ""
echo "=== Test 4: Miss (in neither) ==="
echo "Phase X | irrelevant content" > "${PLANS_FIX}"
echo "Phase Y | another irrelevant" > "${ARCHIVE_FIX}/Plans-2026-05-08-phase47-61.md"
set +e
grep_plans_or_archive 'pattern-that-does-not-exist'
RC=$?
set -e
assert_returns "Miss returns 1" 1 "${RC}"

echo ""
echo "=== Summary ==="
echo "PASS=${PASS} FAIL=${FAIL}"

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi

echo "OK"
exit 0
