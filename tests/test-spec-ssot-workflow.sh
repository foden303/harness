#!/bin/bash
# Verify that Plans.md task workflows also preserve a project spec SSOT when needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if grep -Fq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label ($file does not contain '$pattern')"
  fi
}

SPEC_DOC="$PLUGIN_ROOT/docs/plans/spec-ssot.md"
ROOT_SPEC="$PLUGIN_ROOT/spec.md"
PLAN_SKILL="$PLUGIN_ROOT/skills/harness-plan/SKILL.md"
PLAN_CREATE_REF="$PLUGIN_ROOT/skills/harness-plan/references/create.md"
WORK_SKILL="$PLUGIN_ROOT/skills/harness-work/SKILL.md"
WORK_EXEC_REF="$PLUGIN_ROOT/skills/harness-work/references/execution-modes.md"
WORKER_AGENT="$PLUGIN_ROOT/agents/worker.md"
REVIEWER_AGENT="$PLUGIN_ROOT/agents/reviewer.md"
REVIEW_SKILL="$PLUGIN_ROOT/skills/harness-review/SKILL.md"

echo "=== spec SSOT workflow test ==="

[ -f "$SPEC_DOC" ] || fail "docs/plans/spec-ssot.md not found"
[ -f "$ROOT_SPEC" ] || fail "root spec.md not found"

require_contains "$SPEC_DOC" 'Plans.md is the task ledger. `spec.md` is the product contract.' "spec doc separates the roles of Plans.md and root spec.md"
require_contains "$SPEC_DOC" "co-required planning output" "spec doc defines co-required planning output"
require_contains "$SPEC_DOC" 'Precedence stays: `spec.md` > sub-spec > `Plans.md`' "spec doc maintains spec precedence"
require_contains "$SPEC_DOC" 'Use the root `spec.md` first.' "spec doc states root spec.md takes top precedence"
require_contains "$SPEC_DOC" 'Only when the consumer repository has no root `spec.md`, fall back' "spec doc limits the consumer fallback condition"
require_contains "$SPEC_DOC" "docs/spec/00-project-spec.md" "spec doc shows the fallback spec path"
require_contains "$SPEC_DOC" "When To Create Or Update It" "spec doc has create/update conditions"
require_contains "$SPEC_DOC" "When To Skip" "spec doc has skip conditions"
require_contains "$SPEC_DOC" "Spec delta" "spec doc requires Spec delta output"
require_contains "$SPEC_DOC" "Spec skip reason" "spec doc requires Spec skip reason output"
require_contains "$SPEC_DOC" 'Every `create` output and every product-impacting `add` output' "spec doc requires spec result for both create and add"
require_contains "$SPEC_DOC" "produce the spec result before generating tasks" "spec doc requires spec result before tasks even for add"
require_contains "$SPEC_DOC" 'Harness generates `Spec delta` and `Spec skip reason`; the consumer approves or edits them' "spec doc shows the Harness-generates / consumer-approves-or-edits boundary"
require_contains "$SPEC_DOC" "task context or sprint contract" "spec doc shows where the skip reason is stored for docs-only / mechanical tasks"
require_contains "$SPEC_DOC" "not_observed != absent" "spec doc maintains the not-observed data contract"
require_contains "$SPEC_DOC" "The agent drafts the spec delta" "spec doc shows it does not assume the user writes it by hand"
require_contains "$SPEC_DOC" "team-validated" "spec doc requires team validation for non-trivial planning"
require_contains "$SPEC_DOC" "TeamAgent or sub-agent perspectives" "spec doc states the TeamAgent / sub-agent premise"
require_contains "$SPEC_DOC" "team_validation_mode" "spec doc requires team_validation_mode"
require_contains "$SPEC_DOC" 'Non-trivial work must use `native`, `subagent`, or `manual-pass`' "spec doc limits the non-trivial mode"
require_contains "$SPEC_DOC" 'not required runtime `agent_type` names' "spec doc separates perspective from agent_type"
require_contains "$SPEC_DOC" "project-scoped harness-mem / harness-recall / repo-memory wheel check" "spec doc requires a reinvention-prevention check"
require_contains "$SPEC_DOC" "security fit for permissions, secrets, external sends, supply chain" "spec doc requires a security gate"
require_contains "$SPEC_DOC" "works-in-practice proof through test, smoke, CI, review" "spec doc requires a works-in-practice gate"
require_contains "$SPEC_DOC" "Security fit must not require reading secrets" "spec doc does not require reading secrets"

require_contains "$ROOT_SPEC" "Plans.md is the task ledger" "root spec defines Plans.md as the task ledger"
require_contains "$ROOT_SPEC" "co-required planning output" "root spec defines co-required planning output"
require_contains "$ROOT_SPEC" "spec.md > sub-spec > Plans.md" "root spec maintains precedence"
require_contains "$ROOT_SPEC" "spec.md product contract and Plans.md task contract" "root spec defines the dual-source planning surface"
require_contains "$ROOT_SPEC" "Spec delta" "root spec has a Spec delta output contract"
require_contains "$ROOT_SPEC" "Spec skip reason" "root spec has a Spec skip reason output contract"
require_contains "$ROOT_SPEC" 'product-impacting `/harness-plan add` must produce' "root spec requires spec result for product-impacting add"
require_contains "$ROOT_SPEC" "produce the spec result before producing task rows" "root spec requires spec result before tasks even for add"
require_contains "$ROOT_SPEC" "Harness generates the spec result" "root spec has the Harness-generates / consumer-approves-or-edits boundary"
require_contains "$ROOT_SPEC" "not_observed != absent" "root spec has the not-observed data contract"
require_contains "$ROOT_SPEC" "Non-trivial planning must be team-validated" "root spec requires team validation for non-trivial planning"
require_contains "$ROOT_SPEC" "TeamAgent or sub-agent perspectives" "root spec states the TeamAgent / sub-agent premise"
require_contains "$ROOT_SPEC" "team_validation_mode" "root spec requires team_validation_mode"
require_contains "$ROOT_SPEC" 'Non-trivial work must use `native`, `subagent`, or `manual-pass`' "root spec limits the non-trivial mode"
require_contains "$ROOT_SPEC" 'not required runtime `agent_type` names' "root spec separates perspective from agent_type"
require_contains "$ROOT_SPEC" "project-scoped harness-mem / harness-recall / repo-memory wheel check" "root spec requires a reinvention-prevention check"
require_contains "$ROOT_SPEC" "security validation for permissions, secrets, external sends, supply chain" "root spec requires security validation"
require_contains "$ROOT_SPEC" "works-in-practice validation" "root spec requires works-in-practice validation"
require_contains "$ROOT_SPEC" "Security validation must not require reading secrets" "root spec does not require reading secrets"
require_contains "$ROOT_SPEC" "docs/architecture/hokage-core.md" "root spec references Hokage Core as a sub-spec"
require_contains "$ROOT_SPEC" "go/SPEC.md" "root spec references the Go runtime sub-spec"
require_contains "$ROOT_SPEC" "Host Adapter Boundary" "root spec has a host adapter boundary"
require_contains "$ROOT_SPEC" "Support Tiers And Host Claims" "root spec has a support tier contract"
require_contains "$ROOT_SPEC" "Onboarding Contract" "root spec has an onboarding contract"
require_contains "$ROOT_SPEC" "New Session Bootstrap Rule" "root spec has a new session bootstrap rule"
require_contains "$ROOT_SPEC" "future/unsupported" "root spec manages unsupported host claims by tier"

require_contains "$PLAN_SKILL" "spec.md / Plans.md dual-source check (default)" "harness-plan includes the dual-source check in the default flow"
require_contains "$PLAN_SKILL" "purpose: \"Maintain co-required planning output for the spec.md product contract and Plans.md task contract\"" "harness-plan purpose includes the dual-source contract"
require_contains "$PLAN_SKILL" "docs/plans/spec-ssot.md" "harness-plan references the spec SSOT doc"
require_contains "$PLAN_SKILL" 'The output must always include a `Spec delta` or `Spec skip reason`' "harness-plan requires spec delta / skip reason output"
require_contains "$PLAN_SKILL" "generated by Harness; the consumer only approves or amends" "harness-plan has the Harness-generates / consumer-approves-or-edits boundary"
require_contains "$PLAN_SKILL" "Non-trivial planning gate" "harness-plan has a non-trivial planning gate"
require_contains "$PLAN_SKILL" "requiring TeamAgent or subagents" "harness-plan has the TeamAgent / subagent premise"
require_contains "$PLAN_SKILL" "Reinvention-prevention check" "harness-plan requires a memory wheel check"
require_contains "$PLAN_SKILL" "Whether it is a workable plan" "harness-plan requires a works-in-practice gate"
require_contains "$PLAN_CREATE_REF" "## Step 4.4: spec.md / Plans.md dual-source check" "harness-plan create reference has the dual-source step"
require_contains "$PLAN_CREATE_REF" 'Read the root `spec.md` every time' "harness-plan create requires a root spec.md pre-read"
require_contains "$PLAN_CREATE_REF" 'The output of `/harness-plan create` is always a set of these 2' "harness-plan create requires the Spec + Plans pair"
require_contains "$PLAN_CREATE_REF" "product fit, security fit, and works in practice" "harness-plan create has implementation-plan validation perspectives"

require_contains "$WORK_SKILL" "Spec SSOT preflight" "harness-work has a pre-implementation spec-SSOT preflight"
require_contains "$WORK_SKILL" "spec_path" "harness-work passes spec_path to Worker / Reviewer"
require_contains "$WORK_EXEC_REF" "project spec SSOT" "shared execution mode has a spec SSOT preflight"


require_contains "$WORKER_AGENT" "spec_path" "Worker input receives spec_path"
require_contains "$REVIEWER_AGENT" "spec_path" "Reviewer input receives spec_path"
require_contains "$REVIEW_SKILL" "spec source-of-truth alignment check" "harness-review checks spec alignment"

echo "All spec SSOT workflow checks passed."
