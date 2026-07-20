#!/usr/bin/env bash
# test-flow-mcp-health.sh — tri-state health probe for the Atlassian Rovo MCP.
#
# Enforces .claude/rules/active-watching-test-policy.md: the three states
# (not-configured / unreachable / healthy) each behave correctly, and the
# not-configured state must NOT warn (opt-in feature simply not in use).
#
# Uses `set -uo pipefail` (no -e) because several cases intentionally exit
# non-zero and we assert on the captured exit code.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE="${ROOT}/scripts/flow-mcp-health.sh"

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1" >&2; fail=1; }

[ -x "${PROBE}" ] || die "flow-mcp-health.sh missing/not executable"

# TestFlowMcpHealth_NotConfigured — default surface, no probe input.
out="$(bash "${PROBE}" 2>/dev/null)"; rc=$?
if [ "${rc}" -eq 0 ] \
  && [ "$(printf '%s' "${out}" | jq -r .state)" = "not-configured" ] \
  && [ "$(printf '%s' "${out}" | jq -r .healthy)" = "true" ] \
  && [ "$(printf '%s' "${out}" | jq -r 'has("systemMessage")')" = "false" ]; then
  pass "not-configured: exit 0, healthy=true, no warning"
else
  die "not-configured behavior wrong (rc=${rc}, out=${out})"
fi

# Also via env var.
out="$(HARNESS_FLOW_MCP_PROBE=not-configured bash "${PROBE}" 2>/dev/null)"; rc=$?
[ "${rc}" -eq 0 ] && pass "not-configured via env var: exit 0" || die "env-var not-configured wrong (rc=${rc})"

# TestFlowMcpHealth_Unreachable — tools present but probe failed.
out="$(bash "${PROBE}" --probe unreachable 2>/dev/null)"; rc=$?
if [ "${rc}" -eq 1 ] \
  && [ "$(printf '%s' "${out}" | jq -r .healthy)" = "false" ] \
  && [ "$(printf '%s' "${out}" | jq -r 'has("systemMessage")')" = "true" ]; then
  pass "unreachable: exit 1, healthy=false, warning present"
else
  die "unreachable behavior wrong (rc=${rc}, out=${out})"
fi

# TestFlowMcpHealth_Healthy — probe succeeded.
out="$(bash "${PROBE}" --probe healthy 2>/dev/null)"; rc=$?
if [ "${rc}" -eq 0 ] \
  && [ "$(printf '%s' "${out}" | jq -r .state)" = "healthy" ] \
  && [ "$(printf '%s' "${out}" | jq -r .healthy)" = "true" ] \
  && [ "$(printf '%s' "${out}" | jq -r 'has("systemMessage")')" = "false" ]; then
  pass "healthy: exit 0, healthy=true, no warning"
else
  die "healthy behavior wrong (rc=${rc}, out=${out})"
fi

# Invalid probe value must error clearly.
if bash "${PROBE}" --probe garbage >/dev/null 2>&1; then
  die "invalid probe value accepted (expected non-zero)"
else
  pass "invalid probe value rejected"
fi

if [ "${fail}" -ne 0 ]; then
  echo "test-flow-mcp-health: FAIL"
  exit 1
fi
echo "test-flow-mcp-health: all PASS"
exit 0
