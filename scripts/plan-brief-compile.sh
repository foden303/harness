#!/bin/bash
# scripts/plan-brief-compile.sh
# Phase 65.1.3 - Plan Brief context compilation logic
#
# Usage:
#   plan-brief-compile.sh --query <text> --project <name> [--mem-results <path>]
#                         [--understanding <text>] [--out -|<path>]
#
# Role:
#   Assemble plan-brief-context.v1 schema-compliant JSON from the user request
#   and harness-mem search results. confidence is kept for display compatibility,
#   but its meaning is limited to plan_readiness:
#     (1) DoD clarity        ... out of 60 points
#     (2) dependency resolution rate ... out of 40 points
#   Past similar cases and D/P counts are only shown as evidence links; they are not mixed into the score.
#   Record the basis of each component in confidence_evidence (string[]) with literal numbers.
#
# Input schema of mem search results (JSON file pointed to by --mem-results):
#   {
#     "decisions":     [{"id": "D22", "title": "...", "relevance": "..."}, ...],
#     "patterns":      [{"id": "P5",  "title": "...", "relevance": "..."}, ...],
#     "plans_archive": [{"phase": "Phase 41", "archive_path": "...",
#                         "outcome": "cc:done|cc:WIP|cc:TODO|skipped",
#                         "relevance": "..."}, ...]
#   }
# If --mem-results is omitted, all are treated as empty arrays (confidence uses only DoD / D-P components).
#
# Output: plan-brief-context.v1 JSON to stdout (or the file given by --out)
# Exit code: 0=success, 2=usage error, 3=invalid input

set -euo pipefail

usage() {
  cat <<USAGE >&2
Usage: $0 --query <text> --project <name> [--mem-results <path>]
          [--understanding <text>] [--out -|<path>]

Arguments:
  --query <text>              user request body (required)
  --project <name>            project name (required, basename of toplevel)
  --mem-results <path>        harness-mem search results JSON file (optional)
  --understanding <text>      Claude's understanding (optional, default: "(not started yet)")
  --out -|<path>              output destination (- = stdout, default: stdout)

Output: plan-brief-context.v1 schema-compliant JSON
USAGE
  exit 2
}

QUERY=""
PROJECT=""
MEM_RESULTS=""
UNDERSTANDING="(not started yet)"
OUT="-"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)         QUERY="${2:-}";         shift 2 ;;
    --project)       PROJECT="${2:-}";       shift 2 ;;
    --mem-results)   MEM_RESULTS="${2:-}";   shift 2 ;;
    --understanding) UNDERSTANDING="${2:-}"; shift 2 ;;
    --out)           OUT="${2:-}";           shift 2 ;;
    -h|--help)       usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$QUERY" || -z "$PROJECT" ]]; then
  echo "ERROR: --query and --project are required" >&2
  usage
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not found" >&2
  exit 3
fi

# ---- Normalize mem results (empty arrays if omitted) ----

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/plan-brief-compile.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
NORM_MEM="$TMP_DIR/mem.json"

if [[ -n "$MEM_RESULTS" ]]; then
  if [[ ! -f "$MEM_RESULTS" ]]; then
    echo "ERROR: --mem-results file not found: $MEM_RESULTS" >&2
    exit 3
  fi
  if ! jq -e '.' "$MEM_RESULTS" >/dev/null 2>&1; then
    echo "ERROR: --mem-results is not valid JSON: $MEM_RESULTS" >&2
    exit 3
  fi
  jq '{
    decisions:     (.decisions     // []),
    patterns:      (.patterns      // []),
    plans_archive: (.plans_archive // [])
  }' "$MEM_RESULTS" > "$NORM_MEM"
else
  echo '{"decisions":[],"patterns":[],"plans_archive":[]}' > "$NORM_MEM"
fi

# ---- plan_readiness component (1): DoD clarity (out of 60 points) ----

# Split the request into sentences by "。" and "\n", and judge whether each contains a number.
# `tr` corrupts UTF-8 full stops as byte sequences under LC_ALL=C environments,
# so aggregate Unicode-safely with the required dependency jq.

SENTENCE_STATS_JSON="$(jq -n --arg q "$QUERY" '
  ($q
   | gsub("。|\\n"; "\n")
   | split("\n")
   | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
   | map(select(length > 0))) as $sentences
  | {
      total: ($sentences | length),
      with_num: ($sentences | map(select(test("[0-9]"))) | length)
    }
')"
NUM_SENTENCES_TOTAL="$(printf '%s\n' "$SENTENCE_STATS_JSON" | jq -r '.total')"
NUM_SENTENCES_WITH_NUM="$(printf '%s\n' "$SENTENCE_STATS_JSON" | jq -r '.with_num')"

if [[ "$NUM_SENTENCES_TOTAL" -eq 0 ]]; then
  SCORE_DOD=0
  EVIDENCE_DOD="plan_readiness DoD clarity: request is empty (0/60)"
else
  SCORE_DOD=$(awk -v n="$NUM_SENTENCES_WITH_NUM" -v t="$NUM_SENTENCES_TOTAL" 'BEGIN { printf "%.0f", 60.0 * n / t }')
  RATE_DOD=$(awk -v n="$NUM_SENTENCES_WITH_NUM" -v t="$NUM_SENTENCES_TOTAL" 'BEGIN { printf "%.0f", 100.0 * n / t }')
  EVIDENCE_DOD="plan_readiness DoD clarity: ${NUM_SENTENCES_WITH_NUM} of ${NUM_SENTENCES_TOTAL} request sentences (${RATE_DOD}%) have numeric requirements (contribution ${SCORE_DOD}/60)"
fi

# ---- plan_readiness component (2): dependency resolution rate (out of 40 points) ----

DECISIONS_COUNT="$(jq '.decisions | length' "$NORM_MEM")"
PATTERNS_COUNT="$(jq '.patterns | length' "$NORM_MEM")"
DP_TOTAL=$((DECISIONS_COUNT + PATTERNS_COUNT))
PAST_TOTAL="$(jq '.plans_archive | length' "$NORM_MEM")"
PAST_DONE="$(jq '[.plans_archive[] | select(.outcome == "cc:done")] | length' "$NORM_MEM")"

if [[ "$PAST_TOTAL" -eq 0 ]]; then
  SCORE_DEP=20
  EVIDENCE_DEP="plan_readiness dependency resolution rate: no similar Plans, treated as neutral (contribution 20/40)"
else
  SCORE_DEP=$(awk -v d="$PAST_DONE" -v t="$PAST_TOTAL" 'BEGIN { printf "%.0f", 40.0 * d / t }')
  RATE_DEP=$(awk -v d="$PAST_DONE" -v t="$PAST_TOTAL" 'BEGIN { printf "%.0f", 100.0 * d / t }')
  EVIDENCE_DEP="plan_readiness dependency resolution rate: ${PAST_DONE} of ${PAST_TOTAL} similar Plans (${RATE_DEP}%) are done (contribution ${SCORE_DEP}/40)"
fi
EVIDENCE_CONTEXT="context only: ${DECISIONS_COUNT} related D + ${PATTERNS_COUNT} P = ${DP_TOTAL} total (not added to the readiness score)"

# ---- plan_readiness total (clamped to 0-100) ----

CONFIDENCE=$((SCORE_DOD + SCORE_DEP))
[[ "$CONFIDENCE" -gt 100 ]] && CONFIDENCE=100
[[ "$CONFIDENCE" -lt 0 ]]   && CONFIDENCE=0

# ---- Assemble output JSON ----

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Get each section as a normalized array
RELATED_DECISIONS_JSON="$(jq '[.decisions[] | {id: (.id // ""), title: (.title // ""), relevance: (.relevance // "")}]' "$NORM_MEM")"
SIMILAR_PAST_PLANS_JSON="$(jq '[.plans_archive[] | {archive_path: (.archive_path // ""), phase: (.phase // ""), outcome: (.outcome // "unknown"), relevance: (.relevance // "")}]' "$NORM_MEM")"
OPTIONS_JSON="$(jq -nc '[{name:"Option A: validate the plan small, then implement",summary:"Check DoD and dependencies first, and generate the Plan Brief with minimal changes",pros:["Easier to find failure conditions early","Small impact on the existing flow"],cons:["Large design changes need a separate task"]}]')"
RISKS_JSON="$(jq -nc '[{kind:"readiness-misread",severity:"warn",description:"Risk of misreading plan_readiness as the AI understanding level or success probability",mitigation:"Note in evidence that it is only a metric of DoD clarity and dependency resolution rate"}]')"
AC_JSON="$(jq -nc '[{id:"AC-1",description:"The Plan Brief context JSON contains non-empty options / risks / acceptance_criteria",verifiable_by:"tests/test-plan-brief-compile.sh"}]')"

# confidence_evidence_items is a derived field for template rendering
EVIDENCE_ITEMS_JSON="$(jq -nc \
  --arg d "$EVIDENCE_DOD" \
  --arg dep "$EVIDENCE_DEP" \
  --arg ctx "$EVIDENCE_CONTEXT" \
  '[{text: $d}, {text: $dep}, {text: $ctx}]')"

CONTEXT_JSON="$(jq -n \
  --arg req "$QUERY" \
  --arg proj "$PROJECT" \
  --arg ts "$GENERATED_AT" \
  --arg understanding "$UNDERSTANDING" \
  --arg ev_dod "$EVIDENCE_DOD" \
  --arg ev_dep "$EVIDENCE_DEP" \
  --arg ev_ctx "$EVIDENCE_CONTEXT" \
  --argjson conf "$CONFIDENCE" \
  --argjson options "$OPTIONS_JSON" \
  --argjson risks "$RISKS_JSON" \
  --argjson ac "$AC_JSON" \
  --argjson rd "$RELATED_DECISIONS_JSON" \
  --argjson sp "$SIMILAR_PAST_PLANS_JSON" \
  --argjson ev_items "$EVIDENCE_ITEMS_JSON" \
  '{
    schema: "plan-brief-context.v1",
    user_request: $req,
    my_understanding: $understanding,
    options: $options,
    risks: $risks,
    acceptance_criteria: $ac,
    confidence: $conf,
    confidence_evidence: [$ev_dod, $ev_dep, $ev_ctx],
    related_decisions: $rd,
    similar_past_plans: $sp,
    project: $proj,
    generated_at: $ts,
    confidence_evidence_items: $ev_items
  }')"

if [[ "$OUT" == "-" || -z "$OUT" ]]; then
  printf '%s\n' "$CONTEXT_JSON"
else
  printf '%s\n' "$CONTEXT_JSON" > "$OUT"
fi
