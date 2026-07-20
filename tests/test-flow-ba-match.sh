#!/usr/bin/env bash
# test-flow-ba-match.sh — harness-flow BA-reply matcher (Phase 3).
#
# Given a comment list with (a) our bot comment, (b) an older comment, and
# (c) a newer BA comment, the matcher must pick (c) and ignore (a) and (b).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATCH="${ROOT}/scripts/flow-ba-match.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1" >&2; fail=1; }

[ -x "${MATCH}" ] || die "flow-ba-match.sh missing/not executable"

BOT="bot-acct"
POSTED_AT="2026-07-16T10:00:00Z"
POSTED_ID="c-bot-1"

cat > "${TMP}/comments.json" <<JSON
[
  {"id":"c-old","author_account_id":"ba-acct","created":"2026-07-16T09:00:00Z","parent_id":null,"body":"older, before our question"},
  {"id":"c-bot-1","author_account_id":"bot-acct","created":"2026-07-16T10:00:00Z","parent_id":null,"body":"harness-flow clarify question"},
  {"id":"c-ba-reply","author_account_id":"ba-acct","created":"2026-07-16T11:30:00Z","parent_id":"c-bot-1","body":"Here are the criteria: 200/400/404"}
]
JSON

# --- happy path: picks the newer BA reply ---
out="$(bash "${MATCH}" --comments "${TMP}/comments.json" --posted-at "${POSTED_AT}" --bot-account-id "${BOT}" --posted-comment-id "${POSTED_ID}")"
if [ "$(printf '%s' "${out}" | jq -r .matched)" = "true" ] \
  && [ "$(printf '%s' "${out}" | jq -r .id)" = "c-ba-reply" ]; then
  pass "picks the newer BA reply (ignores bot + older comment)"
else
  die "wrong match: ${out}"
fi

# --- no reply yet: only bot + older comment ---
cat > "${TMP}/none.json" <<JSON
[
  {"id":"c-old","author_account_id":"ba-acct","created":"2026-07-16T09:00:00Z","parent_id":null,"body":"older"},
  {"id":"c-bot-1","author_account_id":"bot-acct","created":"2026-07-16T10:00:00Z","parent_id":null,"body":"our question"}
]
JSON
out="$(bash "${MATCH}" --comments "${TMP}/none.json" --posted-at "${POSTED_AT}" --bot-account-id "${BOT}" --posted-comment-id "${POSTED_ID}")"
if [ "$(printf '%s' "${out}" | jq -r .matched)" = "false" ]; then
  pass "no reply yet -> matched:false"
else
  die "should not have matched: ${out}"
fi

# --- non-threaded fallback: newest non-bot after posted_at, no parent link ---
cat > "${TMP}/flat.json" <<JSON
[
  {"id":"c-bot-1","author_account_id":"bot-acct","created":"2026-07-16T10:00:00Z","parent_id":null,"body":"our question"},
  {"id":"c-ba-flat","author_account_id":"ba-acct","created":"2026-07-16T12:00:00Z","parent_id":null,"body":"reply without threading"}
]
JSON
out="$(bash "${MATCH}" --comments "${TMP}/flat.json" --posted-at "${POSTED_AT}" --bot-account-id "${BOT}" --posted-comment-id "${POSTED_ID}")"
if [ "$(printf '%s' "${out}" | jq -r .id)" = "c-ba-flat" ]; then
  pass "falls back to newest non-bot comment when no threaded reply exists"
else
  die "flat fallback wrong: ${out}"
fi

# --- bad input rejected ---
if bash "${MATCH}" --posted-at "${POSTED_AT}" --bot-account-id "${BOT}" >/dev/null 2>&1; then
  die "missing --comments accepted (expected exit 1)"
else
  pass "missing --comments rejected"
fi

if [ "${fail}" -ne 0 ]; then
  echo "test-flow-ba-match: FAIL"
  exit 1
fi
echo "test-flow-ba-match: all PASS"
exit 0
