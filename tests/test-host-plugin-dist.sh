#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="${ROOT_DIR}/scripts/build-host-plugin-dist.sh"

fail() {
  echo "test-host-plugin-dist: FAIL: $1" >&2
  exit 1
}

[ -x "$BUILD_SCRIPT" ] || chmod +x "$BUILD_SCRIPT"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

build_host() {
  local host="$1"
  local out="${TMP_ROOT}/${host}"
  bash "$BUILD_SCRIPT" --host "$host" --out "$out"
  printf '%s\n' "$out"
}

assert_absent() {
  local base="$1"
  local rel="$2"
  if [ -e "${base}/${rel}" ]; then
    fail "${base} must not contain ${rel}"
  fi
}

assert_present() {
  local base="$1"
  local rel="$2"
  if [ ! -e "${base}/${rel}" ]; then
    fail "${base} missing ${rel}"
  fi
}

assert_manifest_no_parent_paths() {
  local manifest="$1"
  if grep -Fq '../' "$manifest"; then
    fail "${manifest} contains .. paths"
  fi
}

CLAUDE_OUT="$(build_host claude)"

assert_present "$CLAUDE_OUT" ".claude-plugin/plugin.json"
assert_present "$CLAUDE_OUT" "skills/harness-work/SKILL.md"

assert_manifest_no_parent_paths "${CLAUDE_OUT}/.claude-plugin/plugin.json"

# Claude dist must preserve the original slash-command contract.
if ! grep -Eq '^user-invocable:[[:space:]]*true[[:space:]]*$' "${CLAUDE_OUT}/skills/breezing/SKILL.md"; then
  fail "claude dist breezing skill must keep user-invocable: true"
fi

echo "test-host-plugin-dist: ok"
