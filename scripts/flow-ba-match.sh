#!/usr/bin/env bash
# flow-ba-match.sh — match the BA's reply to a harness-flow clarification comment.
#
# The skill normalizes the JIRA/Confluence comment list (fetched via MCP) into a
# JSON array of objects:
#   [{ "id": "...", "author_account_id": "...", "created": "<utc>",
#      "parent_id": "<id-or-null>", "body": "..." }, ...]
# and passes it here with the posting metadata. This helper selects the BA reply:
#   1. keep comments created strictly after --posted-at
#   2. drop comments authored by --bot-account-id (our own posts)
#   3. if any survivor is a reply-child of --posted-comment-id, keep only those
#   4. return the newest by `created`
#
# Output (stdout, one JSON object):
#   {"matched": true,  "id": "...", "created": "...", "body": "..."}
#   {"matched": false}
# Exit 0 whether or not a reply was found; exit 1 only on bad input.
#
# Usage:
#   flow-ba-match.sh --comments FILE --posted-at TS --bot-account-id ID \
#     [--posted-comment-id ID]
set -euo pipefail

comments="" posted_at="" bot="" posted_id=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --comments) comments="${2:-}"; shift 2 ;;
    --posted-at) posted_at="${2:-}"; shift 2 ;;
    --bot-account-id) bot="${2:-}"; shift 2 ;;
    --posted-comment-id) posted_id="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "flow-ba-match: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "${comments}" ] && [ -f "${comments}" ] || { echo "flow-ba-match: --comments FILE required" >&2; exit 1; }
[ -n "${posted_at}" ] || { echo "flow-ba-match: --posted-at required" >&2; exit 1; }
[ -n "${bot}" ] || { echo "flow-ba-match: --bot-account-id required" >&2; exit 1; }

jq \
  --arg posted_at "${posted_at}" \
  --arg bot "${bot}" \
  --arg posted_id "${posted_id}" \
  '
  # 1+2: newer than the post, not authored by the bot.
  ( map(select((.created > $posted_at) and (.author_account_id != $bot))) ) as $fresh
  # 3: prefer direct replies to our clarification comment, if any exist.
  | ( if ($posted_id != "") and ($fresh | map(select(.parent_id == $posted_id)) | length > 0)
        then ($fresh | map(select(.parent_id == $posted_id)))
        else $fresh end ) as $cands
  # 4: newest by created.
  | ( $cands | sort_by(.created) | last ) as $pick
  | if $pick == null
      then {matched: false}
      else {matched: true, id: $pick.id, created: $pick.created, body: $pick.body}
    end
  ' "${comments}"
