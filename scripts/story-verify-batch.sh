#!/usr/bin/env bash
# story-verify-batch.sh — batch cursor for harness-story-verify.
#
# One batch = one invocation target (an Epic and its children, or an explicit
# ticket list). Per-ticket verdicts live in story-verification.v1 records next
# to this file; the batch only tracks which tickets are in scope and where each
# one stands, so a re-run resumes instead of re-asking.
#
# Ticket states:
#   pending             not verified yet
#   clear               verified, no open questions
#   needs-clarification verified, questions drafted but not posted
#   awaiting-ba         questions posted to the ticket, waiting for a reply
#   answered            BA replied and the re-verify came back clear
#   escalated           round cap hit; operator decision needed
#   blocked             ticket could not be read (permission / MCP)
#
# Usage:
#   story-verify-batch.sh init --batch-id ID --mode epic|tickets --root REF \
#       --keys PROJ-1,PROJ-2 [--out FILE]
#   story-verify-batch.sh get FILE [jq-path]
#   story-verify-batch.sh set-state FILE KEY STATE
#   story-verify-batch.sh next FILE                # first ticket not in a terminal state
#   story-verify-batch.sh summary FILE             # counts per state, one line
set -euo pipefail

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
usage() { sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

VALID_STATE=(pending clear needs-clarification awaiting-ba answered escalated blocked)
# next/summary treat these as finished work.
TERMINAL="clear answered escalated blocked"

require_file() {
  [ -n "${1:-}" ] && [ -f "${1}" ] || { echo "story-verify-batch: file not found: ${1:-<missing>}" >&2; exit 1; }
}

jq_update() {
  local file="$1"; shift
  local filter="$1"; shift
  local tmp; tmp="$(mktemp)"
  jq "$@" --arg _now "$(now_utc)" "(${filter}) | .updated_at = \$_now" "${file}" >"${tmp}"
  mv "${tmp}" "${file}"
}

cmd_init() {
  local batch_id="" mode="" root="" keys="" out=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --batch-id) batch_id="${2:-}"; shift 2 ;;
      --mode) mode="${2:-}"; shift 2 ;;
      --root) root="${2:-}"; shift 2 ;;
      --keys) keys="${2:-}"; shift 2 ;;
      --out) out="${2:-}"; shift 2 ;;
      *) echo "story-verify-batch init: unknown arg: $1" >&2; exit 1 ;;
    esac
  done
  [ -n "${batch_id}" ] || { echo "init: --batch-id required" >&2; exit 1; }
  case "${mode}" in epic|tickets) ;; *) echo "init: --mode must be epic|tickets" >&2; exit 1 ;; esac
  [ -n "${keys}" ] || { echo "init: --keys required (comma-separated issue keys)" >&2; exit 1; }
  out="${out:-.claude/state/story-verify/${batch_id}/batch.json}"
  mkdir -p "$(dirname "${out}")"

  # Preserve existing ticket states on re-init so a re-run never resets progress.
  local prev="{}"
  if [ -f "${out}" ]; then
    prev="$(jq '[.tickets[] | {key: .key, value: .state}] | from_entries' "${out}")"
  fi

  jq -n \
    --arg batch_id "${batch_id}" \
    --arg mode "${mode}" \
    --arg root "${root}" \
    --arg keys "${keys}" \
    --argjson prev "${prev}" \
    --arg now "$(now_utc)" \
    '{
      schema_version: "story-verify-batch.v1",
      batch_id: $batch_id,
      mode: $mode,
      root_ref: $root,
      tickets: ($keys | split(",") | map(select(length > 0))
                | map({key: ., state: ($prev[.] // "pending")})),
      created_at: $now,
      updated_at: $now
    }' >"${out}"
  printf '%s\n' "${out}"
}

cmd_get() {
  local file="${1:-}"; require_file "${file}"
  if [ -n "${2:-}" ]; then jq -r "${2}" "${file}"; else cat "${file}"; fi
}

cmd_set_state() {
  local file="${1:-}" key="${2:-}" state="${3:-}"
  require_file "${file}"
  [ -n "${key}" ] && [ -n "${state}" ] || { echo "set-state: FILE KEY STATE required" >&2; exit 1; }
  local ok=0
  for s in "${VALID_STATE[@]}"; do [ "${s}" = "${state}" ] && ok=1; done
  [ "${ok}" = 1 ] || { echo "set-state: invalid state: ${state} (valid: ${VALID_STATE[*]})" >&2; exit 1; }
  jq -e --arg k "${key}" 'any(.tickets[]; .key == $k)' "${file}" >/dev/null \
    || { echo "set-state: ${key} is not in this batch" >&2; exit 1; }
  jq_update "${file}" '.tickets |= map(if .key == $k then .state = $s else . end)' \
    --arg k "${key}" --arg s "${state}"
}

cmd_next() {
  local file="${1:-}"; require_file "${file}"
  jq -r --arg terminal "${TERMINAL}" '
    ($terminal | split(" ")) as $t
    | [.tickets[] | select(.state as $s | ($t | index($s)) | not)][0].key // ""' "${file}"
}

cmd_summary() {
  local file="${1:-}"; require_file "${file}"
  jq -r '
    (.tickets | group_by(.state) | map({state: .[0].state, n: length})) as $g
    | "batch=\(.batch_id) mode=\(.mode) root=\(.root_ref) total=\(.tickets | length) "
      + ($g | map("\(.state)=\(.n)") | join(" "))' "${file}"
}

case "${1:-}" in
  init) shift; cmd_init "$@" ;;
  get) shift; cmd_get "$@" ;;
  set-state) shift; cmd_set_state "$@" ;;
  next) shift; cmd_next "$@" ;;
  summary) shift; cmd_summary "$@" ;;
  -h|--help|"") usage ;;
  *) echo "story-verify-batch: unknown command: $1" >&2; usage >&2; exit 1 ;;
esac
