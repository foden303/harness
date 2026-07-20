#!/usr/bin/env bash
# Resolve Harness model/effort routing from a small role-tier contract.

set -euo pipefail

HOST="claude"
TIER=""
ROLE=""
FIELD=""
FORMAT="json"

usage() {
  cat <<'EOF'
Usage:
  scripts/model-routing.sh [--host claude] --tier TIER [--format json|args|env] [--field model|effort]
  scripts/model-routing.sh [--host claude] --role ROLE [--format json|args|env] [--field model|effort]

Tiers: lite, standard, deep, review, advisor, release, long-context
Roles: explorer, worker, reviewer, advisor, plan, release, operator, long-context
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --host=*) HOST="${1#*=}"; shift ;;
    --tier) TIER="${2:-}"; shift 2 ;;
    --tier=*) TIER="${1#*=}"; shift ;;
    --role) ROLE="${2:-}"; shift 2 ;;
    --role=*) ROLE="${1#*=}"; shift ;;
    --field) FIELD="${2:-}"; shift 2 ;;
    --field=*) FIELD="${1#*=}"; shift ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --format=*) FORMAT="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

role_to_tier() {
  case "$1" in
    explorer|reader|search|lite) printf 'lite\n' ;;
    worker|implementer|setup|standard) printf 'standard\n' ;;
    plan|planner|architect|deep) printf 'deep\n' ;;
    reviewer|review|adversarial-review) printf 'review\n' ;;
    advisor) printf 'advisor\n' ;;
    release|closeout) printf 'release\n' ;;
    operator) printf 'standard\n' ;;
    long-context|long_context) printf 'long-context\n' ;;
    *) echo "ERROR: unknown role: $1" >&2; exit 2 ;;
  esac
}

if [ -z "$TIER" ]; then
  if [ -n "$ROLE" ]; then
    TIER="$(role_to_tier "$ROLE")"
  else
    TIER="standard"
  fi
fi

case "$HOST" in
  claude) ;;
  *) echo "ERROR: unsupported host: $HOST" >&2; exit 2 ;;
esac

# Brain opt-in: HARNESS_BRAIN_MODEL switches the claude-host brain tiers
# (deep/advisor) only.
CLAUDE_BRAIN_MODEL="claude-opus-4-8"
case "${HARNESS_BRAIN_MODEL:-opus}" in
  opus) ;;
  fable) CLAUDE_BRAIN_MODEL="claude-fable-5" ;;
  *) echo "ERROR: unknown HARNESS_BRAIN_MODEL: ${HARNESS_BRAIN_MODEL} (use opus|fable)" >&2; exit 2 ;;
esac

MODEL=""
EFFORT=""

case "$TIER" in
  lite) MODEL="claude-haiku-4-5"; EFFORT="low" ;;
  standard) MODEL="claude-sonnet-5"; EFFORT="medium" ;;
  deep|advisor) MODEL="$CLAUDE_BRAIN_MODEL"; EFFORT="xhigh" ;;
  review) MODEL="claude-sonnet-5"; EFFORT="xhigh" ;;
  release) MODEL="claude-sonnet-5"; EFFORT="high" ;;
  long-context) MODEL="sonnet[1m]"; EFFORT="high" ;;
  *) echo "ERROR: unknown claude tier: $TIER" >&2; exit 2 ;;
esac

case "$FIELD" in
  "") ;;
  model) printf '%s\n' "$MODEL"; exit 0 ;;
  effort) printf '%s\n' "$EFFORT"; exit 0 ;;
  *) echo "ERROR: unsupported field: $FIELD" >&2; exit 2 ;;
esac

case "$FORMAT" in
  json)
    printf '{"host":"%s","tier":"%s","model":"%s","effort":"%s"}\n' "$HOST" "$TIER" "$MODEL" "$EFFORT"
    ;;
  args)
    printf '%s\n' "--model" "$MODEL" "--effort" "$EFFORT"
    ;;
  env)
    printf 'CLAUDE_MODEL=%s\nCLAUDE_EFFORT=%s\n' "$MODEL" "$EFFORT"
    ;;
  *) echo "ERROR: unsupported format: $FORMAT" >&2; exit 2 ;;
esac
