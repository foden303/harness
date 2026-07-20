#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "test-readme-product-surface: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "unexpected '$needle' in $file"
  fi
}

for file in "$ROOT_DIR/README.md"; do
  [ -f "$file" ] || fail "missing $file"
  assert_contains "$file" "docs/onboarding/index.md"
  assert_contains "$file" "docs/onboarding/migration.md"
  assert_contains "$file" "docs/onboarding/skill-trigger-acceptance.md"
  assert_contains "$file" "Claude Code | \`supported\`"
  # One supported host, stated as such, with no tier granted to any other.
  assert_not_contains "$file" "GitHub Copilot CLI"
  assert_not_contains "$file" "Antigravity CLI"
  # Diagrams are markdown (mermaid), never committed image files: the pre-1.0
  # hero PNG was deleted while README still linked it, and a path-string
  # assertion could not tell the difference.
  assert_contains "$file" '```mermaid'
  assert_not_contains "$file" "docs/images/"
  assert_not_contains "$file" "Hokage"
  assert_not_contains "$file" "v4.2"
  assert_not_contains "$file" "v4.0"
  assert_not_contains "$file" "docs/images/hokage/hokage-hero.jpg"
  assert_not_contains "$file" "only setup"
done

assert_contains "$ROOT_DIR/README.md" "## Quickstart"
assert_contains "$ROOT_DIR/README.md" "## Install in 30 Seconds"
assert_contains "$ROOT_DIR/README.md" "## First 15 Minutes"
assert_contains "$ROOT_DIR/README.md" "## How It Works"
assert_contains "$ROOT_DIR/README.md" "## Commands"
assert_contains "$ROOT_DIR/README.md" "What happens inside"
assert_contains "$ROOT_DIR/README.md" "## Basic Workflow"
assert_contains "$ROOT_DIR/README.md" "## Install By Tool"
assert_contains "$ROOT_DIR/README.md" "## Existing User Migration"
assert_contains "$ROOT_DIR/README.md" "## Support Boundary"
assert_contains "$ROOT_DIR/README.md" "## Advanced"
assert_contains "$ROOT_DIR/README.md" "## Documentation"
assert_contains "$ROOT_DIR/README.md" "Your job is not to hand-write the plan"
assert_contains "$ROOT_DIR/README.md" "run \`/harness-plan\` with one small request"
assert_contains "$ROOT_DIR/README.md" "Harness writes the \`spec.md\` and"
assert_contains "$ROOT_DIR/README.md" "Run the smallest approved task"

echo "test-readme-product-surface: ok"
