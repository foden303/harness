#!/bin/bash
# test-quality-guardrails.sh
# Verification test for the test-tampering prevention feature (3-layer defense strategy)
#
# Test targets:
# - Layer 1: existence and structure of the Rules templates
# - Layer 2: integration of Skills quality guardrails
# - Deployment configuration in harness-init

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test functions
assert_file_exists() {
  local file="$1"
  local description="$2"
  TOTAL=$((TOTAL + 1))

  if [ -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected file: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  TOTAL=$((TOTAL + 1))

  if [ ! -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${RED}✗${NC} $description (file not found)"
    FAILED=$((FAILED + 1))
    return 1
  fi

  if grep -qE "$pattern" "$PLUGIN_ROOT/$file"; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected pattern: $pattern"
    echo "  File: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

assert_json_key_exists() {
  local file="$1"
  local key="$2"
  local description="$3"
  TOTAL=$((TOTAL + 1))

  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} $description (jq not available, skipped)"
    return 0
  fi

  if [ ! -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${RED}✗${NC} $description (file not found)"
    FAILED=$((FAILED + 1))
    return 1
  fi

  if jq -e "$key" "$PLUGIN_ROOT/$file" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected key: $key"
    echo "  File: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

echo "=================================================="
echo "Test tampering prevention (3-layer defense strategy) verification"
echo "=================================================="
echo ""

# ============================================
# Layer 1: verify the Rules templates
# ============================================
echo "## Layer 1: Rules templates"
echo ""

# Existence of the test-quality rule template
assert_file_exists \
  "templates/rules/test-quality.md.template" \
  "test-quality.md.template exists"

# Existence of the implementation-quality rule template
assert_file_exists \
  "templates/rules/implementation-quality.md.template" \
  "implementation-quality.md.template exists"

# Required content of test-quality.md
assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "it.skip|test.skip" \
  "test-quality.md contains a skip-prohibition pattern"

assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "eslint|lint|disable" \
  "test-quality.md contains a lint-config tampering prohibition"

assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "_harness_template" \
  "test-quality.md contains frontmatter metadata"

# Required content of implementation-quality.md
assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "[Hh]ardcod" \
  "implementation-quality.md contains a hardcode prohibition"

assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "[Ss]tub" \
  "implementation-quality.md contains a stub prohibition"

assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "_harness_template" \
  "implementation-quality.md contains frontmatter metadata"

# Registration in template-registry.json
assert_json_key_exists \
  "templates/template-registry.json" \
  '.templates["rules/test-quality.md.template"]' \
  "test-quality.md is registered in template-registry.json"

assert_json_key_exists \
  "templates/template-registry.json" \
  '.templates["rules/implementation-quality.md.template"]' \
  "implementation-quality.md is registered in template-registry.json"

echo ""

# ============================================
# Layer 2: verify Skills quality guardrails
# ============================================
echo "## Layer 2: Skills quality guardrails"
echo ""

# Quality guardrails of the harness-work skill
assert_file_contains \
  "skills/harness-work/SKILL.md" \
  "critical / major" \
  "harness-work/SKILL.md has quality stop conditions"

assert_file_contains \
  "skills/harness-work/SKILL.md" \
  "skip" \
  "harness-work/SKILL.md defines a test-tampering prohibition"

assert_file_contains \
  "skills/harness-work/SKILL.md" \
  "DoD|Plans\\.md|sprint-contract" \
  "harness-work/SKILL.md has DoD / Plans-based implementation principles"

# Quality guardrails of the harness-review / ci skills
assert_file_contains \
  "skills/harness-review/SKILL.md" \
  "Security, Performance, Quality|AI Residuals" \
  "harness-review/SKILL.md has quality review perspectives"

assert_file_contains \
  "skills/harness-review/SKILL.md" \
  "it\\.skip|describe\\.skip|test\\.skip" \
  "harness-review/SKILL.md defines test-skip detection"

assert_file_contains \
  "skills/ci/SKILL.md" \
  "[Aa]pproval [Rr]equest" \
  "ci/SKILL.md has an approval-request format"

echo ""

# ============================================
# harness-init integration verification
# ============================================
echo "## harness-init integration"
echo ""

# Quality-rule deployment config in harness-init (after skill migration)
assert_file_contains \
  "skills/harness-setup/SKILL.md" \
  "harness-init|setup" \
  "harness-setup contains setup functionality equivalent to the old harness-init"

# Existence check for the quality-rule files
assert_file_contains \
  ".claude/rules/test-quality.md" \
  "[Tt]est [Tt]ampering" \
  "test-quality.md has test-tampering prevention rules"

assert_file_contains \
  ".claude/rules/implementation-quality.md" \
  "[Ss]tub|[Pp]laceholder" \
  "implementation-quality.md has rules prohibiting hollow implementations"

echo ""

# ============================================
# Documentation verification
# ============================================
echo "## Documentation"
echo ""

# Test-tampering prevention section in CLAUDE.md
assert_file_contains \
  "CLAUDE.md" \
  "Test Tampering Prevention" \
  "CLAUDE.md has a test-tampering prevention section"

# Quality-assurance related mention in README.md
assert_file_contains \
  "README.md" \
  "[Tt]est [Tt]ampering|[Qq]uality" \
  "README.md mentions quality assurance"

# Design document (historical record of quality-guard introduction)
# docs/update-summary-2025-12-23-24.md is a temporary summary doc from introduction time.
# It is now consolidated into CLAUDE.md / .claude/rules/test-quality.md /
# implementation-quality.md, so only assert when the file itself exists.
if [ -f "docs/update-summary-2025-12-23-24.md" ]; then
  assert_file_exists \
    "docs/update-summary-2025-12-23-24.md" \
    "quality-guard introduction document exists"
else
  echo "[skip] docs/update-summary-2025-12-23-24.md not found (statement consolidated into CLAUDE.md and .claude/rules/)"
fi

echo ""

# ============================================
# Result summary
# ============================================
echo "=================================================="
echo "Test results"
echo "=================================================="
echo ""
echo "Total: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAILED tests failed${NC}"
  exit 1
fi
