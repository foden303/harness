#!/bin/bash
# scripts/accept-past-issues.sh
# Phase 65.2.2 - Acceptance Demo "past problem patterns" retrieval (read side)
#
# Usage:
#   accept-past-issues.sh --project <name> --task <description>
#                         [--issues-source <path>] [--out -|<path>]
#
# Role:
#   Takes as input the results of the harness-accept skill running
#   semantic search over patterns.md (P1-P33) and past `acceptance-context.v1`
#   records via `mcp__harness__harness_mem_search`, formats the top 3,
#   and outputs them in the `past-issue.v1` schema.
#
# Input schema (JSON file pointed to by --issues-source):
#   {
#     "items": [
#       {
#         "source": "patterns.md|acceptance-record",
#         "pattern_id": "P5" or "AR-2026-05-08",
#         "title": "string",
#         "summary": "string",
#         "relevance_score": 0.85,
#         "verified_in_current_task": true|false
#       },
#       ...
#     ]
#   }
#   When --issues-source is omitted, treated as items=[] (no-match case).
#
# Project enforcement (DoD b):
#   --project is required. Empty string / unspecified exits 2.
#   Cross-project search is **not called** in this script (unlocked in Phase 65.3).
#   Assumes the skill calls `mcp__harness__harness_mem_search` with
#   `strict_project: true`.
#
# Output schema: past-issue.v1
#   {
#     "schema": "past-issue.v1",
#     "items": [
#       {
#         "source": "...", "pattern_id": "...", "title": "...",
#         "summary": "...", "relevance_score": 0.85,
#         "verified_in_current_task": true
#       }
#     ],
#     "project": "...", "task_description": "...",
#     "generated_at": "ISO8601"
#   }
#
# Exit code: 0=success, 2=usage error, 3=runtime error

set -euo pipefail

usage() {
  cat <<USAGE >&2
Usage: $0 --project <name> --task <description>
          [--issues-source <path>] [--out -|<path>]

Required:
  --project <name>            project name (basename of toplevel)
  --task <description>        current task description (semantic search query)

Optional:
  --issues-source <path>      JSON file holding the mem search results
                              (omitted: items=[], i.e. no past issues)
  --out -|<path>              output destination (- = stdout, default: stdout)

Output: JSON conforming to the past-issue.v1 schema
USAGE
  exit 2
}

PROJECT=""
TASK=""
ISSUES_SOURCE=""
OUT="-"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)        PROJECT="${2:-}";        shift 2 ;;
    --task)           TASK="${2:-}";           shift 2 ;;
    --issues-source)  ISSUES_SOURCE="${2:-}";  shift 2 ;;
    --out)            OUT="${2:-}";            shift 2 ;;
    -h|--help)        usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

# ---- DoD b: project enforcement ----
if [[ -z "$PROJECT" ]]; then
  echo "ERROR: --project is required (cross-project search is forbidden in Phase 65.2)" >&2
  usage
fi

if [[ -z "$TASK" ]]; then
  echo "ERROR: --task is required" >&2
  usage
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not found" >&2
  exit 3
fi

# ---- Normalize input source ----
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/accept-past-issues.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
NORM_SRC="$TMP_DIR/source.json"

if [[ -n "$ISSUES_SOURCE" ]]; then
  if [[ ! -f "$ISSUES_SOURCE" ]]; then
    echo "ERROR: --issues-source file not found: $ISSUES_SOURCE" >&2
    exit 3
  fi
  if ! jq -e '.' "$ISSUES_SOURCE" >/dev/null 2>&1; then
    echo "ERROR: --issues-source is not valid JSON: $ISSUES_SOURCE" >&2
    exit 3
  fi
  jq '{ items: (.items // []) }' "$ISSUES_SOURCE" > "$NORM_SRC"
else
  echo '{"items":[]}' > "$NORM_SRC"
fi

# ---- Extract top 3 by descending relevance_score + fill defaults ----
# If verified_in_current_task is missing, default to false.
# If relevance_score is missing, default to 0.

TOP_ITEMS_JSON="$(jq '
  [.items[] | {
    source:                   (.source // ""),
    pattern_id:               (.pattern_id // ""),
    title:                    (.title // ""),
    summary:                  (.summary // ""),
    relevance_score:          (.relevance_score // 0),
    verified_in_current_task: (if has("verified_in_current_task") then .verified_in_current_task else false end)
  }]
  | sort_by(-.relevance_score)
  | .[0:3]
' "$NORM_SRC")"

# ---- Assemble output JSON ----
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

OUT_JSON="$(jq -n \
  --arg proj "$PROJECT" \
  --arg task "$TASK" \
  --arg ts "$GENERATED_AT" \
  --argjson items "$TOP_ITEMS_JSON" \
  '{
    schema: "past-issue.v1",
    project: $proj,
    task_description: $task,
    items: $items,
    generated_at: $ts
  }')"

if [[ "$OUT" == "-" || -z "$OUT" ]]; then
  printf '%s\n' "$OUT_JSON"
else
  printf '%s\n' "$OUT_JSON" > "$OUT"
fi
