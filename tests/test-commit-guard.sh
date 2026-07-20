#!/bin/bash
# test-commit-guard.sh
# Test of the Commit Guard feature
#
# Test targets:
# - scripts/pretooluse-guard.sh (git commit blocking logic)
# - scripts/posttooluse-commit-cleanup.sh (clear review-approved state)
# - hooks.json (hook registration)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test result counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test function
run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "  Testing: $test_name... "

  if $test_func; then
    echo -e "${GREEN}PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ==================================================
# Test 1: whether posttooluse-commit-cleanup.sh exists
# ==================================================
test_cleanup_script_exists() {
  local script="$PROJECT_ROOT/scripts/posttooluse-commit-cleanup.sh"

  if [ ! -f "$script" ]; then
    echo "    Error: posttooluse-commit-cleanup.sh not found"
    return 1
  fi

  return 0
}

# ==================================================
# Test 2: whether the script has execute permission
# ==================================================
test_cleanup_script_executable() {
  local script="$PROJECT_ROOT/scripts/posttooluse-commit-cleanup.sh"

  if [ ! -x "$script" ]; then
    echo "    Error: posttooluse-commit-cleanup.sh is not executable"
    return 1
  fi

  return 0
}

# ==================================================
# Test 3: whether pretooluse-guard.sh has git commit detection logic
# ==================================================
test_pretooluse_has_commit_guard() {
  local script="$PROJECT_ROOT/scripts/pretooluse-guard.sh"

  if ! grep -q "git[[:space:]]*commit" "$script" 2>/dev/null; then
    echo "    Error: git commit detection not found in pretooluse-guard.sh"
    return 1
  fi

  if ! grep -Eq "review-approved.json|review-result.json" "$script" 2>/dev/null; then
    echo "    Error: review artifact check not found in pretooluse-guard.sh"
    return 1
  fi

  return 0
}

# ==================================================
# Test 4: whether pretooluse-guard.sh has a block message
# ==================================================
test_pretooluse_has_block_message() {
  local script="$PROJECT_ROOT/scripts/pretooluse-guard.sh"

  if ! grep -q "deny_git_commit_no_review" "$script" 2>/dev/null; then
    echo "    Error: deny_git_commit_no_review message not found"
    return 1
  fi

  return 0
}

test_pretooluse_has_bookkeeping_exemption_hardening() {
  local script="$PROJECT_ROOT/scripts/pretooluse-guard.sh"

  grep -q "BOOKKEEPING_ONLY" "$script" 2>/dev/null || {
    echo "    Error: bookkeeping exemption state not found"
    return 1
  }
  grep -q "commit-cleanup-audit.jsonl" "$script" 2>/dev/null || {
    echo "    Error: bookkeeping audit append not found"
    return 1
  }
  grep -Eq 'git\[\[:space:\]\]\+\(add\|restore\|reset\|rm\)|git\[.*\(add\|restore\|reset\|rm\)' "$script" 2>/dev/null || {
    echo "    Error: index-mutating command hardening not found"
    return 1
  }
  grep -Eq -- '--patch|--interactive|\-\*p\*|PATHSPEC_SUSPECT' "$script" 2>/dev/null || {
    echo "    Error: pathspec/patch hardening not found"
    return 1
  }

  return 0
}

# ==================================================
# Test 5: whether posttooluse-commit-cleanup.sh has git commit detection
# ==================================================
test_cleanup_detects_git_commit() {
  local script="$PROJECT_ROOT/scripts/posttooluse-commit-cleanup.sh"

  if ! grep -q "git[[:space:]]*commit" "$script" 2>/dev/null; then
    echo "    Error: git commit detection not found in cleanup script"
    return 1
  fi

  return 0
}

# ==================================================
# Test 6: whether posttooluse-commit-cleanup.sh has state-file removal logic
# ==================================================
test_cleanup_removes_state_file() {
  local script="$PROJECT_ROOT/scripts/posttooluse-commit-cleanup.sh"

  # The script deletes via a variable: rm -f "$REVIEW_STATE_FILE"
  if ! grep -q 'rm -f.*REVIEW_STATE_FILE' "$script" 2>/dev/null; then
    echo "    Error: state file removal logic not found"
    return 1
  fi

  # Also confirm the state-file path definition
  if ! grep -Eq "review-approved.json|review-result.json" "$script" 2>/dev/null; then
    echo "    Error: review artifact path definition not found"
    return 1
  fi

  return 0
}

# ==================================================
# Test 7: whether the commit-cleanup hook is registered in hooks.json
# ==================================================
test_hooks_has_commit_cleanup() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"

  if ! command -v jq &> /dev/null; then
    echo "    Warning: jq not available, skipping JSON validation"
    # Confirm with grep even without jq
    if ! grep -Eq "posttooluse-commit-cleanup|hook commit-cleanup" "$hooks_file" 2>/dev/null; then
      echo "    Error: commit-cleanup hook not registered in hooks.json"
      return 1
    fi
    return 0
  fi

  # Whether commit-cleanup is registered under PostToolUse with a Bash matcher
  if ! jq -e '.hooks.PostToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("posttooluse-commit-cleanup") or contains("hook commit-cleanup"))' "$hooks_file" > /dev/null 2>&1; then
    echo "    Error: commit-cleanup hook not properly registered for Bash in PostToolUse"
    return 1
  fi

  return 0
}

# ==================================================
# Test 8: whether .claude-plugin/hooks.json also has the same hook
# ==================================================
test_plugin_hooks_has_commit_cleanup() {
  local hooks_file="$PROJECT_ROOT/.claude-plugin/hooks.json"

  if ! grep -Eq "posttooluse-commit-cleanup|hook commit-cleanup" "$hooks_file" 2>/dev/null; then
    echo "    Error: commit-cleanup hook not registered in .claude-plugin/hooks.json"
    return 1
  fi

  return 0
}

# ==================================================
# Test 9: whether the config template has a commit_guard setting
# ==================================================
test_config_has_commit_guard_option() {
  local config_template="$PROJECT_ROOT/templates/.harness.config.yaml.template"

  if ! grep -q "commit_guard:" "$config_template" 2>/dev/null; then
    echo "    Error: commit_guard option not found in config template"
    return 1
  fi

  return 0
}

# ==================================================
# Test 10: whether posttooluse-commit-cleanup.sh preserves state on error
# ==================================================
test_cleanup_preserves_on_error() {
  local script="$PROJECT_ROOT/scripts/posttooluse-commit-cleanup.sh"

  # Confirm error-pattern detection logic exists
  if ! grep -Eq "error|fatal|failed|nothing to commit" "$script" 2>/dev/null; then
    echo "    Error: error detection logic not found in cleanup script"
    return 1
  fi

  return 0
}

# ==================================================
# Main execution
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Commit Guard tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "  [PreToolUse Guard]"
run_test "pretooluse-guard.sh has git commit detection logic" test_pretooluse_has_commit_guard
run_test "pretooluse-guard.sh has a block message" test_pretooluse_has_block_message
run_test "bookkeeping exemption and hardening present" test_pretooluse_has_bookkeeping_exemption_hardening

echo ""
echo "  [PostToolUse Cleanup]"
run_test "posttooluse-commit-cleanup.sh exists" test_cleanup_script_exists
run_test "posttooluse-commit-cleanup.sh is executable" test_cleanup_script_executable
run_test "posttooluse-commit-cleanup.sh has git commit detection" test_cleanup_detects_git_commit
run_test "posttooluse-commit-cleanup.sh has state file removal logic" test_cleanup_removes_state_file
run_test "posttooluse-commit-cleanup.sh preserves state on error" test_cleanup_preserves_on_error

echo ""
echo "  [Hooks Integration]"
run_test "commit-cleanup hook registered in hooks.json" test_hooks_has_commit_cleanup
run_test ".claude-plugin/hooks.json also has commit-cleanup hook" test_plugin_hooks_has_commit_cleanup

echo ""
echo "  [Configuration]"
run_test "config template has commit_guard setting" test_config_has_commit_guard_option

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test result: $TESTS_PASSED/$TESTS_RUN passed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi

exit 0
