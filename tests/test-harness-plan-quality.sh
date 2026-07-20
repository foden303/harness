#!/usr/bin/env bash
#
# Guard the harness-plan planning quality contract across shipped skill mirrors.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "test-harness-plan-quality: FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [ -f "$path" ] || fail "missing file: $path"
}

assert_absent() {
  local path="$1"
  local needle="$2"
  if grep -qF "$needle" "$path"; then
    fail "$path should not contain: $needle"
  fi
}

assert_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -qF "$needle" "$path"; then
    fail "$path missing: $needle"
  fi
}

plan_output_contract_valid() {
  local output="$1"

  { grep -qF "Spec delta:" <<<"$output" || grep -qF "Spec skip reason:" <<<"$output"; } \
    && grep -qF "Plans.md:" <<<"$output"
}

nontrivial_planning_gate_valid() {
  local output="$1"

  { grep -qF "team_validation_mode: native" <<<"$output" \
      || grep -qF "team_validation_mode: subagent" <<<"$output" \
      || grep -qF "team_validation_mode: manual-pass" <<<"$output"; } \
    && grep -qF "Spec / Plans Fit:" <<<"$output" \
    && grep -qF "Memory / Wheel Check:" <<<"$output" \
    && grep -qF "Product Fit:" <<<"$output" \
    && grep -qF "Security Fit:" <<<"$output" \
    && grep -qF "Quality Baseline Fit:" <<<"$output" \
    && grep -qF "Works In Practice:" <<<"$output" \
    && ! grep -qF "team_validation_mode: unavailable" <<<"$output"
}

lightweight_planning_gate_valid() {
  local output="$1"

  grep -qF "team_validation_mode: not_required_lightweight" <<<"$output" \
    && grep -qF "Spec skip reason:" <<<"$output" \
    && grep -qF "Plans.md:" <<<"$output"
}

security_gate_avoids_secret_read() {
  local output="$1"

  grep -qF "Security Fit:" <<<"$output" \
    && grep -qF "do not read secrets" <<<"$output" \
    && grep -qF "Risk Gate" <<<"$output" \
    && ! grep -qE 'cat \.env|Read \.env|open secret|print token' <<<"$output"
}

assert_plan_output_contract_valid() {
  local label="$1"
  local output="$2"

  if ! plan_output_contract_valid "$output"; then
    fail "$label should include Spec delta or Spec skip reason plus Plans.md"
  fi
}

assert_plan_output_contract_invalid() {
  local label="$1"
  local output="$2"

  if plan_output_contract_valid "$output"; then
    fail "$label should fail without Spec delta or Spec skip reason"
  fi
}

assert_nontrivial_gate_valid() {
  local label="$1"
  local output="$2"

  if ! nontrivial_planning_gate_valid "$output"; then
    fail "$label should include team validation plus Spec/Memory/Product/Security/Works gates"
  fi
}

assert_nontrivial_gate_invalid() {
  local label="$1"
  local output="$2"

  if nontrivial_planning_gate_valid "$output"; then
    fail "$label should fail without complete non-trivial planning gates"
  fi
}

assert_lightweight_gate_valid() {
  local label="$1"
  local output="$2"

  if ! lightweight_planning_gate_valid "$output"; then
    fail "$label should allow not_required_lightweight for lightweight work"
  fi
}

assert_security_gate_safe() {
  local label="$1"
  local output="$2"

  if ! security_gate_avoids_secret_read "$output"; then
    fail "$label should avoid requiring secret reads"
  fi
}

primary_surfaces=(
  "skills/harness-plan"
)

check_plan_surface() {
  local surface="$1"
  skill="$surface/SKILL.md"
  create_ref="$surface/references/create.md"
  quality_ref="$surface/references/planning-quality.md"

  assert_file "$skill"
  assert_file "$create_ref"
  assert_file "$quality_ref"

  assert_contains "$skill" "Research-backed, team-validated task planning"
  assert_contains "$skill" "team-validated task planning"
  assert_contains "$skill" "### Standard planning quality contract"
  assert_contains "$skill" "See [references/planning-quality.md]"
  assert_contains "$skill" "Non-trivial planning gate"
  assert_contains "$skill" "treated as requiring TeamAgent or subagents"
  assert_contains "$skill" "Product / Architecture / Security / QA / Skeptic"
  assert_contains "$skill" "Required / Recommended / Optional / Reject"
  assert_contains "$skill" "Reinvention-prevention check"
  assert_contains "$skill" "stays aligned with the product's purpose"
  assert_contains "$skill" "security, permissions, secrets, or the supply chain"
  assert_contains "$skill" "lint / formatter baseline"
  assert_contains "$skill" "source code changes"
  assert_contains "$skill" "Whether it is a workable plan"
  assert_contains "$skill" '`team_validation_mode`: `not_required_lightweight` / `native` / `subagent` / `manual-pass` / `unavailable`'
  assert_contains "$skill" 'Do not leave it as `unavailable` while marking it Required'
  assert_contains "$skill" "not agent_type names"
  assert_contains "$skill" "do not require spawning arbitrary agents"
  assert_contains "$skill" "The Security gate does not require actually reading secrets"
  assert_contains "$skill" "co-required planning output"
  assert_contains "$skill" "spec.md > sub-spec > Plans.md"
  assert_contains "$skill" "spec.md product contract and Plans.md task contract"
  assert_contains "$skill" '`/harness-plan create` returns a `Spec delta` or `Spec skip reason` together with generated `Plans.md` tasks'
  assert_contains "$skill" "generated by Harness; the consumer only approves or amends it"
  assert_contains "$skill" '`create` and product-impacting `add` read the root `spec.md` every time'
  assert_contains "$skill" 'The output must always include a `Spec delta` or `Spec skip reason`'
  assert_contains "$skill" 'Only when the consumer repo has no root `spec.md`'
  assert_contains "$skill" "not_observed != absent"

  assert_absent "$skill" "/harness-plan maxplan"
  assert_absent "$skill" "argument-hint: \"[create|maxplan"
  assert_absent "$skill" "### maxplan"

  assert_contains "$create_ref" "## Step 3: Planning quality check"
  assert_contains "$create_ref" "references/planning-quality.md"
  assert_contains "$create_ref" "treated as requiring TeamAgent or subagents"
  assert_contains "$create_ref" "Product / Architecture / Security / QA / Skeptic"
  assert_contains "$create_ref" "check product fit, security fit, and works in practice"
  assert_contains "$create_ref" '`formatter_baseline`'
  assert_contains "$create_ref" "front-load a setup task if lint / formatter is unset"
  assert_contains "$create_ref" "Do not install packages during planning"
  assert_contains "$create_ref" "Product Fit, Evidence Strength, User Value, Implementation Feasibility, Regression Safety, Strategic Leverage, Security Safety"
  assert_contains "$create_ref" 'Do not read the `harness-mem` DB directly'
  assert_contains "$create_ref" "avoid reinventing the wheel"
  assert_contains "$create_ref" 'subagents-not-used'
  assert_contains "$create_ref" '`team_validation_mode` as one of `not_required_lightweight` / `native` / `subagent` / `manual-pass` / `unavailable`'
  assert_contains "$create_ref" "Product / Architecture / Security / QA / Skeptic are perspective names, not agent_type names"
  assert_contains "$create_ref" 'The Security gate does not require actually reading `.env` or secrets'
  assert_contains "$create_ref" "## Step 4.4: spec.md / Plans.md dual-source check"
  assert_contains "$create_ref" 'Read the root `spec.md` every time'
  assert_contains "$create_ref" "Spec delta"
  assert_contains "$create_ref" "Spec skip reason"
  assert_contains "$create_ref" "co-required planning output"
  assert_contains "$create_ref" "generated by Harness; the consumer only approves or amends it"
  assert_contains "$create_ref" "Do not make the user write the spec from scratch"
  assert_contains "$create_ref" "docs-only / mechanical task"

  assert_contains "$quality_ref" "This is not a standalone subcommand"
  assert_contains "$quality_ref" "WebSearch"
  assert_contains "$quality_ref" "Use a cross-project search only when the user explicitly asks"
  assert_contains "$quality_ref" "Do not assume you can read the harness-mem DB directly"
  assert_contains "$quality_ref" "multi-perspective discussion via TeamAgent / subagents"
  assert_contains "$quality_ref" "Non-trivial planning assumes TeamAgent or subagent validation"
  assert_contains "$quality_ref" 'The output must always include `team_validation_mode`'
  assert_contains "$quality_ref" '`not_required_lightweight`'
  assert_contains "$quality_ref" '`manual-pass`'
  assert_contains "$quality_ref" 'Do not mark non-trivial work as Required'
  assert_contains "$quality_ref" 'Do not mark a `team_validation_mode: unavailable` plan as Required'
  assert_contains "$quality_ref" "reinvention-prevention check"
  assert_contains "$quality_ref" '`create` and product-impacting `add` read the root `spec.md` every time'
  assert_contains "$quality_ref" 'Only in a consumer repo without a root `spec.md`'
  assert_contains "$quality_ref" "Spec delta"
  assert_contains "$quality_ref" "Spec skip reason"
  assert_contains "$quality_ref" "co-required planning output"
  assert_contains "$quality_ref" "not_observed != absent"
  assert_contains "$quality_ref" "Product / Strategy"
  assert_contains "$quality_ref" "Architecture / Implementation"
  assert_contains "$quality_ref" "Security / Abuse"
  assert_contains "$quality_ref" "perspective names, not agent_type names"
  assert_contains "$quality_ref" "Do not require spawning arbitrary agents"
  assert_contains "$quality_ref" "QA / Regression"
  assert_contains "$quality_ref" "Skeptic"
  assert_contains "$quality_ref" "## Step 5.5: Implementation plan validation gate"
  assert_contains "$quality_ref" "Spec / Plans Fit"
  assert_contains "$quality_ref" "Memory / Wheel Check"
  assert_contains "$quality_ref" "Security Fit"
  assert_contains "$quality_ref" "Quality Baseline Fit"
  assert_contains "$quality_ref" "formatter_baseline setup task"
  assert_contains "$quality_ref" "source code changes"
  assert_contains "$quality_ref" "Do not install packages during planning"
  assert_contains "$quality_ref" "Works In Practice"
  assert_contains "$quality_ref" "Security Fit does not require actually reading secrets"
  assert_contains "$quality_ref" "stop it as a Risk Gate"
  assert_contains "$quality_ref" "Implementation Feasibility"
  assert_contains "$quality_ref" "Regression Safety"
  assert_contains "$quality_ref" "Security Safety"
  assert_contains "$quality_ref" "Works In Practice"
  assert_contains "$quality_ref" "Directly at the core of the target product"
  assert_absent "$quality_ref" "at the core of Harness"
  assert_contains "$quality_ref" "If Evidence Strength is 2 or below, Required is prohibited"
  assert_contains "$quality_ref" "If Regression Safety is 2 or below, place a spike / spec / test first"
  assert_contains "$quality_ref" "If Security Safety is 2 or below, Required is prohibited"
  assert_contains "$quality_ref" "If Works In Practice is 2 or below, rebuild the DoD or drop it to a spike"
  assert_contains "$quality_ref" '## Step 7: `$easy` report'
}

for surface in "${primary_surfaces[@]}"; do
  check_plan_surface "$surface"
  assert_contains "$surface/SKILL.md" "purpose: \"Maintain co-required planning output for the spec.md product contract and Plans.md task contract\""
  assert_contains "$surface/SKILL.md" "argument-hint: \"[create|add|update|sync|sync --no-retro|--ci]\""
done

assert_contains "scripts/sync-skill-mirrors.sh" '".agents/skills"'
if [ -d ".agents/skills/harness-plan" ]; then
  check_plan_surface ".agents/skills/harness-plan"
fi

assert_plan_output_contract_valid "create fixture with Spec delta" "Spec delta:
- path: spec.md
- change: add product contract
Plans.md:
| Task | Content | DoD | Depends | Status |"

assert_plan_output_contract_valid "add fixture with Spec skip reason" "Spec skip reason:
- path checked: spec.md
- reason: docs-only task
Plans.md:
| Task | Content | DoD | Depends | Status |"

assert_plan_output_contract_invalid "create fixture missing spec result" "Plans.md:
| Task | Content | DoD | Depends | Status |"

assert_plan_output_contract_invalid "add fixture missing spec result" "Plan:
- add a task with no spec result"

assert_lightweight_gate_valid "lightweight fixture" "team_validation_mode: not_required_lightweight
Spec skip reason:
- path checked: spec.md
- reason: typo/docs-only/update/sync lightweight work
Plans.md:
| Task | Content | DoD | Depends | Status |"

assert_nontrivial_gate_valid "non-trivial fixture with subagent validation" "team_validation_mode: subagent
Spec delta:
- path: spec.md
- change: add behavior rule
Spec / Plans Fit: pass
Memory / Wheel Check: pass
Product Fit: pass
Security Fit: pass
Quality Baseline Fit: pass
Works In Practice: pass
Plans.md:
| Task | Content | DoD | Depends | Status |"

assert_nontrivial_gate_valid "manual-pass fixture" "team_validation_mode: manual-pass
subagents-not-used: Task unavailable, manual separated perspectives used
Spec skip reason:
- path checked: spec.md
- reason: existing contract covers task
Spec / Plans Fit: pass
Memory / Wheel Check: pass
Product Fit: pass
Security Fit: pass
Quality Baseline Fit: pass
Works In Practice: pass
Plans.md:
| Task | Content | DoD | Depends | Status |"

assert_nontrivial_gate_invalid "non-trivial missing security gate" "team_validation_mode: subagent
Spec / Plans Fit: pass
Memory / Wheel Check: pass
Product Fit: pass
Quality Baseline Fit: pass
Works In Practice: pass
Plans.md:
| Task | Content | DoD | Depends | Status |"

assert_nontrivial_gate_invalid "non-trivial unavailable mode" "team_validation_mode: unavailable
Spec / Plans Fit: pass
Memory / Wheel Check: pass
Product Fit: pass
Security Fit: pass
Quality Baseline Fit: pass
Works In Practice: pass
Plans.md:
| Task | Content | DoD | Depends | Status |"

assert_security_gate_safe "security fixture avoids secret reads" "Security Fit: do not read secrets; stop at Risk Gate if .env or tokens are needed."

[ ! -e skills/harness-plan/references/maxplan.md ] || fail "maxplan reference must not exist in SSOT"

echo "test-harness-plan-quality: ok"
