#!/usr/bin/env bash
# story-verify-record.sh — validate and persist a story-verification.v1 record.
#
# The skill reads the JIRA issue via MCP, scores it against the rubric
# in-context, then hands the resulting JSON to this helper. The helper is the
# only writer: it stamps verified_at, derives the verdict from the checks so a
# hand-written verdict can never contradict the gates, and refuses anything the
# schema rejects.
#
# Verdict derivation (authoritative, not advisory):
#   blocked                -> only if the caller passes verdict=blocked explicitly
#   needs-clarification    -> any blocker check result=fail, OR questions[] non-empty
#   clear                  -> otherwise
#
# Usage:
#   story-verify-record.sh --in RECORD.json --out FILE
#   story-verify-record.sh --in RECORD.json --out FILE --set-clarification CLARIF.json
#   story-verify-record.sh --in RECORD.json --out FILE --set-handoff HANDOFF.json
#   story-verify-record.sh verdict --in RECORD.json      # print derived verdict only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/story-verification.v1.json"

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

usage() { sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

mode="write"
in_file="" out_file="" clarif_file="" handoff_file=""

if [ "${1:-}" = "verdict" ]; then mode="verdict"; shift; fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --in) in_file="${2:-}"; shift 2 ;;
    --out) out_file="${2:-}"; shift 2 ;;
    --set-clarification) clarif_file="${2:-}"; shift 2 ;;
    --set-handoff) handoff_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "story-verify-record: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "${in_file}" ] || { echo "story-verify-record: --in required" >&2; exit 1; }
[ -f "${in_file}" ] || { echo "story-verify-record: input not found: ${in_file}" >&2; exit 1; }
jq -e . "${in_file}" >/dev/null 2>&1 || { echo "story-verify-record: --in is not valid JSON" >&2; exit 1; }

# Derive the verdict from the checks. A caller-declared "blocked" is preserved
# (it means the ticket could not be read at all); everything else is recomputed.
derive_verdict() {
  jq -r '
    if .verdict == "blocked" then "blocked"
    elif ((.checks // []) | map(select(.severity == "blocker" and .result == "fail")) | length) > 0
      then "needs-clarification"
    elif ((.questions // []) | length) > 0 then "needs-clarification"
    else "clear" end' "${in_file}"
}

verdict="$(derive_verdict)"

if [ "${mode}" = "verdict" ]; then
  printf '%s\n' "${verdict}"
  exit 0
fi

[ -n "${out_file}" ] || { echo "story-verify-record: --out required" >&2; exit 1; }

clarif_json="null"
if [ -n "${clarif_file}" ]; then
  [ -f "${clarif_file}" ] || { echo "story-verify-record: clarification file not found: ${clarif_file}" >&2; exit 1; }
  clarif_json="$(jq -e . "${clarif_file}")" || { echo "story-verify-record: --set-clarification is not valid JSON" >&2; exit 1; }
fi

handoff_json="null"
if [ -n "${handoff_file}" ]; then
  [ -f "${handoff_file}" ] || { echo "story-verify-record: handoff file not found: ${handoff_file}" >&2; exit 1; }
  handoff_json="$(jq -e . "${handoff_file}")" || { echo "story-verify-record: --set-handoff is not valid JSON" >&2; exit 1; }
fi

mkdir -p "$(dirname "${out_file}")"

tmp="$(mktemp)"
jq \
  --arg schema "story-verification.v1" \
  --arg verdict "${verdict}" \
  --arg now "$(now_utc)" \
  --argjson clarif "${clarif_json}" \
  --argjson handoff "${handoff_json}" \
  '. + {schema_version: $schema, verdict: $verdict, verified_at: $now}
   + (if $clarif != null then {clarification: ((.clarification // {}) + $clarif)} else {} end)
   + (if $handoff != null then {handoff: ((.handoff // {}) + $handoff)} else {} end)' \
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
    if data.get("schema_version") != "story-verification.v1":
        raise SystemExit("schema_version must be story-verification.v1")
    for key in ("issue_key", "title", "verdict", "checks", "verified_at"):
        if key not in data:
            raise SystemExit(f"missing required field: {key}")
    if data["verdict"] not in {"clear", "needs-clarification", "blocked"}:
        raise SystemExit(f"invalid verdict: {data['verdict']}")
    if not isinstance(data["checks"], list) or not data["checks"]:
        raise SystemExit("checks must be a non-empty array")
    for check in data["checks"]:
        if check.get("severity") not in {"blocker", "advisory"}:
            raise SystemExit(f"invalid severity: {check.get('severity')}")
        if check.get("result") not in {"pass", "fail", "n-a"}:
            raise SystemExit(f"invalid result: {check.get('result')}")

# A gate marked n-a without a reason is a silent skip — reject it.
for check in data["checks"]:
    if check.get("result") == "n-a" and not check.get("note"):
        raise SystemExit(f"gate {check.get('id')} is n-a without a note explaining why")

# Each gate's severity is fixed by the rubric
# (skills/ba-story-verify/references/us-rubric.md). A record that downgrades
# a blocker to advisory would let a failing gate pass silently.
GATE_SEVERITY = {
    "goal-value-clear": "blocker",
    "ac-present-testable": "blocker",
    "ac-covers-happy-path": "blocker",
    "edge-error-states": "blocker",
    "data-validation-rules": "blocker",
    "scope-boundaries": "blocker",
    "dependencies-identified": "blocker",
    "no-ambiguous-wording": "blocker",
    "invest-sizing": "blocker",
    "story-format": "advisory",
    "design-reference": "advisory",
    "nonfunctional-stated": "advisory",
    "assumptions-confirmed": "advisory",
}
for check in data["checks"]:
    expected = GATE_SEVERITY.get(check.get("id"))
    if expected and check.get("severity") != expected:
        raise SystemExit(f"gate {check.get('id')} must be severity={expected}, got {check.get('severity')}")
PY

mv "${tmp}" "${out_file}"
printf '%s\n' "${out_file}"
