#!/bin/bash
# test-harness-loop-guard.sh
# Test of harness-loop idempotency guard (a): the multiple-launch prevention lock
#
# Usage: bash tests/test-harness-loop-guard.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "${SCRIPT_DIR}")"
LOCK_FILE="${PLUGIN_ROOT}/.claude/state/locks/loop-session.lock"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass_test() {
    echo -e "${GREEN}✓${NC} $1"
    PASS_COUNT=$(( PASS_COUNT + 1 ))
}

fail_test() {
    echo -e "${RED}✗${NC} $1"
    FAIL_COUNT=$(( FAIL_COUNT + 1 ))
}

echo "=========================================="
echo "harness-loop idempotency guard (a) test"
echo "=========================================="
echo ""

# Cleanup: remove the lock file before the test starts
cleanup() {
    rm -f "${LOCK_FILE}" 2>/dev/null || true
}
trap cleanup EXIT
cleanup

# Mock harness-loop launch script for testing (reproduces flow.md Step 0)
MOCK_LOOP_SCRIPT="$(mktemp /tmp/test-harness-loop-XXXXXX.sh)"
cat > "${MOCK_LOOP_SCRIPT}" << 'SCRIPT'
#!/bin/bash
# Reproduce the flow.md Step 0 multiple-launch prevention lock
LOCK_FILE="$1"
mkdir -p "$(dirname "${LOCK_FILE}")"

if [ -f "${LOCK_FILE}" ]; then
    echo "harness-loop: already running" >&2
    exit 1
fi

SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
printf '{"pid":%d,"session_id":"%s","started_at":"%s","args":"%s"}\n' \
    "$$" "${SESSION_ID}" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "test" \
    > "${LOCK_FILE}"

cleanup_loop_lock() {
    rm -f "${LOCK_FILE}" 2>/dev/null || true
}
trap cleanup_loop_lock EXIT INT TERM

# Work while holding the lock (for testing: sleep 0.5s)
sleep 0.5
exit 0
SCRIPT
chmod +x "${MOCK_LOOP_SCRIPT}"

# Test 1: the first launch must succeed
echo "--- Test 1: first launch ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
FIRST_PID=$!
sleep 0.1  # wait a moment for the lock file to be created

if [ -f "${LOCK_FILE}" ]; then
    pass_test "first launch: lock file was created"
else
    fail_test "first launch: lock file was not created"
fi

# Test 2: the second launch must give an already-running error
echo "--- Test 2: multiple-launch prevention ---"
SECOND_OUTPUT="$(bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" 2>&1 || true)"
if echo "${SECOND_OUTPUT}" | grep -q "already running"; then
    pass_test "second launch: 'already running' error was returned"
else
    fail_test "second launch: 'already running' error was not returned (output: ${SECOND_OUTPUT})"
fi

# Test 3: the second launch must exit with code 1
echo "--- Test 3: exit code on multiple launch ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" 2>/dev/null
EXIT_CODE=$?
if [ "${EXIT_CODE}" -eq 1 ]; then
    pass_test "second launch: exited with exit code 1"
else
    fail_test "second launch: exit code was ${EXIT_CODE} (expected: 1)"
fi

# Wait until the first one finishes
wait "${FIRST_PID}" 2>/dev/null || true

# Test 4: the lock file must be removed after normal exit
echo "--- Test 4: lock removal after normal exit ---"
if [ ! -f "${LOCK_FILE}" ]; then
    pass_test "after normal exit: lock file was removed"
else
    fail_test "after normal exit: lock file remains"
fi

# Test 5: relaunch must be possible after the lock file is removed
echo "--- Test 5: relaunch after lock removal ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
THIRD_PID=$!
sleep 0.1

if [ -f "${LOCK_FILE}" ]; then
    pass_test "relaunch: lock file was created (reusable)"
else
    fail_test "relaunch: lock file was not created"
fi
wait "${THIRD_PID}" 2>/dev/null || true

# Test 6: the lock file content must be valid JSON
echo "--- Test 6: JSON format of the lock file ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
FOURTH_PID=$!
sleep 0.1

if [ -f "${LOCK_FILE}" ]; then
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import json; json.load(open('${LOCK_FILE}'))" 2>/dev/null; then
            pass_test "lock file content is valid JSON"
            # Check each of the pid, session_id, started_at, args fields
            for field in pid session_id started_at args; do
                if python3 -c "import json; d=json.load(open('${LOCK_FILE}')); assert '${field}' in d" 2>/dev/null; then
                    pass_test "lock file has '${field}' field"
                else
                    fail_test "lock file is missing '${field}' field"
                fi
            done
        else
            fail_test "lock file content is not valid JSON"
        fi
    else
        pass_test "python3 unavailable, skipping JSON validation"
    fi
fi
wait "${FOURTH_PID}" 2>/dev/null || true

# Cleanup
rm -f "${MOCK_LOOP_SCRIPT}" 2>/dev/null || true

echo ""
echo "=========================================="
echo "Test result summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} ${PASS_COUNT}"
echo -e "${RED}Failed:${NC} ${FAIL_COUNT}"
echo ""

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAIL_COUNT} test(s) failed${NC}"
    exit 1
fi
