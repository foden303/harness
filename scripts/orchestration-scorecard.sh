#!/usr/bin/env bash
# orchestration-scorecard.sh — render the orchestration visibility scorecard
#
# Phase 90.1.3 (spec.md "Orchestration Visibility Contract"): merges the current
# session's backend mix (from the ledger) with lifetime totals (from the
# accumulator) into an orchestration-scorecard.v1 view.
#
# Usage:
#   bash scripts/orchestration-scorecard.sh [--format json|terminal] [session_id]
#
# Claude is the host runtime and is never counted as a delegation; the headline
# figures are worker delegation counts. Tri-state per backend:
#   used (count>0) / available (configured but unused) / not-configured (absent).
# If nothing is recorded, the scorecard degrades to "no delegations observed".

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/lib/orchestration-ledger.sh" ]; then
  # shellcheck source=scripts/lib/orchestration-ledger.sh
  . "${SCRIPT_DIR}/lib/orchestration-ledger.sh" 2>/dev/null || true
fi

FORMAT="json"
SESSION_ID=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:-json}"; shift 2 ;;
    --format=*) FORMAT="${1#*=}"; shift ;;
    -*) shift ;;
    *) SESSION_ID="$1"; shift ;;
  esac
done

if [ -z "${SESSION_ID}" ] && command -v __orch_session_id >/dev/null 2>&1; then
  SESSION_ID="$(__orch_session_id)"
fi

if command -v __orch_ledger_path >/dev/null 2>&1; then
  LEDGER="$(__orch_ledger_path)"
else
  LEDGER="${HARNESS_ORCHESTRATION_LEDGER:-}"
fi
if command -v __orch_totals_path >/dev/null 2>&1; then
  TOTALS="$(__orch_totals_path)"
else
  TOTALS="${HARNESS_ORCHESTRATION_TOTALS:-}"
fi

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"version":1,"observed":false,"note":"jq unavailable"}'
  exit 0
fi

# backend_available <worker> — HARNESS_ORCH_FORCE_AVAIL overrides for tests.
backend_available() {
  local b="$1"
  if [ "${HARNESS_ORCH_FORCE_AVAIL:-__real__}" != "__real__" ]; then
    case ",${HARNESS_ORCH_FORCE_AVAIL}," in
      *",${b},"*) return 0 ;;
      *) return 1 ;;
    esac
  fi
  case "$b" in
    worker) return 0 ;;
    *) return 1 ;;
  esac
}

# session counts for this session (counted delegations only).
session_count() { # $1 = backend
  [ -f "${LEDGER}" ] || { printf '0'; return; }
  jq -s --arg sid "${SESSION_ID}" --arg b "$1" \
    '[.[] | select(.session_id == $sid and .counts == true and .backend == $b)] | length' \
    "${LEDGER}" 2>/dev/null || printf '0'
}

# lifetime count from the accumulator.
lifetime_count() { # $1 = backend
  [ -f "${TOTALS}" ] || { printf '0'; return; }
  jq -r --arg b "$1" '.totals[$b] // 0' "${TOTALS}" 2>/dev/null || printf '0'
}

status_for() { # $1 = count, $2 = backend
  if [ "${1:-0}" -gt 0 ] 2>/dev/null; then printf 'used'; return; fi
  if backend_available "$2"; then printf 'available'; else printf 'not-configured'; fi
}

sc_worker="$(session_count worker)"; sc_worker="${sc_worker:-0}"
lt_worker="$(lifetime_count worker)"; lt_worker="${lt_worker:-0}"

st_worker="$(status_for "${sc_worker}" worker)"

session_non_claude=$(( sc_worker ))
lifetime_non_claude=$(( lt_worker ))

backends_engaged=1 # Claude host is always engaged
[ "${sc_worker}" -gt 0 ] && backends_engaged=$(( backends_engaged + 1 ))

if [ "${session_non_claude}" -gt 0 ] || [ "${lifetime_non_claude}" -gt 0 ]; then
  observed="true"
  note="Number of delegations to the worker backend. Claude (host) work is not counted as a delegation."
else
  observed="false"
  note="no delegations observed — worker unused (ran with Claude only)."
fi

if [ "${FORMAT}" = "terminal" ]; then
  printf 'Orchestration usage (this session)\n'
  if [ "${observed}" = "false" ]; then
    printf '  %s\n' "${note}"
  else
    printf '  This session: worker %s  (Claude=host) — backends engaged %s/2\n' "${sc_worker}" "${backends_engaged}"
    printf '  Lifetime: worker %s\n' "${lt_worker}"
    printf '  %s\n' "${note}"
  fi
  exit 0
fi

if [ "${FORMAT}" = "html-data" ]; then
  # Flattened shape for scripts/render-html.sh (top-level scalars + a backends
  # array). render-html.sh supports {{var}} and {{#section}} only — no nested
  # dot access — so the nested scorecard.v1 is projected here.
  project="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
  gen="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '')"
  jq -n \
    --arg project "${project}" --arg gen "${gen}" \
    --argjson observed "${observed}" --arg note "${note}" \
    --argjson sc_worker "${sc_worker}" --arg st_worker "${st_worker}" \
    --argjson lt_worker "${lt_worker}" \
    --argjson snc "${session_non_claude}" --argjson lnc "${lifetime_non_claude}" \
    --argjson be "${backends_engaged}" \
    '{
      kind: "orchestration-scorecard",
      project: $project,
      generated_at: $gen,
      observed: $observed,
      note: $note,
      session_worker: $sc_worker,
      session_non_claude: $snc,
      backends_engaged: $be,
      lifetime_worker: $lt_worker,
      lifetime_non_claude: $lnc,
      backends: [
        { name: "worker", session: ($sc_worker | tostring), lifetime: ($lt_worker | tostring), status: $st_worker },
        { name: "Claude", session: "host", lifetime: "—", status: "host" }
      ]
    }'
  exit 0
fi

jq -n \
  --arg sid "${SESSION_ID}" \
  --argjson observed "${observed}" \
  --argjson sc_worker "${sc_worker}" --arg st_worker "${st_worker}" \
  --argjson lt_worker "${lt_worker}" \
  --argjson snc "${session_non_claude}" --argjson lnc "${lifetime_non_claude}" \
  --argjson be "${backends_engaged}" \
  --arg note "${note}" \
  '{
    version: 1,
    session_id: $sid,
    observed: $observed,
    session: {
      worker: { count: $sc_worker, status: $st_worker },
      claude: { status: "host" },
      non_claude_delegations: $snc,
      backends_engaged: $be
    },
    lifetime: {
      worker: { count: $lt_worker },
      non_claude_delegations: $lnc
    },
    note: $note
  }'
