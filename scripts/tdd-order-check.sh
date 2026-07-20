#!/bin/bash
# tdd-order-check.sh
# TDD is enabled by default. Emit a warning recommending test-first (does not block)
#
# Purpose: run after Write|Edit in PostToolUse
# Behavior:
#   - when Plans.md has a cc:WIP task (TDD enabled by default)
#   - but skip WIP tasks that carry a [skip:tdd] marker
#   - a source file (*.ts, *.tsx, *.js, *.jsx) was edited
#   - the corresponding test file (*.test.*, *.spec.*) has not been edited yet
#   → emit a warning message (does not block)

set -euo pipefail

# get information about the edited file
TOOL_INPUT="${TOOL_INPUT:-}"
FILE_PATH=""

# extract file_path from TOOL_INPUT (works on both macOS/Linux)
if [[ -n "$TOOL_INPUT" ]]; then
    # use jq when available (safest)
    if command -v jq &>/dev/null; then
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null || true)
    else
        # fallback: extract with sed (POSIX compatible)
        FILE_PATH=$(echo "$TOOL_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null || true)
    fi
fi

# exit if there is no file path
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# check whether it is a test file
is_test_file() {
    local file="$1"
    [[ "$file" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || \
    [[ "$file" =~ __tests__/ ]] || \
    [[ "$file" =~ /tests?/ ]]
}

# check whether it is a source file (excluding test files)
is_source_file() {
    local file="$1"
    [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]] && ! is_test_file "$file"
}

# check whether there is an active WIP task
has_active_wip_task() {
    if [[ -f "Plans.md" ]]; then
        grep -q 'cc:WIP' Plans.md 2>/dev/null
        return $?
    fi
    return 1
}

# check whether the WIP task has a [skip:tdd] marker
is_tdd_skipped() {
    if [[ -f "Plans.md" ]]; then
        grep -q '\[skip:tdd\].*cc:WIP\|cc:WIP.*\[skip:tdd\]' Plans.md 2>/dev/null
        return $?
    fi
    return 1
}

# check whether a test file was edited during the session (simplified)
test_edited_this_session() {
    # check .claude/state/session-changes.json if it exists
    local state_file=".claude/state/session-changes.json"
    if [[ -f "$state_file" ]]; then
        grep -q '\.test\.\|\.spec\.\|__tests__' "$state_file" 2>/dev/null
        return $?
    fi
    return 1
}

# main processing
main() {
    # skip if it is not a source file
    if ! is_source_file "$FILE_PATH"; then
        exit 0
    fi

    # skip if it is a test file
    if is_test_file "$FILE_PATH"; then
        exit 0
    fi

    # skip if there is no WIP task
    if ! has_active_wip_task; then
        exit 0
    fi

    # skip if there is a [skip:tdd] marker
    if is_tdd_skipped; then
        exit 0
    fi

    # skip if a test file has already been edited
    if test_edited_this_session; then
        exit 0
    fi

    # emit a warning (does not block)
    cat << 'EOF'
{
  "decision": "approve",
  "reason": "TDD reminder",
  "systemMessage": "💡 TDD is enabled by default. Writing tests first is recommended.\n\nYou just edited a source file, but its corresponding test file has not been edited yet.\n\nRecommended: create the test file (*.test.ts, *.spec.ts) first, then implement the source.\n\nTo skip, add a [skip:tdd] marker to the relevant task in Plans.md.\n\nThis is a warning and does not block."
}
EOF
}

main
