#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTER="${ROOT_DIR}/scripts/model-routing.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

[ -x "${ROUTER}" ] || {
  echo "model-routing.sh must be executable"
  exit 1
}

claude_lite_model="$(bash "${ROUTER}" --host claude --role explorer --field model)"
[ "${claude_lite_model}" = "claude-haiku-4-5" ] || {
  echo "claude explorer must route to claude-haiku-4-5"
  exit 1
}

claude_advisor_effort="$(bash "${ROUTER}" --host claude --role advisor --field effort)"
[ "${claude_advisor_effort}" = "xhigh" ] || {
  echo "claude advisor must route to xhigh"
  exit 1
}

claude_advisor_model="$(bash "${ROUTER}" --host claude --role advisor --field model)"
[ "${claude_advisor_model}" = "claude-opus-4-8" ] || {
  echo "claude advisor must route to claude-opus-4-8"
  exit 1
}

claude_args="$(bash "${ROUTER}" --host claude --tier review --format args | tr '\n' ' ')"
printf '%s' "${claude_args}" | grep -q -- '--model claude-sonnet-5' || {
  echo "claude args must include review model"
  exit 1
}
printf '%s' "${claude_args}" | grep -q -- '--effort xhigh' || {
  echo "claude args must include xhigh effort"
  exit 1
}

if bash "${ROUTER}" --host claude --tier unknown >/tmp/model-routing-unknown.out 2>/tmp/model-routing-unknown.err; then
  echo "unknown tier should fail"
  exit 1
fi

# --- Fable brain opt-in (HARNESS_BRAIN_MODEL) ---

unset_default_model="$(env -u HARNESS_BRAIN_MODEL bash "${ROUTER}" --host claude --role advisor --field model)"
[ "${unset_default_model}" = "claude-opus-4-8" ] || {
  echo "unset HARNESS_BRAIN_MODEL must keep claude-opus-4-8"
  exit 1
}

empty_default_model="$(HARNESS_BRAIN_MODEL= bash "${ROUTER}" --host claude --role advisor --field model)"
[ "${empty_default_model}" = "claude-opus-4-8" ] || {
  echo "empty HARNESS_BRAIN_MODEL must keep claude-opus-4-8"
  exit 1
}

fable_advisor_model="$(HARNESS_BRAIN_MODEL=fable bash "${ROUTER}" --host claude --role advisor --field model)"
[ "${fable_advisor_model}" = "claude-fable-5" ] || {
  echo "HARNESS_BRAIN_MODEL=fable must route claude advisor to claude-fable-5"
  exit 1
}

fable_deep_model="$(HARNESS_BRAIN_MODEL=fable bash "${ROUTER}" --host claude --tier deep --field model)"
[ "${fable_deep_model}" = "claude-fable-5" ] || {
  echo "HARNESS_BRAIN_MODEL=fable must route claude deep tier to claude-fable-5"
  exit 1
}

fable_advisor_effort="$(HARNESS_BRAIN_MODEL=fable bash "${ROUTER}" --host claude --role advisor --field effort)"
[ "${fable_advisor_effort}" = "xhigh" ] || {
  echo "fable brain opt-in must keep xhigh effort"
  exit 1
}

opus_explicit_model="$(HARNESS_BRAIN_MODEL=opus bash "${ROUTER}" --host claude --role advisor --field model)"
[ "${opus_explicit_model}" = "claude-opus-4-8" ] || {
  echo "HARNESS_BRAIN_MODEL=opus must keep claude-opus-4-8"
  exit 1
}

fable_worker_model="$(HARNESS_BRAIN_MODEL=fable bash "${ROUTER}" --host claude --role worker --field model)"
[ "${fable_worker_model}" = "claude-sonnet-5" ] || {
  echo "fable brain opt-in must not touch the claude worker tier"
  exit 1
}

fable_reviewer_model="$(HARNESS_BRAIN_MODEL=fable bash "${ROUTER}" --host claude --role reviewer --field model)"
[ "${fable_reviewer_model}" = "claude-sonnet-5" ] || {
  echo "fable brain opt-in must not change the primary review tier"
  exit 1
}

if HARNESS_BRAIN_MODEL=bogus bash "${ROUTER}" --host claude --role advisor >/dev/null 2>&1; then
  echo "unknown HARNESS_BRAIN_MODEL value should fail loudly"
  exit 1
fi

echo "OK"
