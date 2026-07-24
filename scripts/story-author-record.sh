#!/usr/bin/env bash
# story-author-record.sh — validate and persist a story-draft.v1 record.
#
# harness-story-author drafts the ticket/epic in-context (fills the template,
# scores the authoring rubric, records the BA's answers), then hands the JSON
# here. This helper is the only writer: it stamps authored_at, derives the
# readiness from the gates + open questions so a hand-written readiness can never
# contradict them, and refuses anything the schema rejects.
#
# Readiness derivation (authoritative, not advisory):
#   created      -> only if created_key is present (the issue exists in JIRA)
#   needs-input  -> any blocker check result=fail, OR any open_question lacking a
#                   non-empty answer
#   ready        -> otherwise (all blocker gates pass, every question answered)
#
# Creating the JIRA issue is a separate, operator-approved step (the skill calls
# createJiraIssue, then re-runs this helper with --set-created to stamp the key).
# This helper NEVER touches JIRA.
#
# Usage:
#   story-author-record.sh --in RECORD.json --out FILE
#   story-author-record.sh --in RECORD.json --out FILE --set-created CREATED.json
#   story-author-record.sh readiness --in RECORD.json     # print derived readiness only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/story-draft.v1.json"

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

usage() { sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

mode="write"
in_file="" out_file="" created_file=""

if [ "${1:-}" = "readiness" ]; then mode="readiness"; shift; fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --in) in_file="${2:-}"; shift 2 ;;
    --out) out_file="${2:-}"; shift 2 ;;
    --set-created) created_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "story-author-record: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "${in_file}" ] || { echo "story-author-record: --in required" >&2; exit 1; }
[ -f "${in_file}" ] || { echo "story-author-record: input not found: ${in_file}" >&2; exit 1; }
jq -e . "${in_file}" >/dev/null 2>&1 || { echo "story-author-record: --in is not valid JSON" >&2; exit 1; }

# Derive readiness from created_key + blocker gates + unanswered questions.
# created_key wins (the issue exists); otherwise any blocker fail OR any
# open_question with an empty/absent answer keeps it at needs-input.
derive_readiness() {
  jq -r '
    if (.created_key // "") != "" then "created"
    elif ((.checks // []) | map(select(.severity == "blocker" and .result == "fail")) | length) > 0
      then "needs-input"
    elif ((.open_questions // []) | map(select((.answer // "") == "")) | length) > 0
      then "needs-input"
    else "ready" end' "${in_file}"
}

readiness="$(derive_readiness)"

if [ "${mode}" = "readiness" ]; then
  printf '%s\n' "${readiness}"
  exit 0
fi

[ -n "${out_file}" ] || { echo "story-author-record: --out required" >&2; exit 1; }

created_json="null"
if [ -n "${created_file}" ]; then
  [ -f "${created_file}" ] || { echo "story-author-record: created file not found: ${created_file}" >&2; exit 1; }
  created_json="$(jq -e . "${created_file}")" || { echo "story-author-record: --set-created is not valid JSON" >&2; exit 1; }
fi

mkdir -p "$(dirname "${out_file}")"

tmp="$(mktemp)"
jq \
  --arg schema "story-draft.v1" \
  --arg readiness "${readiness}" \
  --arg now "$(now_utc)" \
  --argjson created "${created_json}" \
  '. + {schema_version: $schema, readiness: $readiness, authored_at: $now}
   + (if $created != null then $created else {} end)
   + (if $created != null and ($created.created_key // "") != "" then {readiness: "created"} else {} end)' \
  "${in_file}" >"${tmp}"

python3 - "${tmp}" "${SCHEMA}" <<'PY'
import json
import sys

record_path, schema_path = sys.argv[1], sys.argv[2]
with open(record_path, encoding="utf-8") as f:
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
    if data.get("schema_version") != "story-draft.v1":
        raise SystemExit("schema_version must be story-draft.v1")
    for key in ("mode", "project_key", "issue_type", "title", "body_markdown", "readiness", "authored_at"):
        if key not in data:
            raise SystemExit(f"missing required field: {key}")
    if data["mode"] not in {"epic", "story"}:
        raise SystemExit(f"invalid mode: {data['mode']}")
    if data["readiness"] not in {"needs-input", "ready", "created"}:
        raise SystemExit(f"invalid readiness: {data['readiness']}")
    for check in data.get("checks", []):
        if check.get("severity") not in {"blocker", "advisory"}:
            raise SystemExit(f"invalid severity: {check.get('severity')}")
        if check.get("result") not in {"pass", "fail", "n-a"}:
            raise SystemExit(f"invalid result: {check.get('result')}")

# A gate marked n-a without a reason is a silent skip — reject it.
for check in data.get("checks", []):
    if check.get("result") == "n-a" and not check.get("note"):
        raise SystemExit(f"gate {check.get('id')} is n-a without a note explaining why")
PY

mv "${tmp}" "${out_file}"
printf '%s\n' "${out_file}"
