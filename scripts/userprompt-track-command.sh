#!/bin/bash
# userprompt-track-command.sh
# On UserPromptSubmit, detect slash commands and record usage
# + create a pending entry for Skill-required commands
#
# Usage: auto-run from the UserPromptSubmit hook
# Input: stdin JSON (Claude Code hooks)
# Output: JSON (continue)

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR=".claude/state"
PENDING_DIR="${STATE_DIR}/pending-skills"
RECORD_USAGE="$SCRIPT_DIR/record-usage.js"

# list of Skill-required commands
# these commands are expected to use the Skill tool
SKILL_REQUIRED_COMMANDS="work|harness-review|validate|plan-with-agent"

# extract a value from JSON (prefer jq)
json_get() {
  local json="$1"
  local key="$2"
  local default="${3:-}"

  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r "$key // \"$default\"" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# read JSON input from stdin
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && { echo '{"continue":true}'; exit 0; }

# extract the prompt
PROMPT=$(json_get "$INPUT" ".prompt" "")

# skip empty prompts
[ -z "$PROMPT" ] && { echo '{"continue":true}'; exit 0; }

# detect slash commands (line starts with /xxx)
# for multi-line input, only check the first line
FIRST_LINE=$(echo "$PROMPT" | head -n1)

if [[ "$FIRST_LINE" =~ ^/([a-zA-Z0-9_:/-]+) ]]; then
  RAW_COMMAND="${BASH_REMATCH[1]}"

  # normalize the command name (strip the plugin prefix)
  # /harness:core:work → work
  # /harness/work → work
  # /work → work
  COMMAND_NAME="$RAW_COMMAND"
  # harness:xxx:yyy → yyy (last segment)
  if [[ "$COMMAND_NAME" =~ ^harness[:/] ]]; then
    COMMAND_NAME=$(echo "$COMMAND_NAME" | sed 's|.*[:/]||')
  fi

  # record command usage
  if [ -f "$RECORD_USAGE" ] && [ -n "$COMMAND_NAME" ]; then
    node "$RECORD_USAGE" command "$COMMAND_NAME" >/dev/null 2>&1 || true
  fi

  # check whether it is a Skill-required command
  if echo "$COMMAND_NAME" | grep -qiE "^($SKILL_REQUIRED_COMMANDS)$"; then
    # Permission hardening: prompt_preview contains user input,
    # restrict file permissions to owner-only (rwx------/rw-------)
    OLD_UMASK=$(umask)
    umask 077

    # create the pending directory (symlink bypass protection)
    if [ -L "$PENDING_DIR" ] || [ -L "$(dirname "$PENDING_DIR")" ]; then
      echo "[track-command] Warning: symlink detected in state path, skipping" >&2
      umask "$OLD_UMASK"
    else
    mkdir -p "$PENDING_DIR"

    # create the pending file (with timestamp)
    PENDING_FILE="${PENDING_DIR}/${COMMAND_NAME}.pending"
    # Security: refuse if pending file is a symlink
    if [ -L "$PENDING_FILE" ]; then
      echo "[track-command] Warning: symlink detected at $PENDING_FILE, skipping" >&2
      umask "$OLD_UMASK"
    else
    cat > "$PENDING_FILE" <<EOF
{
  "command": "$COMMAND_NAME",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prompt_preview": "$(echo "$PROMPT" | head -c 200 | tr '\n' ' ' | sed 's/"/\\"/g')"
}
EOF

    # Restore original umask
    umask "$OLD_UMASK"
    fi  # end symlink check for PENDING_FILE
    fi  # end symlink check for PENDING_DIR
  fi
fi

echo '{"continue":true}'
exit 0
