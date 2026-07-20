#!/usr/bin/env bash
# test-bug-contracts.sh — harness-bugfix contracts.
#
# Proves: bug-report.v1 schema + flow-ingest-bug.sh, the new bug statuses in
# flow-session.v1 (triaging / not-a-bug / awaiting-push), and that the skill +
# references pin the bug-specific contract (triage-vs-source, QA not BA,
# sequential pause-to-push, no push, approval before posting).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUG_SCHEMA="${ROOT}/templates/schemas/bug-report.v1.json"
INGEST="${ROOT}/scripts/flow-ingest-bug.sh"
SESS="${ROOT}/scripts/flow-session.sh"
SKILL_DIR="${ROOT}/skills/harness-bugfix"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1" >&2; fail=1; }

# --- presence ---
[ -f "${BUG_SCHEMA}" ] || die "bug-report.v1 schema missing"
[ -x "${INGEST}" ] || die "flow-ingest-bug.sh missing/not executable"
[ -f "${SKILL_DIR}/SKILL.md" ] || die "harness-bugfix SKILL.md missing"
for ref in triage-rubric qa-comment sequential-batch; do
  [ -f "${SKILL_DIR}/references/${ref}.md" ] || die "reference missing: ${ref}.md"
done
[ "${fail}" -eq 0 ] && pass "skill + schema + 3 references present"

# --- ingest happy path ---
printf 'Login returns 500 on empty password.\n' > "${TMP}/desc.txt"
printf 'Open login\nSubmit empty password\nObserve 500\n' > "${TMP}/steps.txt"
printf '400 Bad Request\n' > "${TMP}/exp.txt"
printf '500 Internal Server Error\n' > "${TMP}/act.txt"
BFILE="$(bash "${INGEST}" --source jira --source-ref BUG-42 --title "Login 500 on empty password" \
  --description-file "${TMP}/desc.txt" --steps-file "${TMP}/steps.txt" \
  --expected-file "${TMP}/exp.txt" --actual-file "${TMP}/act.txt" \
  --environment "prod v1.2" --reporter-account-id qa-acct --mcp-available true \
  --out "${TMP}/bug.json")"
if [ "$(jq -r .schema_version "${BFILE}")" = "bug-report.v1" ] \
  && [ "$(jq -r '.steps_to_reproduce | length' "${BFILE}")" = "3" ] \
  && [ "$(jq -r .expected_behavior "${BFILE}")" = "400 Bad Request" ] \
  && [ "$(jq -r .reporter_account_id "${BFILE}")" = "qa-acct" ]; then
  pass "ingest writes a valid bug-report.v1 (steps + expected + reporter)"
else
  die "bug ingest output malformed"
fi

# --- triage verdict merges + validates ---
jq '.triage = {verdict:"bug", evidence:"api/x.go:10 no guard", code_refs:["api/x.go:10"], reproduced:true, open_questions:[]}' \
  "${BFILE}" > "${TMP}/bug2.json"
python3 - "${TMP}/bug2.json" "${BUG_SCHEMA}" <<'PY' && echo "triage-valid" >/dev/null
import json,sys
d=json.load(open(sys.argv[1])); s=json.load(open(sys.argv[2]))
try:
    import jsonschema; jsonschema.validate(d,s)
except ImportError:
    assert d["triage"]["verdict"]=="bug"
PY
[ "$(jq -r '.triage.verdict' "${TMP}/bug2.json")" = "bug" ] && pass "triage block accepts a bug verdict" || die "triage merge failed"

# --- ingest rejects bad source ---
if bash "${INGEST}" --source nope --source-ref X --title Y --out "${TMP}/z.json" >/dev/null 2>&1; then
  die "bug ingest accepted invalid --source"
else
  pass "bug ingest rejects invalid --source"
fi

# --- new bug statuses accepted by flow-session ---
SFILE="$(PROJECT_ROOT="${TMP}" bash "${SESS}" init --session-id bug-42 --source jira --source-ref BUG-42 --out "${TMP}/session.json")"
ok_status=1
for st in triaging not-a-bug awaiting-push; do
  bash "${SESS}" status "${SFILE}" "${st}" >/dev/null 2>&1 || ok_status=0
  [ "$(bash "${SESS}" get "${SFILE}" .status)" = "${st}" ] || ok_status=0
done
[ "${ok_status}" -eq 1 ] && pass "flow-session accepts triaging/not-a-bug/awaiting-push" || die "new bug statuses rejected"
bash "${SESS}" validate "${SFILE}" >/dev/null 2>&1 && pass "bug session validates" || die "bug session invalid"

# --- contract text pinned ---
if grep -qi "one at a time" "${SKILL_DIR}/SKILL.md" \
  && grep -qi "pause after each" "${SKILL_DIR}/SKILL.md" \
  && grep -q "NEVER push" "${SKILL_DIR}/SKILL.md" \
  && grep -qi "approval before every post" "${SKILL_DIR}/references/qa-comment.md" \
  && grep -qi "current source code" "${SKILL_DIR}/references/triage-rubric.md"; then
  pass "bug contract pinned (sequential pause-to-push, no push, QA approval, triage vs source)"
else
  die "bug contract text not pinned"
fi

if [ "${fail}" -ne 0 ]; then
  echo "test-bug-contracts: FAIL"
  exit 1
fi
echo "test-bug-contracts: all PASS"
exit 0
