#!/usr/bin/env bash
# flow-ingest-bug.sh — validate and write a bug-report.v1 record.
#
# harness-bugfix fetches the JIRA bug issue via MCP, extracts fields in-context,
# then calls this helper to persist a schema-valid record. Long text is passed
# via files; steps-to-reproduce = one step per non-empty line.
#
# Usage:
#   flow-ingest-bug.sh \
#     --source jira|confluence --source-ref REF --title TITLE \
#     [--description-file FILE] [--steps-file FILE] \
#     [--expected-file FILE] [--actual-file FILE] \
#     [--environment ENV] [--labels a,b] [--status STATUS] \
#     [--reporter-account-id ID] [--mcp-available true|false] \
#     --out FILE
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/bug-report.v1.json"

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

source="" source_ref="" title="" desc_file="" steps_file=""
expected_file="" actual_file="" environment="" labels="" status="" reporter="" mcp_available="true" out=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) source="${2:-}"; shift 2 ;;
    --source-ref) source_ref="${2:-}"; shift 2 ;;
    --title) title="${2:-}"; shift 2 ;;
    --description-file) desc_file="${2:-}"; shift 2 ;;
    --steps-file) steps_file="${2:-}"; shift 2 ;;
    --expected-file) expected_file="${2:-}"; shift 2 ;;
    --actual-file) actual_file="${2:-}"; shift 2 ;;
    --environment) environment="${2:-}"; shift 2 ;;
    --labels) labels="${2:-}"; shift 2 ;;
    --status) status="${2:-}"; shift 2 ;;
    --reporter-account-id) reporter="${2:-}"; shift 2 ;;
    --mcp-available) mcp_available="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    *) echo "flow-ingest-bug: unknown arg: $1" >&2; exit 1 ;;
  esac
done

case "${source}" in jira|confluence) ;; *) echo "ingest-bug: --source must be jira|confluence" >&2; exit 1 ;; esac
[ -n "${source_ref}" ] || { echo "ingest-bug: --source-ref required" >&2; exit 1; }
[ -n "${title}" ] || { echo "ingest-bug: --title required" >&2; exit 1; }
[ -n "${out}" ] || { echo "ingest-bug: --out required" >&2; exit 1; }
case "${mcp_available}" in true|false) ;; *) echo "ingest-bug: --mcp-available must be true|false" >&2; exit 1 ;; esac

read_file_or_empty() {
  local f="${1:-}"
  if [ -n "${f}" ]; then
    [ -f "${f}" ] || { echo "ingest-bug: file not found: ${f}" >&2; exit 1; }
    cat "${f}"
  fi
}

description="$(read_file_or_empty "${desc_file}")"
expected="$(read_file_or_empty "${expected_file}")"
actual="$(read_file_or_empty "${actual_file}")"

if [ -n "${steps_file}" ]; then
  [ -f "${steps_file}" ] || { echo "ingest-bug: steps file not found: ${steps_file}" >&2; exit 1; }
  steps_json="$(jq -R -s 'split("\n") | map(select(length > 0))' <"${steps_file}")"
else
  steps_json="[]"
fi

if [ -n "${labels}" ]; then
  labels_json="$(printf '%s' "${labels}" | jq -R 'split(",") | map(select(length > 0))')"
else
  labels_json="[]"
fi

mkdir -p "$(dirname "${out}")"

jq -n \
  --arg source "${source}" \
  --arg ref "${source_ref}" \
  --arg title "${title}" \
  --arg description "${description}" \
  --argjson steps "${steps_json}" \
  --arg expected "${expected}" \
  --arg actual "${actual}" \
  --arg environment "${environment}" \
  --argjson labels "${labels_json}" \
  --arg status "${status}" \
  --arg reporter "${reporter}" \
  --argjson mcp_available "${mcp_available}" \
  --arg ingested_at "$(now_utc)" \
  '{
    schema_version: "bug-report.v1",
    source: $source,
    source_ref: $ref,
    title: $title,
    description: $description,
    steps_to_reproduce: $steps,
    labels: $labels,
    ingested_at: $ingested_at,
    mcp_available: $mcp_available
  }
  + (if $expected != "" then {expected_behavior: $expected} else {} end)
  + (if $actual != "" then {actual_behavior: $actual} else {} end)
  + (if $environment != "" then {environment: $environment} else {} end)
  + (if $status != "" then {status: $status} else {} end)
  + (if $reporter != "" then {reporter_account_id: $reporter} else {} end)' \
  >"${out}"

python3 - "${out}" "${SCHEMA}" <<'PY'
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
    if data.get("schema_version") != "bug-report.v1":
        raise SystemExit("schema_version must be bug-report.v1")
    for key in ("source", "source_ref", "title", "ingested_at"):
        if key not in data:
            raise SystemExit(f"missing required field: {key}")
    if data["source"] not in {"jira", "confluence"}:
        raise SystemExit(f"invalid source: {data['source']}")
PY

echo "${out}"
