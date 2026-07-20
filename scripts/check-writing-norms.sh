#!/usr/bin/env bash
# check-writing-norms.sh — HOTL Phase 101 U6 (Plans.md 101.7) pilot gate.
#
# Deterministic prose gate: scans the public doc surface for the
# §7 "LLM-ish banned phrase" deterministic subset of the writing-norms standard
# (k16shikano). Any hit → exit 1. This is the first end-to-end Authority
# Provenance Graph instance: rule (§7 banned phrases) ↔ check (this scanner) ↔
# execution (exit code). LLM-advisory rules, hedges and the em-dash preference
# are intentionally NOT gated (see spec.md §HOTL Governance Contract).
#
# Scope: the public README surface.
# Usage:
#   scripts/check-writing-norms.sh [file ...]
# With no args it scans the default surface (README.md).
set -euo pipefail

# §7 deterministic banned-phrase subset.
# Japanese-input support has been dropped, so the banned-phrase list is empty.
# The scanner remains wired so that new (English) banned phrases can be added here.
BANNED=(
  "delve"
  "seamlessly"
  "effortlessly"
  "revolutionary"
  "game-changer"
  "game changer"
  "cutting-edge"
  "unleash"
  "supercharge"
  "blazingly fast"
)

repo_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    cd "$(dirname "$0")/.." && pwd
  fi
}

# Resolve target files. Args override the default surface.
if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  ROOT="$(repo_root)"
  FILES=("$ROOT/README.md")
fi

hits=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue   # missing optional surface file is not a failure
  for phrase in ${BANNED[@]+"${BANNED[@]}"}; do
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      echo "VIOLATION: ${f}:${line} contains banned phrase \"${phrase}\""
      hits=$((hits + 1))
    done < <(grep -Fn -- "$phrase" "$f" | cut -d: -f1)
  done
done

if [ "$hits" -gt 0 ]; then
  echo "writing-norms gate: FAIL (${hits} banned-phrase hit(s) on README surface)"
  exit 1
fi

echo "writing-norms gate: ok (0 banned-phrase hits on README surface)"
exit 0
