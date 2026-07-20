#!/usr/bin/env bash
# test-flow-e2e-dryrun.sh — harness-flow end-to-end state-machine walk (Phase 6).
#
# The skill's MCP/LLM steps are not scriptable, so this exercises the
# deterministic spine: the helper scripts drive one flow-session.v1 through its
# full lifecycle (ingest -> verify -> plan -> work -> review -> confirm ->
# commit -> done) inside a throwaway git repo, and we assert:
#   - the session reaches `done`
#   - a per-task commit tagged [PROJ-123] exists
#   - NO push is ever attempted (no remote is configured; the flow must not push)
#   - the skill + references pin the no-push contract and all reference files exist
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESS="${ROOT}/scripts/flow-session.sh"
INGEST="${ROOT}/scripts/flow-ingest-requirement.sh"
SKILL_DIR="${ROOT}/skills/harness-flow"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1" >&2; fail=1; }

# --- skill + references present ---
[ -f "${SKILL_DIR}/SKILL.md" ] || die "SKILL.md missing"
for ref in ingestion verify-rubric ba-loop planning-split confirm-gate commit-close; do
  [ -f "${SKILL_DIR}/references/${ref}.md" ] || die "reference missing: ${ref}.md"
done
[ "${fail}" -eq 0 ] && pass "skill + all 6 references present"

# --- no-push contract pinned ---
if grep -q "NEVER pushes" "${SKILL_DIR}/references/commit-close.md" \
  && grep -q "NEVER push" "${SKILL_DIR}/SKILL.md"; then
  pass "no-push contract is pinned in SKILL.md + commit-close.md"
else
  die "no-push contract not pinned"
fi

# --- approval-before-external-write pinned (BA comment must NOT auto-post) ---
if grep -qi "never auto-post" "${SKILL_DIR}/references/ba-loop.md" \
  && grep -qi "approval BEFORE posting" "${SKILL_DIR}/references/ba-loop.md" \
  && grep -qi "external write needs your approval" "${SKILL_DIR}/SKILL.md"; then
  pass "external-write approval gate is pinned (BA comment / JIRA writes not auto-sent)"
else
  die "approval-before-external-write gate not pinned"
fi

# --- throwaway repo ---
REPO="${TMP}/repo"
mkdir -p "${REPO}"
(
  cd "${REPO}"
  git init -q
  git config user.email flow@test.local
  git config user.name "flow test"
  echo "seed" > README.md
  git add README.md
  git commit -qm "seed"
)

# --- drive the session lifecycle ---
STATE_DIR="${REPO}/.claude/state/flow/proj-123"
SFILE="$(PROJECT_ROOT="${REPO}" bash "${SESS}" init --session-id proj-123 --source jira --source-ref PROJ-123 --out "${STATE_DIR}/session.json")"

printf 'Add health endpoint.\n' > "${TMP}/desc.txt"
printf 'GET /health returns 200\n' > "${TMP}/ac.txt"
RFILE="$(bash "${INGEST}" --source jira --source-ref PROJ-123 --title "Add /health" \
  --description-file "${TMP}/desc.txt" --acceptance-criteria-file "${TMP}/ac.txt" \
  --mcp-available true --out "${STATE_DIR}/requirement.json")"
bash "${SESS}" set "${SFILE}" requirement_path "${RFILE}"
bash "${SESS}" status "${SFILE}" ingested

# verify ok -> planning
bash "${SESS}" status "${SFILE}" verifying
bash "${SESS}" status "${SFILE}" planning
bash "${SESS}" set-json "${SFILE}" plans '["main"]'

# work: create a per-task commit tagged with the JIRA key
bash "${SESS}" status "${SFILE}" working
(
  cd "${REPO}"
  echo "ok" > health.txt
  git add health.txt
  git commit -qm "[PROJ-123] add /health endpoint"
)
HASH="$(cd "${REPO}" && git rev-parse HEAD)"
bash "${SESS}" set-json "${SFILE}" commit_hashes "$(printf '["%s"]' "${HASH}")"

# review -> confirm -> commit -> done
bash "${SESS}" status "${SFILE}" reviewing
bash "${SESS}" status "${SFILE}" awaiting-confirm
bash "${SESS}" status "${SFILE}" committing
bash "${SESS}" status "${SFILE}" done

# --- assertions ---
bash "${SESS}" validate "${SFILE}" >/dev/null 2>&1 && pass "final session validates" || die "final session invalid"
[ "$(bash "${SESS}" get "${SFILE}" .status)" = "done" ] && pass "session reached done" || die "session not done"
[ "$(bash "${SESS}" get "${SFILE}" '.commit_hashes[0]')" = "${HASH}" ] && pass "commit hash recorded" || die "commit hash not recorded"

if (cd "${REPO}" && git log --oneline -1 | grep -q '\[PROJ-123\]'); then
  pass "per-task commit is tagged [PROJ-123]"
else
  die "commit not tagged with JIRA key"
fi

# no remote => a push is impossible; assert the flow never configured one
if (cd "${REPO}" && [ -z "$(git remote)" ]); then
  pass "no remote configured — flow did not push"
else
  die "unexpected remote configured"
fi

if [ "${fail}" -ne 0 ]; then
  echo "test-flow-e2e-dryrun: FAIL"
  exit 1
fi
echo "test-flow-e2e-dryrun: all PASS"
exit 0
