#!/usr/bin/env bash
# enable-1h-cache.sh
# Appends ENABLE_PROMPT_CACHING_1H=1 to env.local (idempotent).
# Script to opt into CC v2.1.108+ 1-hour prompt cache for long Harness sessions.
#
# Usage:
#   bash scripts/enable-1h-cache.sh
#
# Effects:
#   - Appends ENABLE_PROMPT_CACHING_1H=1 to env.local at the project root
#   - Does nothing if already set (idempotent)
#   - Creates env.local if it does not exist
#
# Selection criteria:
#   - Choose the 1h cache if a session is likely to exceed 30 minutes
#   - The default 5-minute cache is enough for short exchanges under 30 minutes
#
# Notes:
#   - Do not commit env.local to the repository (recommend adding to .gitignore)
#   - Does not change global settings; applies only to this project's sessions

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$(dirname "$0")/.." && pwd)")"
ENV_LOCAL="${REPO_ROOT}/env.local"
KEY="ENABLE_PROMPT_CACHING_1H"
VALUE="1"
# Use `export KEY=VALUE` so that `source env.local` propagates the variable
# to subprocesses (claude). Without `export`, `source env.local` only sets a
# shell-local variable and the spawned `claude` process never sees it.
ENTRY="export ${KEY}=${VALUE}"

# Check whether an active setting line already exists (ignore comment lines)
if grep -qE "^export ${KEY}=${VALUE}$" "${ENV_LOCAL}" 2>/dev/null; then
  echo "[enable-1h-cache] ${ENTRY} is already set in ${ENV_LOCAL} (no change)."
  exit 0
fi

# If the existing file has the same key with a different value, warn and exit without overwriting
if grep -qE "^(export )?${KEY}=" "${ENV_LOCAL}" 2>/dev/null; then
  existing_val=$(grep -E "^(export )?${KEY}=" "${ENV_LOCAL}" | tail -1)
  echo "[enable-1h-cache] Warning: ${ENV_LOCAL} already has an existing setting '${existing_val}'." >&2
  echo "[enable-1h-cache] Check it manually, then run again." >&2
  exit 1
fi

# Append to env.local (create it if it does not exist)
{
  echo ""
  echo "# CC v2.1.108+ 1-hour prompt cache (recommended for sessions over 30 minutes)"
  echo "${ENTRY}"
} >> "${ENV_LOCAL}"

echo "[enable-1h-cache] Appended ${ENTRY} to ${ENV_LOCAL}."
echo "[enable-1h-cache] It takes effect from your next long session (over 30 minutes)."
