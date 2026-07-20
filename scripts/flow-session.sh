#!/usr/bin/env bash
# flow-session.sh — single-writer init/read/update/validate for flow-session.v1.
#
# The resumable state cursor for a harness-flow run. All mutations bump
# updated_at. Status transitions are validated against the schema enum.
#
# Usage:
#   flow-session.sh init --session-id ID --source jira|confluence --source-ref REF [--out FILE]
#   flow-session.sh get FILE [jq-path]
#   flow-session.sh status FILE NEW_STATUS
#   flow-session.sh set FILE KEY VALUE            # scalar string
#   flow-session.sh set-json FILE KEY JSON        # raw JSON value
#   flow-session.sh validate FILE
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/flow-session.v1.json"

VALID_STATUS=(ingesting ingested verifying triaging not-a-bug awaiting-ba planning working reviewing awaiting-confirm committing awaiting-push done escalated)

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

require_file() {
  local f="${1:-}"
  if [ -z "${f}" ] || [ ! -f "${f}" ]; then
    echo "flow-session: file not found: ${f:-<missing>}" >&2
    exit 1
  fi
}

# jq in-place update that always refreshes updated_at.
# Usage: jq_update FILE FILTER [extra jq args...]
# The FILTER must return the whole (modified) document.
jq_update() {
  local file="$1"; shift
  local filter="$1"; shift
  local tmp
  tmp="$(mktemp)"
  jq "$@" --arg _now "$(now_utc)" "(${filter}) | .updated_at = \$_now" "${file}" >"${tmp}"
  mv "${tmp}" "${file}"
}

cmd_init() {
  local session_id="" source="" source_ref="" out=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --session-id) session_id="${2:-}"; shift 2 ;;
      --source) source="${2:-}"; shift 2 ;;
      --source-ref) source_ref="${2:-}"; shift 2 ;;
      --out) out="${2:-}"; shift 2 ;;
      *) echo "flow-session init: unknown arg: $1" >&2; exit 1 ;;
    esac
  done
  [ -n "${session_id}" ] || { echo "init: --session-id required" >&2; exit 1; }
  case "${source}" in jira|confluence) ;; *) echo "init: --source must be jira|confluence" >&2; exit 1 ;; esac
  [ -n "${source_ref}" ] || { echo "init: --source-ref required" >&2; exit 1; }

  local project_root="${PROJECT_ROOT:-$(pwd)}"
  if [ -z "${out}" ]; then
    out="${project_root}/.claude/state/flow/${session_id}/session.json"
  fi
  mkdir -p "$(dirname "${out}")"

  local ts
  ts="$(now_utc)"
  jq -n \
    --arg sid "${session_id}" \
    --arg src "${source}" \
    --arg ref "${source_ref}" \
    --arg ts "${ts}" \
    '{
      schema_version: "flow-session.v1",
      session_id: $sid,
      status: "ingesting",
      source: $src,
      source_ref: $ref,
      created_at: $ts,
      updated_at: $ts
    }' >"${out}"
  echo "${out}"
}

cmd_get() {
  local file="${1:-}"
  require_file "${file}"
  local path="${2:-.}"
  jq -r "${path}" "${file}"
}

cmd_status() {
  local file="${1:-}" new="${2:-}"
  require_file "${file}"
  [ -n "${new}" ] || { echo "status: NEW_STATUS required" >&2; exit 1; }
  local ok=0
  for s in "${VALID_STATUS[@]}"; do [ "${s}" = "${new}" ] && ok=1; done
  if [ "${ok}" -ne 1 ]; then
    echo "status: invalid status '${new}' (allowed: ${VALID_STATUS[*]})" >&2
    exit 1
  fi
  jq_update "${file}" '.status = $s' --arg s "${new}"
}

cmd_set() {
  local file="${1:-}" key="${2:-}" value="${3:-}"
  require_file "${file}"
  [ -n "${key}" ] || { echo "set: KEY required" >&2; exit 1; }
  jq_update "${file}" 'setpath($k | split("."); $v)' --arg k "${key}" --arg v "${value}"
}

cmd_set_json() {
  local file="${1:-}" key="${2:-}" json="${3:-}"
  require_file "${file}"
  [ -n "${key}" ] || { echo "set-json: KEY required" >&2; exit 1; }
  jq_update "${file}" 'setpath($k | split("."); $v)' --arg k "${key}" --argjson v "${json}"
}

cmd_validate() {
  local file="${1:-}"
  require_file "${file}"
  [ -f "${SCHEMA}" ] || { echo "validate: schema not found: ${SCHEMA}" >&2; exit 1; }
  python3 - "${file}" "${SCHEMA}" <<'PY'
import json
import sys

state_path, schema_path = sys.argv[1], sys.argv[2]
with open(state_path, encoding="utf-8") as f:
    data = json.load(f)
with open(schema_path, encoding="utf-8") as f:
    schema = json.load(f)

try:
    import jsonschema  # type: ignore
except Exception:
    jsonschema = None

if jsonschema is not None:
    jsonschema.validate(instance=data, schema=schema)
else:
    if not isinstance(data, dict):
        raise SystemExit("root must be object")
    if data.get("schema_version") != "flow-session.v1":
        raise SystemExit("schema_version must be flow-session.v1")
    for key in ("session_id", "status", "source", "source_ref", "created_at", "updated_at"):
        if not data.get(key):
            raise SystemExit(f"missing required field: {key}")
    allowed_status = {
        "ingesting", "ingested", "verifying", "triaging", "not-a-bug",
        "awaiting-ba", "planning", "working", "reviewing", "awaiting-confirm",
        "committing", "awaiting-push", "done", "escalated",
    }
    if data["status"] not in allowed_status:
        raise SystemExit(f"invalid status: {data['status']}")
    if data["source"] not in {"jira", "confluence"}:
        raise SystemExit(f"invalid source: {data['source']}")
    # reject unknown top-level keys (additionalProperties:false)
    allowed_keys = {
        "schema_version", "session_id", "status", "source", "source_ref",
        "source_refs", "requirement_path", "clarification", "plans",
        "commit_hashes", "rework_rounds", "jira_transitioned", "done_comment_id",
        "mcp_health", "created_at", "updated_at",
    }
    extra = set(data) - allowed_keys
    if extra:
        raise SystemExit(f"unknown keys: {sorted(extra)}")
print("flow-session: valid")
PY
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    init) shift; cmd_init "$@" ;;
    get) shift; cmd_get "$@" ;;
    status) shift; cmd_status "$@" ;;
    set) shift; cmd_set "$@" ;;
    set-json) shift; cmd_set_json "$@" ;;
    validate) shift; cmd_validate "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "flow-session: unknown command: ${cmd}" >&2; usage; exit 1 ;;
  esac
}

main "$@"
