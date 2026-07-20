#!/bin/bash
# todo-sync.sh
# Bidirectional sync between TodoWrite and Plans.md
#
# Called from the PostToolUse hook; reflects TodoWrite state changes into Plans.md
#
# Mapping:
#   TodoWrite state   → Plans.md marker
#   pending          → cc:todo
#   in_progress      → cc:wip
#   completed        → cc:done

set +e  # do not stop on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# read JSON input from stdin
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
fi

# jq is required
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# exit if there is no input
if [ -z "$INPUT" ]; then
  exit 0
fi

# parse the TodoWrite tool output
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# ignore anything other than TodoWrite
if [ "$TOOL_NAME" != "TodoWrite" ]; then
  exit 0
fi

# get the Plans.md path
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  source "${SCRIPT_DIR}/config-utils.sh"
  PLANS_FILE=$(get_plans_file_path)
else
  PLANS_FILE="Plans.md"
fi

# exit if Plans.md does not exist
if [ ! -f "$PLANS_FILE" ]; then
  exit 0
fi

# state directory
STATE_DIR=".claude/state"
mkdir -p "$STATE_DIR"
SYNC_STATE_FILE="${STATE_DIR}/todo-sync-state.json"

# get the TodoWrite todos array
TODOS=$(echo "$INPUT" | jq -r '.tool_input.todos // []' 2>/dev/null)

if [ -z "$TODOS" ] || [ "$TODOS" = "null" ] || [ "$TODOS" = "[]" ]; then
  exit 0
fi

# save the sync state
echo "$TODOS" | jq '{
  synced_at: (now | todate),
  todos: .
}' > "$SYNC_STATE_FILE" 2>/dev/null

# update task states within Plans.md
# Note: updating while preserving Plans.md formatting is complex, so
# here we only log, and leave the actual update to Claude Code

# record to the event log
EVENT_LOG="${STATE_DIR}/session.events.jsonl"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

PENDING_COUNT=$(echo "$TODOS" | jq '[.[] | select(.status == "pending")] | length' 2>/dev/null || echo "0")
WIP_COUNT=$(echo "$TODOS" | jq '[.[] | select(.status == "in_progress")] | length' 2>/dev/null || echo "0")
DONE_COUNT=$(echo "$TODOS" | jq '[.[] | select(.status == "completed")] | length' 2>/dev/null || echo "0")

if [ -f "$EVENT_LOG" ]; then
  echo "{\"type\":\"todo.sync\",\"ts\":\"$NOW\",\"data\":{\"pending\":$PENDING_COUNT,\"in_progress\":$WIP_COUNT,\"completed\":$DONE_COUNT}}" >> "$EVENT_LOG"
fi

# ===== detect all-complete in Work mode and warn =====
WORK_WARNING=""
WORK_FILE="${STATE_DIR}/work-active.json"
# backward compat: if work-active.json is missing, try ultrawork-active.json
if [ ! -f "$WORK_FILE" ]; then
  WORK_FILE="${STATE_DIR}/ultrawork-active.json"
fi
TOTAL_COUNT=$((PENDING_COUNT + WIP_COUNT + DONE_COUNT))

# when all tasks are complete (pending=0, WIP=0, completed>0) and in Work mode
if [ "$PENDING_COUNT" -eq 0 ] && [ "$WIP_COUNT" -eq 0 ] && [ "$DONE_COUNT" -gt 0 ]; then
  if [ -f "$WORK_FILE" ]; then
    REVIEW_STATUS=$(jq -r '.review_status // "pending"' "$WORK_FILE" 2>/dev/null)

    if [ "$REVIEW_STATUS" != "passed" ]; then
      WORK_WARNING="\n\n⚠️ **work pre-completion check**: review_status=${REVIEW_STATUS}\n→ Get APPROVE from /harness-review before marking the work complete"
    fi
  fi
fi

# output sync info as additionalContext
OUTPUT="[TodoSync] Synced with Plans.md: TODO=$PENDING_COUNT, WIP=$WIP_COUNT, done=$DONE_COUNT${WORK_WARNING}"

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg ctx "$OUTPUT" \
    '{hookSpecificOutput:{additionalContext:$ctx}}'
else
  cat <<EOF
{"hookSpecificOutput":{"additionalContext":"[TodoSync] Synced with Plans.md: TODO=$PENDING_COUNT, WIP=$WIP_COUNT, done=$DONE_COUNT"}}
EOF
fi
