#!/bin/bash
# test-team-composition-advisor.sh
# Consistency test for role-division docs that include the Advisor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

ADVISOR_FILE="${PROJECT_ROOT}/agents/advisor.md"
TEAM_FILE="${PROJECT_ROOT}/docs/team-composition.md"
WORKER_FILE="${PROJECT_ROOT}/agents/worker.md"
REVIEWER_FILE="${PROJECT_ROOT}/agents/reviewer.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

for file in "${ADVISOR_FILE}" "${TEAM_FILE}" "${WORKER_FILE}" "${REVIEWER_FILE}"; do
  [ -f "${file}" ] || fail "missing file: ${file}"
done

grep -q 'advisor-response.v1' "${ADVISOR_FILE}" \
  || fail "advisor.md is missing advisor-response.v1"

grep -q 'PLAN / CORRECTION / STOP' "${ADVISOR_FILE}" \
  || fail "advisor.md is missing the 3 decision types"

grep -q 'Do not write code' "${ADVISOR_FILE}" \
  || fail "advisor.md is missing the no-implementation rule"

grep -q 'The Harness standard team has 5 roles' "${TEAM_FILE}" \
  || fail "team-composition.md is missing the 5-role composition description"

grep -q 'permissionMode' "${TEAM_FILE}" \
  || fail "team-composition.md is missing the permissionMode boundary description"

grep -q 'inherited from the parent session and plugin settings' "${TEAM_FILE}" \
  || fail "team-composition.md is missing the permission-inheritance description"

grep -q 'advisor-request.v1' "${WORKER_FILE}" \
  || fail "worker.md is missing advisor-request.v1"

grep -q 'The Advisor is a separate role and not a substitute for the Reviewer' "${REVIEWER_FILE}" \
  || fail "reviewer.md does not state that Advisor is not a replacement"

echo "test-team-composition-advisor: ok"
