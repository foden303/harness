#!/bin/bash
# validate-plugin-v3.sh
# Harness v4 plugin structure validator
#
# Usage: ./tests/validate-plugin-v3.sh
# Exit codes:
#   0 - All checks passed
#   1 - Failures found

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Claude Harness v4 — plugin validation test"
echo "=========================================="
echo ""

# Colored output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass_test() { echo -e "${GREEN}✓${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail_test() { echo -e "${RED}✗${NC} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn_test() { echo -e "${YELLOW}⚠${NC} $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

# ============================================================
# [1] v4 Go core structure check
# ============================================================
echo "📁 [1/7] v4 Go core structure check..."

V4_REQUIRED_FILES=(
  "go/go.mod"
  "go/cmd/harness/main.go"
  "go/cmd/harness/doctor.go"
  "go/cmd/harness/sync.go"
  "go/cmd/harness/validate.go"
  "go/internal/policy/rules.go"
  "go/internal/guardrail/pre_tool.go"
  "go/internal/policy/post_tool.go"
  "go/internal/policy/permission.go"
  "go/internal/policy/tampering.go"
  "go/internal/hookhandler/setup_hook.go"
  "go/internal/hookhandler/stop_session_evaluator.go"
)

for f in "${V4_REQUIRED_FILES[@]}"; do
  if [ -f "$PLUGIN_ROOT/$f" ]; then
    pass_test "$f"
  else
    fail_test "$f (missing)"
  fi
done

# ============================================================
# [2] 5-verb skill check
# ============================================================
echo ""
echo "🎯 [2/7] 5-verb skill check..."

V3_SKILLS=(harness-plan harness-work harness-review harness-release harness-setup)
AUX_V3_SKILLS=(harness-sync)

for skill in "${V3_SKILLS[@]}"; do
  skill_dir="$PLUGIN_ROOT/skills/$skill"
  skill_md="$skill_dir/SKILL.md"

  if [ ! -d "$skill_dir" ]; then
    fail_test "skills/$skill/ (directory missing)"
    continue
  fi

  if [ ! -f "$skill_md" ]; then
    fail_test "skills/$skill/SKILL.md (missing)"
    continue
  fi

  # check frontmatter name:
  if grep -q "^name: $skill$" "$skill_md"; then
    pass_test "skills/$skill/SKILL.md (name: $skill)"
  else
    fail_test "skills/$skill/SKILL.md (name: field is not '$skill')"
  fi
done

echo ""
echo "🧭 [2.5/7] auxiliary workflow surface check..."

for skill in "${AUX_V3_SKILLS[@]}"; do
  skill_dir="$PLUGIN_ROOT/skills/$skill"
  skill_md="$skill_dir/SKILL.md"

  if [ ! -d "$skill_dir" ]; then
    fail_test "skills/$skill/ (directory missing)"
    continue
  fi

  if [ ! -f "$skill_md" ]; then
    fail_test "skills/$skill/SKILL.md (missing)"
    continue
  fi

  if grep -q "^name: $skill$" "$skill_md"; then
    pass_test "skills/$skill/SKILL.md (name: $skill)"
  else
    fail_test "skills/$skill/SKILL.md (name: field is not '$skill')"
  fi
done

# ============================================================
# [3] Public mirror bundle check
# ============================================================
echo ""
echo "📦 [3/7] Public mirror bundle check..."

if bash "$PLUGIN_ROOT/scripts/sync-skill-mirrors.sh" --check >/dev/null 2>&1; then
  pass_test "sync-skill-mirrors.sh --check"
else
  fail_test "sync-skill-mirrors.sh --check"
fi

# ============================================================
# [4] Agent check
# ============================================================
echo ""
echo "🤖 [4/7] agent check..."

V3_AGENTS=(worker reviewer advisor)

for agent in "${V3_AGENTS[@]}"; do
  agent_file="$PLUGIN_ROOT/agents/$agent.md"
  if [ -f "$agent_file" ]; then
    # check name: field
    if grep -q "^name: $agent$" "$agent_file"; then
      pass_test "agents/$agent.md (name: $agent)"
    else
      fail_test "agents/$agent.md (name: field is not '$agent')"
    fi
  else
    fail_test "agents/$agent.md (missing)"
  fi
done

# team-composition.md
if [ -f "$PLUGIN_ROOT/docs/team-composition.md" ]; then
  pass_test "docs/team-composition.md"
else
  warn_test "docs/team-composition.md (missing)"
fi

# ============================================================
# [5] Go build / guardrail test
# ============================================================
echo ""
echo "🔷 [5/7] Go build / guardrail test..."

GO_DIR="$PLUGIN_ROOT/go"

if [ ! -d "$GO_DIR" ]; then
  fail_test "go/ (missing)"
else
  if (cd "$GO_DIR" && go build ./cmd/harness >/dev/null 2>&1); then
    pass_test "go build ./cmd/harness"
  else
    fail_test "go build ./cmd/harness"
  fi

  if (cd "$GO_DIR" && go test ./internal/guardrail >/dev/null 2>&1); then
    pass_test "go test ./internal/guardrail"
  else
    fail_test "go test ./internal/guardrail"
  fi
fi

# ============================================================
# [6] hooks / runtime check
# ============================================================
echo ""
echo "🪝 [6/7] hooks / runtime check..."

HOOK_FILES=(
  "hooks/hooks.json"
  "bin/harness"
)

for f in "${HOOK_FILES[@]}"; do
  if [ -f "$PLUGIN_ROOT/$f" ]; then
    pass_test "$f"
  else
    fail_test "$f (missing)"
  fi
done

for f in \
  "scripts/lib/harness-mem-bridge.sh" \
  "scripts/hook-handlers/memory-bridge.sh" \
  "scripts/hook-handlers/memory-session-start.sh" \
  "scripts/hook-handlers/memory-user-prompt.sh" \
  "scripts/hook-handlers/memory-post-tool-use.sh" \
  "scripts/hook-handlers/memory-stop.sh"
do
  if [ -f "$PLUGIN_ROOT/$f" ]; then
    pass_test "$f"
  else
    fail_test "$f (missing)"
  fi
done

# ============================================================
# [7] Hardening parity check
# ============================================================
echo ""
echo "🛡️ [7/7] Hardening parity check..."

if [ -f "$PLUGIN_ROOT/docs/hardening-parity.md" ]; then
  pass_test "docs/hardening-parity.md"
else
  fail_test "docs/hardening-parity.md (missing)"
fi

if grep -q 'docs/hardening-parity.md' "$PLUGIN_ROOT/README.md"; then
  pass_test "README.md → hardening parity link"
else
  fail_test "README.md has no hardening parity link"
fi

for rule_id in \
  "R10:no-git-bypass-flags" \
  "R11:no-reset-hard-protected-branch" \
  "R12:confirm-direct-push-protected-branch" \
  "R13:warn-protected-review-paths"
do
  if grep -q "$rule_id" "$PLUGIN_ROOT/go/internal/policy/rules.go"; then
    pass_test "go/internal/policy/rules.go ($rule_id)"
  else
    fail_test "go/internal/policy/rules.go ($rule_id missing)"
  fi
done

# ============================================================
# Summary
# ============================================================
echo ""
echo "=========================================="
echo "Result summary"
echo "=========================================="
echo -e "${GREEN}✓ Passed${NC}: $PASS_COUNT"
echo -e "${RED}✗ Failed${NC}: $FAIL_COUNT"
echo -e "${YELLOW}⚠ Warnings${NC}: $WARN_COUNT"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}❌ Validation failed: $FAIL_COUNT error(s) found${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Validation passed${NC}"
  exit 0
fi
