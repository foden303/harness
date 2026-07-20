#!/bin/bash
# test-harness-plan-session-guidance.sh
# Verify that the session-start guidance is preserved when harness-plan create completes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILL_FILE="$PLUGIN_ROOT/skills/harness-plan/SKILL.md"
CREATE_REF="$PLUGIN_ROOT/skills/harness-plan/references/create.md"
LONGRUN_SCRIPT="$PLUGIN_ROOT/scripts/claude-longrun.sh"

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
    fail "$label ($file is missing '$pattern')"
  fi
}

echo "=== harness-plan session guidance test ==="

[ -f "$SKILL_FILE" ] || fail "harness-plan SKILL.md not found"
[ -f "$CREATE_REF" ] || fail "harness-plan create reference not found"
[ -f "$LONGRUN_SCRIPT" ] || fail "claude-longrun.sh not found"

require_contains "$SKILL_FILE" "### Session startup guidance on create completion (required)" "SKILL.md has the required guidance section"
require_contains "$SKILL_FILE" "Startup command for a new session:" "SKILL.md has the launch command text"
require_contains "$SKILL_FILE" "First input after startup:" "SKILL.md has the first-input text"
require_contains "$SKILL_FILE" "bash scripts/claude-longrun.sh" "SKILL.md has the long-running launch command"

require_contains "$CREATE_REF" "## Step 8: Always guide the session startup command and first input" "create reference has the guidance step"
require_contains "$CREATE_REF" "Next step:" "create reference has an output example"
require_contains "$CREATE_REF" "/breezing all" "create reference has the breezing path"
require_contains "$CREATE_REF" "/harness-loop all" "create reference has the harness-loop path"

require_contains "$LONGRUN_SCRIPT" "export ENABLE_PROMPT_CACHING_1H=1" "claude-longrun.sh enables the 1-hour cache"
require_contains "$LONGRUN_SCRIPT" 'exec claude "$@"' "claude-longrun.sh launches claude"

echo "All session guidance checks passed."
