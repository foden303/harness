#!/usr/bin/env bash
set -euo pipefail

# Launch Claude Code with 1-hour prompt cache for long-running tasks.
# A thin wrapper that keeps defaults unchanged and only opts in for sessions that need it.

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: 'claude' command not found." >&2
  echo "Install the Claude Code CLI and try again." >&2
  exit 1
fi

export ENABLE_PROMPT_CACHING_1H=1

exec claude "$@"
