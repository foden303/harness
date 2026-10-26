#!/usr/bin/env bash
# jira-status-match.sh — pick the clarification transition for a JIRA issue.
#
# When ba-story-verify / ba-epic-verify post questions back to the BA
# they also hand the ticket over: assignee -> reporter, status -> a
# clarification state. Workflow names differ per project, so the target is
# chosen from the transitions the issue ACTUALLY offers rather than assumed.
#
# Matching order:
#   1. --prefer NAME  exact (case-insensitive) match on the destination status
#      or the transition name. If --prefer is given and not available, the
#      result is matched=false with reason=preferred-status-not-available —
#      an explicit operator choice is never silently redirected.
#   2. the candidate list, in order, exact match first, then substring.
#      Default: Clarification, Waiting for BA, Needs Info, In Review
#
# No match is a SKIP, not a failure: exit 0 with matched=false so the caller
# still posts the comment and reports that the status was left alone. Exit 1 is
# reserved for malformed input.
#
# Input: the getTransitionsForJiraIssue payload, either {"transitions":[...]}
# or a bare [...] array. Each item: {id, name, to: {name}}.
#
# Usage:
#   jira-status-match.sh --transitions FILE [--prefer NAME] [--candidates "A,B"]
#                        [--current-status NAME]
set -euo pipefail

usage() { sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

DEFAULT_CANDIDATES="Clarification,Waiting for BA,Needs Info,In Review"

transitions_file="" prefer="" candidates="${DEFAULT_CANDIDATES}" current_status=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --transitions) transitions_file="${2:-}"; shift 2 ;;
    --prefer) prefer="${2:-}"; shift 2 ;;
    --candidates) candidates="${2:-}"; shift 2 ;;
    --current-status) current_status="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "jira-status-match: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "${transitions_file}" ] || { echo "jira-status-match: --transitions required" >&2; exit 1; }
[ -f "${transitions_file}" ] || { echo "jira-status-match: file not found: ${transitions_file}" >&2; exit 1; }
jq -e . "${transitions_file}" >/dev/null 2>&1 || { echo "jira-status-match: --transitions is not valid JSON" >&2; exit 1; }

jq -e 'if type == "object" then has("transitions") else type == "array" end' \
  "${transitions_file}" >/dev/null 2>&1 \
  || { echo "jira-status-match: expected {\"transitions\":[...]} or [...]" >&2; exit 1; }

jq -n \
  --slurpfile raw "${transitions_file}" \
  --arg prefer "${prefer}" \
  --arg candidates "${candidates}" \
  --arg current "${current_status}" '
  def norm: (. // "") | ascii_downcase | gsub("^\\s+|\\s+$"; "");
  # exact match on destination status, then on transition name
  def pick_exact($t; $want):
    ($t | map(select((.to | norm) == ($want | norm)))
        + map(select((.name | norm) == ($want | norm)))) | .[0];
  # substring match, destination status first
  def pick_loose($t; $want):
    ($t | map(select((.to | norm) | contains($want | norm)))
        + map(select((.name | norm) | contains($want | norm)))) | .[0];

  ($raw[0] | if type == "array" then . else (.transitions // []) end) as $ts
  | ($ts | map({
      id: (.id | tostring),
      name: (.name // ""),
      to: (.to.name // .to // "")
    })) as $t
  | ($t | map(if (.to | length) > 0 then .to else .name end)) as $available
  | ($candidates | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))) as $cands
  | if ($current | length) > 0 and ($cands | map(norm) | index($current | norm)) != null
     and ($prefer | length) == 0 then
    {matched: false, reason: "already-in-target-status",
     current_status: $current, available: $available}
  elif ($prefer | length) > 0 then
    (pick_exact($t; $prefer) // pick_loose($t; $prefer)) as $hit
    | if $hit == null then
        {matched: false, reason: "preferred-status-not-available",
         preferred: $prefer, available: $available}
      elif ($current | length) > 0 and (($hit.to | norm) == ($current | norm)) then
        {matched: false, reason: "already-in-target-status",
         current_status: $current, available: $available}
      else
        {matched: true, transition_id: $hit.id, transition_name: $hit.name,
         to_status: (if ($hit.to | length) > 0 then $hit.to else $hit.name end),
         matched_by: ("prefer:" + $prefer)}
      end
  else
    ([$cands[] | . as $c | (pick_exact($t; $c) // pick_loose($t; $c))
                 | select(. != null) | . + {_cand: $c}] | .[0]) as $hit
    | if $hit == null then
        {matched: false, reason: "no-matching-transition",
         candidates: $cands, available: $available}
      elif ($current | length) > 0 and (($hit.to | norm) == ($current | norm)) then
        {matched: false, reason: "already-in-target-status",
         current_status: $current, available: $available}
      else
        {matched: true, transition_id: $hit.id, transition_name: $hit.name,
         to_status: (if ($hit.to | length) > 0 then $hit.to else $hit.name end),
         matched_by: ("candidate:" + $hit._cand)}
      end
  end'
