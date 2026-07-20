#!/usr/bin/env bash
# resolve-impl-backend.sh
# Resolve the implementation backend (claude) by priority and print one line to stdout.
#
# Usage:
#   bash scripts/resolve-impl-backend.sh [--backend <v>] [--role <role>] [--default <v>]
#
# Priority (highest first):
#   1. --backend <v> flag
#   2. HARNESS_IMPL_BACKEND environment variable
#   3. the `^export HARNESS_IMPL_BACKEND=` line in ${REPO_ROOT}/env.local (project scope)
#   4. the same line in ${HOME}/.config/claude-harness/impl-backend.env (user scope, shared across all projects)
#   5. default value (claude; special local callers can override with --default <v>)
#
# Validity:
#   - the resolved value must be one of {claude}
#   - if the env / file value is invalid, warn to stderr and fall back to claude
#   - if an invalid value is passed to --backend / --default, exit with error (exit 2)
#
# --role:
#   - accepted for forward compatibility, but currently does not affect resolution (reserved)
#
# --default:
#   - default used only when flag / env / project file / user file are all unset.
#   - the distributed plugin's normal workflow does not set it, for opt-in compatibility.
#
# Test overrides:
#   - if HARNESS_ENV_LOCAL is set, use it as the env.local (project) path
#   - if HARNESS_USER_BACKEND_FILE is set, use it as the user-scope file path
#     (instead of ${HOME}/.config/claude-harness/impl-backend.env). Keeps tests from touching real files.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))"
ENV_LOCAL="${HARNESS_ENV_LOCAL:-${REPO_ROOT}/env.local}"
USER_FILE="${HARNESS_USER_BACKEND_FILE:-${HOME}/.config/claude-harness/impl-backend.env}"
KEY="HARNESS_IMPL_BACKEND"
DEFAULT="claude"

# Determine whether the value is valid
is_valid_backend() {
  case "$1" in
    claude) return 0 ;;
    *) return 1 ;;
  esac
}

flag_backend=""
# shellcheck disable=SC2034  # role is reserved for forward-compat; not yet used in resolution
role=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --backend)
      flag_backend="${2:-}"
      shift 2
      ;;
    --role)
      role="${2:-}"
      shift 2
      ;;
    --default)
      DEFAULT="${2:-}"
      if ! is_valid_backend "${DEFAULT}"; then
        echo "[resolve-impl-backend] invalid --default value: '${DEFAULT}' (specify claude)" >&2
        exit 2
      fi
      shift 2
      ;;
    *)
      echo "[resolve-impl-backend] unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# 1. --backend flag (invalid value exits with error)
if [ -n "${flag_backend}" ]; then
  if is_valid_backend "${flag_backend}"; then
    echo "${flag_backend}"
    exit 0
  fi
  echo "[resolve-impl-backend] invalid --backend value: '${flag_backend}' (specify claude)" >&2
  exit 2
fi

# 2. environment variable (invalid value warns and falls back to claude)
if [ -n "${HARNESS_IMPL_BACKEND:-}" ]; then
  if is_valid_backend "${HARNESS_IMPL_BACKEND}"; then
    echo "${HARNESS_IMPL_BACKEND}"
    exit 0
  fi
  echo "[resolve-impl-backend] Warning: environment variable ${KEY}='${HARNESS_IMPL_BACKEND}' is invalid. Falling back to 'claude'." >&2
  echo "claude"
  exit 0
fi

# 3. env.local config line (invalid value warns and falls back to claude)
if [ -f "${ENV_LOCAL}" ]; then
  file_line="$(grep -E "^export ${KEY}=" "${ENV_LOCAL}" 2>/dev/null | tail -1 || true)"
  if [ -n "${file_line}" ]; then
    file_value="${file_line#export "${KEY}"=}"
    if is_valid_backend "${file_value}"; then
      echo "${file_value}"
      exit 0
    fi
    echo "[resolve-impl-backend] Warning: ${KEY}='${file_value}' in ${ENV_LOCAL} is invalid. Falling back to 'claude'." >&2
    echo "claude"
    exit 0
  fi
fi

# 4. user-scope file (shared across all projects; invalid value warns and falls back to claude)
if [ -f "${USER_FILE}" ]; then
  user_line="$(grep -E "^export ${KEY}=" "${USER_FILE}" 2>/dev/null | tail -1 || true)"
  if [ -n "${user_line}" ]; then
    user_value="${user_line#export "${KEY}"=}"
    if is_valid_backend "${user_value}"; then
      echo "${user_value}"
      exit 0
    fi
    echo "[resolve-impl-backend] Warning: ${KEY}='${user_value}' in ${USER_FILE} is invalid. Falling back to 'claude'." >&2
    echo "claude"
    exit 0
  fi
fi

# 5. default value
echo "${DEFAULT}"
