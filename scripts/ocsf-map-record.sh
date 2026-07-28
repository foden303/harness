#!/usr/bin/env bash
# ocsf-map-record.sh — validate and persist an ocsf-mapping.v1 record.
#
# harness-ocsf-map profiles the raw samples, chooses the OCSF class and maps the
# fields in-context, then hands the JSON here. This helper is the only writer: it
# stamps mapped_at, derives readiness from the gates + open questions so a
# hand-written readiness can never contradict them, and refuses anything the
# schema rejects.
#
# Readiness derivation (authoritative, not advisory):
#   published    -> the document has been written somewhere (--set-published)
#   needs-input  -> any blocker check result=fail, OR any open_question lacking a
#                   non-empty answer, OR the schema pin is not in-sync
#   ready        -> otherwise (pin in-sync, all blocker gates pass, every question
#                   answered) — ready still means "not published yet"
#
# Publishing is a separate, operator-approved step (the skill writes the folder or
# calls Confluence, then re-runs this helper with --set-published). This helper
# NEVER writes to Confluence and never touches the network.
#
# Usage:
#   ocsf-map-record.sh --in RECORD.json --out FILE
#   ocsf-map-record.sh --in RECORD.json --out FILE --set-published PUBLISHED.json
#   ocsf-map-record.sh readiness --in RECORD.json     # print derived readiness only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/ocsf-mapping.v1.json"

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

usage() { sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

mode="write"
in_file="" out_file="" published_file=""

if [ "${1:-}" = "readiness" ]; then mode="readiness"; shift; fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --in) in_file="${2:-}"; shift 2 ;;
    --out) out_file="${2:-}"; shift 2 ;;
    --set-published) published_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ocsf-map-record: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "${in_file}" ] || { echo "ocsf-map-record: --in required" >&2; exit 1; }
[ -f "${in_file}" ] || { echo "ocsf-map-record: input not found: ${in_file}" >&2; exit 1; }
jq -e . "${in_file}" >/dev/null 2>&1 || { echo "ocsf-map-record: --in is not valid JSON" >&2; exit 1; }

# Derive readiness. An already-published record wins. Otherwise a pin that is not
# in-sync keeps it at needs-input: a mapping scored against a missing or corrupted
# schema is not "ready", however green its gates look.
derive_readiness() {
  jq -r '
    if ((.output.page_id // "") != "") or (((.output.files // []) | length) > 0) then "published"
    elif ((.pin_reason // "not-configured") != "in-sync") then "needs-input"
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

[ -n "${out_file}" ] || { echo "ocsf-map-record: --out required" >&2; exit 1; }

published_json="null"
if [ -n "${published_file}" ]; then
  [ -f "${published_file}" ] || { echo "ocsf-map-record: published file not found: ${published_file}" >&2; exit 1; }
  published_json="$(jq -e . "${published_file}")" || { echo "ocsf-map-record: --set-published is not valid JSON" >&2; exit 1; }
fi

mkdir -p "$(dirname "${out_file}")"

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

jq \
  --arg schema "ocsf-mapping.v1" \
  --arg readiness "${readiness}" \
  --arg now "$(now_utc)" \
  --argjson published "${published_json}" \
  '. + {schema_version: $schema, readiness: $readiness, mapped_at: $now}
   + (if $published != null then {output: ((.output // {}) + $published)} else {} end)
   + (if $published != null
        and ((($published.page_id // "") != "") or ((($published.files // []) | length) > 0))
      then {readiness: "published"} else {} end)' \
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
    if data.get("schema_version") != "ocsf-mapping.v1":
        raise SystemExit("schema_version must be ocsf-mapping.v1")
    for key in ("source_name", "ocsf_version", "ocsf_class", "input", "fields",
                "readiness", "mapped_at"):
        if key not in data:
            raise SystemExit(f"missing required field: {key}")
    if data["readiness"] not in {"needs-input", "ready", "published"}:
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

# Every mapped field must cite a raw path AND a value actually seen in the
# samples. This is the one structural defence against an invented mapping: a
# plausible OCSF attribute with no observed evidence behind it.
for i, field in enumerate(data.get("fields", [])):
    if not field.get("raw_path"):
        raise SystemExit(f"fields[{i}] has no raw_path")
    if not str(field.get("sample_value", "")).strip():
        raise SystemExit(
            f"fields[{i}] ({field.get('raw_path')} -> {field.get('ocsf_attribute')}) "
            "has no sample_value — a mapping with no observed value is invented"
        )

# A required attribute that is neither mapped nor declared missing is silent data
# loss dressed up as a complete mapping.
mapped = {f.get("ocsf_attribute") for f in data.get("fields", [])}
declared = {m.get("ocsf_attribute") for m in data.get("missing_required", [])}
overlap = mapped & declared
if overlap:
    raise SystemExit(
        "attribute listed as both mapped and missing_required: " + ", ".join(sorted(overlap))
    )
PY

mv "${tmp}" "${out_file}"
trap - EXIT
printf '%s\n' "${out_file}"
