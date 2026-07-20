#!/usr/bin/env bash
# flow-mcp-health.sh — tri-state health probe for the Atlassian Rovo MCP.
#
# harness-flow depends on the Atlassian Rovo MCP tools (mcp__claude_ai_Atlassian_Rovo__*)
# for JIRA/Confluence access. Those tools live in the Claude Code runtime, so a
# bash script cannot call them directly. The skill performs the real probe
# (e.g. getAccessibleAtlassianResources / atlassianUserInfo) and passes the
# observed result here; run standalone it reports not-configured.
#
# Tri-state contract (.claude/rules/active-watching-test-policy.md):
#   not-configured : Rovo tools absent (headless/not connected). healthy=true,
#                    exit 0, NO warning — opt-in feature simply not in use.
#   unreachable    : tools present but the probe call failed/timed out.
#                    healthy=false, exit 1, warning.
#   healthy        : probe succeeded. healthy=true, exit 0, no warning.
#
# Resolution order for the observed state:
#   1. --probe <state>            (skill passes the MCP-probe result; tests use this)
#   2. $HARNESS_FLOW_MCP_PROBE    (same values)
#   3. default: not-configured    (bash alone cannot reach MCP)
#
# Usage:
#   flow-mcp-health.sh [--probe healthy|unreachable|not-configured]
set -euo pipefail

probe=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --probe) probe="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "flow-mcp-health: unknown arg: $1" >&2; exit 1 ;;
  esac
done

state="${probe:-${HARNESS_FLOW_MCP_PROBE:-not-configured}}"

case "${state}" in
  healthy)
    echo '{"state":"healthy","healthy":true,"reason":""}'
    exit 0
    ;;
  not-configured)
    # Acknowledged, acceptable state — never warn.
    echo '{"state":"not-configured","healthy":true,"reason":"not-configured"}'
    exit 0
    ;;
  unreachable)
    echo '{"state":"unreachable","healthy":false,"reason":"unreachable","systemMessage":"Atlassian Rovo MCP is unreachable; harness-flow cannot ingest JIRA/Confluence or post BA comments."}'
    exit 1
    ;;
  *)
    echo "flow-mcp-health: invalid probe state '${state}' (allowed: healthy|unreachable|not-configured)" >&2
    exit 2
    ;;
esac
