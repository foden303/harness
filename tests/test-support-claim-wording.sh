#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Public surfaces a prospective user reads before installing anything.
PUBLIC_FILES=(
  "${ROOT_DIR}/README.md"
  "${ROOT_DIR}/docs/onboarding/index.md"
  "${ROOT_DIR}/docs/onboarding/install.md"
  "${ROOT_DIR}/docs/onboarding/migration.md"
  "${ROOT_DIR}/docs/onboarding/skill-trigger-acceptance.md"
  "${ROOT_DIR}/docs/tool-capability-matrix.md"
  "${ROOT_DIR}/docs/bootstrap-routing-contract.md"
)

# Harness supports exactly one host. No other agent CLI may appear next to a
# support claim — including the backends this repo once carried (codex, cursor,
# opencode) and the ones it only ever researched (copilot, antigravity). Listing
# them all, rather than just the two whose claims were removed, means a
# re-introduction is caught as well as a leftover.
UNSUPPORTED_HOSTS='GitHub Copilot CLI|Copilot CLI|Copilot|Antigravity CLI|Antigravity|Codex CLI|Codex|Cursor|OpenCode|Gemini CLI|Aider'

fail() {
  echo "test-support-claim-wording: FAIL: $1" >&2
  exit 1
}

for file in "${PUBLIC_FILES[@]}"; do
  [ -f "$file" ] || fail "missing ${file}"

  # "<host> ... supported"
  if grep -Eiq "(${UNSUPPORTED_HOSTS}).{0,80}([^[:alpha:]]supported([^[:alpha:]]|\$))" "$file"; then
    fail "unsupported host appears supported in ${file}"
  fi

  # "supported ... <host>"
  if grep -Eiq "(^|[^[:alpha:]])supported([^[:alpha:]]|\$).{0,80}(${UNSUPPORTED_HOSTS})" "$file"; then
    fail "support wording implies an unsupported host in ${file}"
  fi
done

# The supported host must still be stated, or the checks above would pass
# trivially against a page that claims nothing at all.
grep -Fq 'Claude Code | `supported`' "${ROOT_DIR}/docs/tool-capability-matrix.md" \
  || fail "capability matrix no longer states the Claude Code support tier"

echo "test-support-claim-wording: ok"
