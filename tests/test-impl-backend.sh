#!/usr/bin/env bash
# test-impl-backend.sh
# Verify the behavior of set-impl-backend.sh / resolve-impl-backend.sh.
# The harness is Claude-only, so `claude` is the sole valid backend; every
# other value must warn/exit and fall back to claude.
#
# Isolation: use a temporary env.local via HARNESS_ENV_LOCAL; do not touch the real env.local.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SET="${PROJECT_ROOT}/scripts/set-impl-backend.sh"
RESOLVE="${PROJECT_ROOT}/scripts/resolve-impl-backend.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Prepare an isolated temporary env.local (respecting TMPDIR)
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/impl-backend-test.XXXXXX")"
export HARNESS_ENV_LOCAL="${TMP_DIR}/env.local"
# Also isolate the user scope up front. Reading the real
# ~/.config/claude-harness/impl-backend.env would break the default judgments
# on an opt-in machine
# (active-watching-test-policy: do not depend on unisolated optional user-scope config).
export HARNESS_USER_BACKEND_FILE="${TMP_DIR}/user-backend"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

[ -f "$SET" ] || fail "missing script: $SET"
[ -f "$RESOLVE" ] || fail "missing script: $RESOLVE"

# Helper to reset env.local before each test
reset_env_local() {
  rm -f "${HARNESS_ENV_LOCAL}"
}

# ---------------------------------------------------------------------------
# (a) the --backend flag resolves the valid backend
# ---------------------------------------------------------------------------
reset_env_local
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE" --backend claude)"
[ "$got" = "claude" ] || fail "(a) --backend claude should resolve claude, got '$got'"

# ---------------------------------------------------------------------------
# (b) the HARNESS_IMPL_BACKEND env resolves the valid backend
# ---------------------------------------------------------------------------
reset_env_local
got="$(HARNESS_IMPL_BACKEND=claude bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(b) env claude should resolve claude, got '$got'"

# ---------------------------------------------------------------------------
# (c) use the file value when env / flag are absent
# ---------------------------------------------------------------------------
reset_env_local
printf 'export HARNESS_IMPL_BACKEND=claude\n' > "${HARNESS_ENV_LOCAL}"
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(c) file value should be used, got '$got'"

# ---------------------------------------------------------------------------
# (d) default is claude when nothing is set
# ---------------------------------------------------------------------------
reset_env_local
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(d) default should be claude, got '$got'"

# ---------------------------------------------------------------------------
# (d2) an invalid --default value exits non-zero
# ---------------------------------------------------------------------------
reset_env_local
if env -u HARNESS_IMPL_BACKEND bash "$RESOLVE" --default bogus >/dev/null 2>&1; then
  fail "(d2) invalid --default should exit non-zero"
fi

# ---------------------------------------------------------------------------
# (e) set-impl-backend writes and resolve reads it back
# ---------------------------------------------------------------------------
reset_env_local
env -u HARNESS_IMPL_BACKEND bash "$SET" claude >/dev/null
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(e) set then resolve should return claude, got '$got'"
grep -qE "^export HARNESS_IMPL_BACKEND=claude$" "${HARNESS_ENV_LOCAL}" \
  || fail "(e) env.local should contain the export line"

# ---------------------------------------------------------------------------
# (f) idempotency: re-running with the same value creates no duplicate line
# ---------------------------------------------------------------------------
reset_env_local
env -u HARNESS_IMPL_BACKEND bash "$SET" claude >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" claude >/dev/null
count="$(grep -cE "^export HARNESS_IMPL_BACKEND=" "${HARNESS_ENV_LOCAL}")"
[ "$count" = "1" ] || fail "(f) idempotent set should keep 1 line, got $count"

# ---------------------------------------------------------------------------
# (g) --unset removes the setting
# ---------------------------------------------------------------------------
reset_env_local
env -u HARNESS_IMPL_BACKEND bash "$SET" claude >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" --unset >/dev/null
count="$(grep -cE "^export HARNESS_IMPL_BACKEND=" "${HARNESS_ENV_LOCAL}" || true)"
[ "$count" = "0" ] || fail "(g) --unset should remove the line, got $count"
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(g) after unset resolve should default to claude, got '$got'"

# ---------------------------------------------------------------------------
# (h) passing an invalid argument to set-impl-backend exits non-zero
# ---------------------------------------------------------------------------
reset_env_local
if env -u HARNESS_IMPL_BACKEND bash "$SET" bogus >/dev/null 2>&1; then
  fail "(h) invalid arg should exit non-zero"
fi

# ---------------------------------------------------------------------------
# Additional: --show displays the resolved result
# ---------------------------------------------------------------------------
reset_env_local
env -u HARNESS_IMPL_BACKEND bash "$SET" claude >/dev/null
got="$(env -u HARNESS_IMPL_BACKEND bash "$SET" --show)"
[ "$got" = "claude" ] || fail "(--show) should print resolved backend, got '$got'"

# ---------------------------------------------------------------------------
# Additional: an invalid file value warns and falls back to claude
# ---------------------------------------------------------------------------
reset_env_local
printf 'export HARNESS_IMPL_BACKEND=bogus\n' > "${HARNESS_ENV_LOCAL}"
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE" 2>/dev/null)"
[ "$got" = "claude" ] || fail "(invalid-file) should fall back to claude, got '$got'"
got="$(HARNESS_IMPL_BACKEND=bogus bash "$RESOLVE" 2>/dev/null)"
[ "$got" = "claude" ] || fail "(invalid-env) should fall back to claude, got '$got'"

# ---------------------------------------------------------------------------
# User scope (--user / HARNESS_USER_BACKEND_FILE)
# ---------------------------------------------------------------------------
reset_user() { rm -f "${HARNESS_USER_BACKEND_FILE}"; }

# (i) use the user file value when project / env / flag are absent
reset_env_local; reset_user
env -u HARNESS_IMPL_BACKEND bash "$SET" --user claude >/dev/null
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(i) user-scope value should be used, got '$got'"
grep -qE "^export HARNESS_IMPL_BACKEND=claude$" "${HARNESS_USER_BACKEND_FILE}" \
  || fail "(i) user file should contain the export line"

# (l) --unset --user removes only the user file (does not touch project)
reset_env_local; reset_user
env -u HARNESS_IMPL_BACKEND bash "$SET" claude >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" --user claude >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" --unset --user >/dev/null
ucount="$(grep -cE "^export HARNESS_IMPL_BACKEND=" "${HARNESS_USER_BACKEND_FILE}" 2>/dev/null || true)"
[ "$ucount" = "0" ] || fail "(l) --unset --user should clear user file, got $ucount"
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(l) project setting should survive user unset, got '$got'"

echo "ok"
