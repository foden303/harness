#!/usr/bin/env bash
# flow-ingest-requirement.sh — validate and write a requirement.v1 record.
#
# The skill fetches the JIRA issue / Confluence page via MCP, extracts the
# fields in-context, then calls this helper to persist a schema-valid record.
# Long text (description, acceptance criteria) is passed via files to avoid
# shell-quoting hazards; criteria file = one criterion per non-empty line.
#
# For a merged multi-ticket feature, pass --sources-file with a JSON array of
# {source, source_ref, title?} objects; --source/--source-ref stay the primary
# (first) ticket, and the skill supplies the already-merged title/description/
# acceptance-criteria.
#
# Usage:
#   flow-ingest-requirement.sh \
#     --source jira|confluence --source-ref REF \
#     --title TITLE \
#     [--description-file FILE] [--acceptance-criteria-file FILE] \
#     [--labels a,b,c] [--issue-type TYPE] [--status STATUS] \
#     [--reporter-account-id ID] [--mcp-available true|false] \
#     [--sources-file FILE] \
#     --out FILE
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/requirement.v1.json"

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

source="" source_ref="" title="" desc_file="" ac_file=""
labels="" issue_type="" status="" reporter="" mcp_available="true" out="" sources_file=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) source="${2:-}"; shift 2 ;;
    --source-ref) source_ref="${2:-}"; shift 2 ;;
    --title) title="${2:-}"; shift 2 ;;
    --description-file) desc_file="${2:-}"; shift 2 ;;
    --acceptance-criteria-file) ac_file="${2:-}"; shift 2 ;;
    --labels) labels="${2:-}"; shift 2 ;;
    --issue-type) issue_type="${2:-}"; shift 2 ;;
    --status) status="${2:-}"; shift 2 ;;
    --reporter-account-id) reporter="${2:-}"; shift 2 ;;
    --mcp-available) mcp_available="${2:-}"; shift 2 ;;
    --sources-file) sources_file="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    *) echo "flow-ingest: unknown arg: $1" >&2; exit 1 ;;
  esac
done

case "${source}" in jira|confluence) ;; *) echo "ingest: --source must be jira|confluence" >&2; exit 1 ;; esac
[ -n "${source_ref}" ] || { echo "ingest: --source-ref required" >&2; exit 1; }
[ -n "${title}" ] || { echo "ingest: --title required" >&2; exit 1; }
[ -n "${out}" ] || { echo "ingest: --out required" >&2; exit 1; }
case "${mcp_available}" in true|false) ;; *) echo "ingest: --mcp-available must be true|false" >&2; exit 1 ;; esac

description=""
if [ -n "${desc_file}" ]; then
  [ -f "${desc_file}" ] || { echo "ingest: description file not found: ${desc_file}" >&2; exit 1; }
  description="$(cat "${desc_file}")"
fi

# Build acceptance_criteria JSON array from non-empty lines.
if [ -n "${ac_file}" ]; then
  [ -f "${ac_file}" ] || { echo "ingest: acceptance-criteria file not found: ${ac_file}" >&2; exit 1; }
  ac_json="$(jq -R -s 'split("\n") | map(select(length > 0))' <"${ac_file}")"
else
  ac_json="[]"
fi

# Build labels JSON array from comma-separated input.
if [ -n "${labels}" ]; then
  labels_json="$(printf '%s' "${labels}" | jq -R 'split(",") | map(select(length > 0))')"
else
  labels_json="[]"
fi

# Optional merged-feature sources array (validated shape).
sources_json=""
if [ -n "${sources_file}" ]; then
  [ -f "${sources_file}" ] || { echo "ingest: sources file not found: ${sources_file}" >&2; exit 1; }
  if ! sources_json="$(jq -e '
        if type != "array" or length == 0 then error("sources must be a non-empty array")
        else map(
          if (.source|type) != "string" or (.source_ref|type) != "string"
          then error("each source needs string source + source_ref") else . end)
        end' "${sources_file}")"; then
    echo "ingest: invalid --sources-file content" >&2; exit 1
  fi
fi

mkdir -p "$(dirname "${out}")"

jq -n \
  --arg source "${source}" \
  --arg ref "${source_ref}" \
  --arg title "${title}" \
  --arg description "${description}" \
  --argjson acceptance_criteria "${ac_json}" \
  --argjson labels "${labels_json}" \
  --arg issue_type "${issue_type}" \
  --arg status "${status}" \
  --arg reporter "${reporter}" \
  --argjson mcp_available "${mcp_available}" \
  --argjson sources "${sources_json:-null}" \
  --arg ingested_at "$(now_utc)" \
  '{
    schema_version: "requirement.v1",
    source: $source,
    source_ref: $ref,
    title: $title,
    description: $description,
    acceptance_criteria: $acceptance_criteria,
    labels: $labels,
    ingested_at: $ingested_at,
    mcp_available: $mcp_available
  }
  + (if $issue_type != "" then {issue_type: $issue_type} else {} end)
  + (if $status != "" then {status: $status} else {} end)
  + (if $reporter != "" then {reporter_account_id: $reporter} else {} end)
  + (if $sources != null then {sources: $sources} else {} end)' \
  >"${out}"

# Validate against schema (jsonschema if available, else minimal checks).
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
    if data.get("schema_version") != "requirement.v1":
        raise SystemExit("schema_version must be requirement.v1")
    for key in ("source", "source_ref", "title", "acceptance_criteria", "ingested_at"):
        if key not in data:
            raise SystemExit(f"missing required field: {key}")
    if data["source"] not in {"jira", "confluence"}:
        raise SystemExit(f"invalid source: {data['source']}")
PY

echo "${out}"
