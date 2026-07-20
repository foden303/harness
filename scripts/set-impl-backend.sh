#!/usr/bin/env bash
# set-impl-backend.sh
# Persist the implementation backend (claude) to env.local (idempotent).
#
# Usage:
#   bash scripts/set-impl-backend.sh claude            # Project scope (env.local)
#   bash scripts/set-impl-backend.sh --user claude     # User scope (shared across all projects)
#   bash scripts/set-impl-backend.sh --show                           # Show the currently resolved backend
#   bash scripts/set-impl-backend.sh --unset [--user]                 # Remove the setting (default: project)
#
# Effect:
#   - Writes `export HARNESS_IMPL_BACKEND=<value>` to the target file (idempotent)
#     - Default (project): ${REPO_ROOT}/env.local
#     - With --user (user): ${HOME}/.config/claude-harness/impl-backend.env
#   - Does nothing if the value already matches. If different, replaces in-place (leaves no duplicate lines). Creates the file if missing.
#
# Scope and precedence:
#   - Project env.local takes precedence over user scope (see precedence in resolve-impl-backend.sh)
#   - User scope acts as the shared default across all projects
#
# Note:
#   - env.local / user file must not be committed to the repository
#
# Test overrides:
#   - HARNESS_ENV_LOCAL: override the path of env.local (project)
#   - HARNESS_USER_BACKEND_FILE: override the path of the user-scope file

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_LOCAL="${HARNESS_ENV_LOCAL:-${REPO_ROOT}/env.local}"
USER_FILE="${HARNESS_USER_BACKEND_FILE:-${HOME}/.config/claude-harness/impl-backend.env}"
KEY="HARNESS_IMPL_BACKEND"

usage() {
  echo "Usage: $0 claude [--user] | --show | --unset [--user]" >&2
}

# Determine whether the value is valid
is_valid_backend() {
  case "$1" in
    claude) return 0 ;;
    *) return 1 ;;
  esac
}

# Parse arguments: --user scope flag + action (value | --show | --unset)
use_user=0
action=""
VALUE=""
for arg in "$@"; do
  case "$arg" in
    --user) use_user=1 ;;
    --show) action="show" ;;
    --unset) action="unset" ;;
    claude) action="set"; VALUE="$arg" ;;
    *)
      echo "[set-impl-backend] Unknown argument: ${arg}" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "${action}" ]; then
  usage
  exit 2
fi

# Decide the target file from the scope
if [ "${use_user}" = "1" ]; then
  TARGET="${USER_FILE}"
  SCOPE="user"
else
  TARGET="${ENV_LOCAL}"
  SCOPE="project"
fi

case "${action}" in
  show)
    # Delegate to resolve-impl-backend.sh to show the currently resolved backend
    exec bash "${SCRIPT_DIR}/resolve-impl-backend.sh"
    ;;
  unset)
    if [ -f "${TARGET}" ] && grep -qE "^export ${KEY}=" "${TARGET}" 2>/dev/null; then
      tmp_file="$(mktemp "${TARGET}.XXXXXX")"
      grep -vE "^export ${KEY}=" "${TARGET}" > "${tmp_file}" || true
      mv "${tmp_file}" "${TARGET}"
      echo "[set-impl-backend] Removed ${KEY} from ${TARGET} (${SCOPE} scope)."
    else
      echo "[set-impl-backend] ${KEY} is not set in ${TARGET} (${SCOPE} scope) (no change)."
    fi
    exit 0
    ;;
esac

# action=set: ensure the target file's parent directory exists (for the user file)
mkdir -p "$(dirname "${TARGET}")"
if ! is_valid_backend "${VALUE}"; then
  echo "[set-impl-backend] Invalid value: '${VALUE}' (specify claude)" >&2
  exit 2
fi

# Use `export KEY=VALUE` so that `source env.local` propagates the variable
# to subprocesses. Without `export`, `source env.local` only sets a
# shell-local variable and spawned processes never see it.
ENTRY="export ${KEY}=${VALUE}"

# Check whether a setting line with the same value already exists (idempotent)
if grep -qE "^export ${KEY}=${VALUE}$" "${TARGET}" 2>/dev/null; then
  echo "[set-impl-backend] ${ENTRY} is already set in ${TARGET} (${SCOPE} scope) (no change)."
  exit 0
fi

# If an existing setting line (with a different value) exists, replace it in-place, leaving no duplicates
if grep -qE "^export ${KEY}=" "${TARGET}" 2>/dev/null; then
  # Create the temp file in the same directory as the target to keep mv atomic
  tmp_file="$(mktemp "${TARGET}.XXXXXX")"
  # Replace the existing setting line with the new value. Substitute only the first line with ENTRY and remove the rest.
  awk -v entry="${ENTRY}" -v key="export ${KEY}=" '
    index($0, key) == 1 {
      if (!replaced) { print entry; replaced = 1 }
      next
    }
    { print }
  ' "${TARGET}" > "${tmp_file}"
  mv "${tmp_file}" "${TARGET}"
  echo "[set-impl-backend] Updated ${KEY} to ${VALUE} in ${TARGET} (${SCOPE} scope)."
  exit 0
fi

# Append to the target file (create it if it does not exist)
{
  echo ""
  echo "# Persisted implementation backend selection (claude)"
  echo "${ENTRY}"
} >> "${TARGET}"

echo "[set-impl-backend] Appended ${ENTRY} to ${TARGET} (${SCOPE} scope)."
