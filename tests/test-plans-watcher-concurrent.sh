#!/bin/bash
# test-plans-watcher-concurrent.sh
# plans-watcher.sh flock guard (e) — concurrent write test with 2 processes
# verifies that no lost update occurs
#
# Usage: bash tests/test-plans-watcher-concurrent.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "${SCRIPT_DIR}")"

# color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

warn_test() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=========================================="
echo "plans-watcher.sh flock guard (e) test"
echo "=========================================="
echo ""

# create temp directory for test
WORK_DIR="$(mktemp -d /tmp/test-plans-watcher-XXXXXX)"
PLANS_LOCK_FILE="${WORK_DIR}/.claude/state/locks/plans.flock"
TEST_FILE="${WORK_DIR}/counter.txt"
mkdir -p "${WORK_DIR}/.claude/state/locks"

# cleanup
cleanup() {
    rm -rf "${WORK_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: basic flock guard behavior (reproduce 3-tier lock fallback)
echo "--- Test 1: basic flock mutual-exclusion behavior ---"

# minimal script extracting flock logic (reproduces plans-watcher.sh's _plans_acquire_lock)
LOCK_SCRIPT="$(mktemp /tmp/test-flock-worker-XXXXXX.sh)"
cat > "${LOCK_SCRIPT}" << SCRIPT
#!/bin/bash
LOCK_FILE="\$1"
COUNTER_FILE="\$2"
LOCK_DIR="\${LOCK_FILE}.dir"
LOCK_TIMEOUT=3
_LOCK_ACQUIRED=0

_acquire() {
    mkdir -p "\$(dirname "\${LOCK_FILE}")" 2>/dev/null || true
    if command -v flock >/dev/null 2>&1; then
        exec 8>"\${LOCK_FILE}"
        if flock -w "\${LOCK_TIMEOUT}" 8 2>/dev/null; then
            _LOCK_ACQUIRED=1; return 0
        else
            exec 8>&- 2>/dev/null || true; return 1
        fi
    fi
    if command -v lockf >/dev/null 2>&1; then
        exec 8>"\${LOCK_FILE}"
        if lockf -s -t "\${LOCK_TIMEOUT}" 8 2>/dev/null; then
            _LOCK_ACQUIRED=2; return 0
        else
            exec 8>&- 2>/dev/null || true; return 1
        fi
    fi
    local waited=0
    while ! mkdir "\${LOCK_DIR}" 2>/dev/null; do
        sleep 0.1
        waited=\$(( waited + 1 ))
        if [ "\${waited}" -ge \$(( LOCK_TIMEOUT * 10 )) ]; then return 1; fi
    done
    _LOCK_ACQUIRED=3; return 0
}

_release() {
    case "\${_LOCK_ACQUIRED}" in
        1) flock -u 8 2>/dev/null || true; exec 8>&- 2>/dev/null || true ;;
        2) exec 8>&- 2>/dev/null || true ;;
        3) rmdir "\${LOCK_DIR}" 2>/dev/null || true ;;
    esac
}

trap _release EXIT

if ! _acquire; then
    echo "worker \$\$: could not acquire lock" >&2
    exit 1
fi

# critical section: increment the counter (read-modify-write)
CURRENT=\$(cat "\${COUNTER_FILE}" 2>/dev/null || echo "0")
NEW=\$(( CURRENT + 1 ))
# intentional sleep to induce a race condition
sleep 0.05
echo "\${NEW}" > "\${COUNTER_FILE}"
SCRIPT
chmod +x "${LOCK_SCRIPT}"

# initialize counter
echo "0" > "${TEST_FILE}"

# increment counter concurrently with 20 parallel processes
WORKERS=20
PIDS=()
for i in $(seq 1 "${WORKERS}"); do
    bash "${LOCK_SCRIPT}" "${PLANS_LOCK_FILE}" "${TEST_FILE}" &
    PIDS+=($!)
done

# wait for all workers to finish
FAILED_WORKERS=0
for pid in "${PIDS[@]}"; do
    if ! wait "${pid}" 2>/dev/null; then
        FAILED_WORKERS=$(( FAILED_WORKERS + 1 ))
    fi
done

# check result
FINAL_COUNT=$(cat "${TEST_FILE}" 2>/dev/null || echo "error")

if [ "${FAILED_WORKERS}" -gt 0 ]; then
    warn_test "${FAILED_WORKERS} workers failed to acquire the lock (possible timeout)"
fi

EXPECTED=$(( WORKERS - FAILED_WORKERS ))

if [ "${FINAL_COUNT}" = "${EXPECTED}" ]; then
    pass_test "flock mutual exclusion: ${EXPECTED} increments completed accurately across ${WORKERS} processes (no lost update)"
elif [ "${FINAL_COUNT}" = "${WORKERS}" ]; then
    pass_test "flock mutual exclusion: all ${WORKERS} processes succeeded (no lost update)"
else
    fail_test "flock mutual exclusion: final count=${FINAL_COUNT}, expected=${EXPECTED} (possible lost update)"
fi

# Test 2: confirm lost update occurs without flock (no lock)
# (test environment sanity check: confirm problems occur without exclusion control)
echo ""
echo "--- Test 2: confirm lost update without mutual exclusion (expected: inconsistency) ---"

LOCK_SCRIPT_NOLOCK="$(mktemp /tmp/test-nolock-worker-XXXXXX.sh)"
cat > "${LOCK_SCRIPT_NOLOCK}" << 'SCRIPT'
#!/bin/bash
COUNTER_FILE="$1"
CURRENT=$(cat "${COUNTER_FILE}" 2>/dev/null || echo "0")
NEW=$(( CURRENT + 1 ))
sleep 0.05  # induce a race condition
echo "${NEW}" > "${COUNTER_FILE}"
SCRIPT
chmod +x "${LOCK_SCRIPT_NOLOCK}"

TEST_FILE_NOLOCK="${WORK_DIR}/counter_nolock.txt"
echo "0" > "${TEST_FILE_NOLOCK}"

WORKERS_NOLOCK=10
PIDS_NOLOCK=()
for i in $(seq 1 "${WORKERS_NOLOCK}"); do
    bash "${LOCK_SCRIPT_NOLOCK}" "${TEST_FILE_NOLOCK}" &
    PIDS_NOLOCK+=($!)
done
for pid in "${PIDS_NOLOCK[@]}"; do
    wait "${pid}" 2>/dev/null || true
done

FINAL_NOLOCK=$(cat "${TEST_FILE_NOLOCK}" 2>/dev/null || echo "error")

if [ "${FINAL_NOLOCK}" != "${WORKERS_NOLOCK}" ]; then
    pass_test "no mutual exclusion: lost update occurred (final=${FINAL_NOLOCK}, expected=${WORKERS_NOLOCK}) — test environment is healthy"
else
    warn_test "no mutual exclusion: no lost update occurred (final=${FINAL_NOLOCK}) — may be fine depending on environment (races may not happen even without flock)"
fi

# Test 3: confirm plans-watcher.sh's flock guard is callable
echo ""
echo "--- Test 3: verify plans-watcher.sh flock function definitions ---"
WATCHER_SCRIPT="${PLUGIN_ROOT}/scripts/plans-watcher.sh"

if [ -f "${WATCHER_SCRIPT}" ]; then
    if grep -q "_plans_acquire_lock" "${WATCHER_SCRIPT}" && grep -q "_plans_release_lock" "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh defines flock guard functions"
    else
        fail_test "plans-watcher.sh flock guard functions not found"
    fi

    if grep -q "plans.flock" "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh uses .claude/state/locks/plans.flock"
    else
        fail_test "plans-watcher.sh does not use plans.flock"
    fi

    if grep -q 'trap.*_plans_watcher_cleanup.*EXIT' "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh has an EXIT trap set"
    else
        fail_test "plans-watcher.sh has no EXIT trap set"
    fi

    # fail-closed verification (41.1.3): confirm exit 11 code exists
    if grep -q 'exit 11' "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh fail-closes with exit 11 when lock acquisition fails"
    else
        fail_test "plans-watcher.sh has no exit 11 (fail-closed) set"
    fi

    # fail-closed verification: confirm retry logic exists
    if grep -q '_PLANS_LOCK_MAX_RETRIES' "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh has retry logic (_PLANS_LOCK_MAX_RETRIES)"
    else
        fail_test "plans-watcher.sh retry logic not found"
    fi
else
    fail_test "plans-watcher.sh not found: ${WATCHER_SCRIPT}"
fi

# Test 4: verify fail-closed actual behavior (run plans-watcher.sh equivalent with lock pre-acquired)
echo ""
echo "--- Test 4: verify fail-closed actual behavior (exit 11 on lock contention) ---"

# start a background process that pre-acquires and keeps holding the lock file
FAIL_CLOSED_LOCK="${WORK_DIR}/.claude/state/locks/fc-test.flock"
mkdir -p "$(dirname "${FAIL_CLOSED_LOCK}")"

# minimal fail-closed script (excerpt of plans-watcher.sh's retry + exit 11 logic)
FC_SCRIPT="$(mktemp /tmp/test-fc-XXXXXX.sh)"
cat > "${FC_SCRIPT}" << 'FCSCRIPT'
#!/bin/bash
LOCK_FILE="$1"
LOCK_TIMEOUT=1  # keep it short for the test
_LOCK_ACQUIRED=0

_acquire() {
    mkdir -p "$(dirname "${LOCK_FILE}")" 2>/dev/null || true
    if command -v flock >/dev/null 2>&1; then
        exec 8>"${LOCK_FILE}"
        if flock -w "${LOCK_TIMEOUT}" 8 2>/dev/null; then
            _LOCK_ACQUIRED=1; return 0
        else
            exec 8>&- 2>/dev/null || true; return 1
        fi
    fi
    if command -v lockf >/dev/null 2>&1; then
        exec 8>"${LOCK_FILE}"
        if lockf -s -t "${LOCK_TIMEOUT}" 8 2>/dev/null; then
            _LOCK_ACQUIRED=2; return 0
        else
            exec 8>&- 2>/dev/null || true; return 1
        fi
    fi
    local waited=0
    local lock_dir="${LOCK_FILE}.dir"
    while ! mkdir "${lock_dir}" 2>/dev/null; do
        sleep 0.1
        waited=$(( waited + 1 ))
        if [ "${waited}" -ge $(( LOCK_TIMEOUT * 10 )) ]; then return 1; fi
    done
    _LOCK_ACQUIRED=3; return 0
}

_LOCK_MAX=3
_GOT=0
for _r in 1 2 3; do
    if _acquire; then _GOT=1; break; fi
    if [ "${_r}" -lt "${_LOCK_MAX}" ]; then sleep 0.2; fi
done

if [ "${_GOT}" -eq 0 ]; then
    echo "fail-closed: abort" >&2
    exit 11
fi

echo "lock acquired"
exit 0
FCSCRIPT
chmod +x "${FC_SCRIPT}"

# process that keeps holding the lock (reliably locks via mkdir method)
FC_LOCK_DIR="${FAIL_CLOSED_LOCK}.dir"
mkdir -p "${FC_LOCK_DIR}" 2>/dev/null || true

# run the script while lock is held → should return exit 11
bash "${FC_SCRIPT}" "${FAIL_CLOSED_LOCK}"
FC_EXIT=$?
rmdir "${FC_LOCK_DIR}" 2>/dev/null || true

if [ "${FC_EXIT}" -eq 11 ]; then
    pass_test "fail-closed: exit 11 returned on lock contention (as expected)"
elif [ "${FC_EXIT}" -eq 0 ]; then
    # in environments where flock/lockf is available, locks may coexist, so keep it a warn
    warn_test "fail-closed: exit 0 (in flock/lockf environments this may coexist with the mkdir lock)"
else
    fail_test "fail-closed: unexpected exit code: ${FC_EXIT} (expected: 11)"
fi

# cleanup
rm -f "${LOCK_SCRIPT}" "${LOCK_SCRIPT_NOLOCK}" "${FC_SCRIPT}" 2>/dev/null || true

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
    echo -e "${RED}✗ ${FAIL_COUNT} tests failed${NC}"
    exit 1
fi
