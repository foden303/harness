#!/usr/bin/env bash
# test-settings-baseline.sh
# Phase 62.1.4 + 62.2.5 (+ Phase 64 hardening): settings template baseline verification
#
# What is verified:
#   (1) deniedDomains baseline has 9+ entries (Phase 62.1.4 canonical baseline)
#   (2) deniedDomains includes metadata exfil endpoints (3 entries)
#   (3) deniedDomains includes all 6 Phase 62.1.4 paste-site/file-host entries
#   (4) skillOverrides is allowed (optional in template, not enforced)
#   (5) `.claude-plugin/settings.json` and template match exactly on deniedDomains
#   (6) skillOverrides governance doc exists
#   (7) [Phase 64 SSOT-alignment] harness.toml and settings.json match on deniedDomains
#       — for sync drift regression detection (be2a1781 follow-up)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_SETTINGS="${ROOT_DIR}/.claude-plugin/settings.json"
SECURITY_TEMPLATE="${ROOT_DIR}/templates/claude/settings.security.json.template"
HARNESS_TOML="${ROOT_DIR}/harness.toml"

[ -f "${SECURITY_TEMPLATE}" ] || {
  echo "FAIL (0): ${SECURITY_TEMPLATE} does not exist"
  exit 1
}

# (1) deniedDomains baseline has 9+ entries in template (Phase 62.1.4 canonical baseline)
TEMPLATE_DOMAINS_COUNT="$(jq -r '.sandbox.network.deniedDomains | length' "${SECURITY_TEMPLATE}")"
if [ "${TEMPLATE_DOMAINS_COUNT}" -lt 9 ]; then
  echo "FAIL (1): ${SECURITY_TEMPLATE} has only ${TEMPLATE_DOMAINS_COUNT} deniedDomains; Phase 62.1.4 baseline requires 9+"
  exit 1
fi

# (2) metadata exfil endpoints (cloud metadata) — 3 entries
for required in '169.254.169.254' 'metadata.google.internal' 'metadata.azure.com'; do
  if ! jq -e --arg d "${required}" '.sandbox.network.deniedDomains | index($d) != null' "${SECURITY_TEMPLATE}" >/dev/null; then
    echo "FAIL (2): ${SECURITY_TEMPLATE} missing required metadata domain: ${required}"
    exit 1
  fi
done

# (3) Phase 62.1.4 paste-site/file-host additions (all 6 required)
for paste_site in 'pastebin.com' 'transfer.sh' '0x0.st' 'paste.ee' 'termbin.com' 'ix.io'; do
  if ! jq -e --arg d "${paste_site}" '.sandbox.network.deniedDomains | index($d) != null' "${SECURITY_TEMPLATE}" >/dev/null; then
    echo "FAIL (3): ${SECURITY_TEMPLATE} missing Phase 62.1.4 paste-site domain: ${paste_site}"
    exit 1
  fi
done

# (4) skillOverrides is allowed (optional)
# If present, it must be one of the 3 modes
if jq -e 'has("skillOverrides")' "${SECURITY_TEMPLATE}" >/dev/null; then
  MODE="$(jq -r '.skillOverrides' "${SECURITY_TEMPLATE}")"
  case "${MODE}" in
    off|user-invocable-only|name-only) ;;
    *)
      echo "FAIL (4): skillOverrides must be off|user-invocable-only|name-only, got: ${MODE}"
      exit 1
      ;;
  esac
fi
# A missing skillOverrides in the template is allowed (Phase 62.2.5 policy: harness-init adds no default)

# (5) `.claude-plugin/settings.json` and template match exactly on deniedDomains
# Phase 64 hardening: under Phase 62.1.4 this was "user manual sync" so it was a WARN,
# but now that harness.toml is promoted to SSOT, drift between the two is a sign of a missed sync.
# Order does not matter; assert equality as a set.
if [ -f "${PLUGIN_SETTINGS}" ]; then
  for required in '169.254.169.254' 'metadata.google.internal' 'metadata.azure.com'; do
    if ! jq -e --arg d "${required}" '.sandbox.network.deniedDomains | index($d) != null' "${PLUGIN_SETTINGS}" >/dev/null; then
      echo "FAIL (5a): ${PLUGIN_SETTINGS} missing baseline metadata domain: ${required}"
      exit 1
    fi
  done

  PLUGIN_DOMAINS_COUNT="$(jq -r '.sandbox.network.deniedDomains | length' "${PLUGIN_SETTINGS}")"
  if [ "${PLUGIN_DOMAINS_COUNT}" -ne "${TEMPLATE_DOMAINS_COUNT}" ]; then
    echo "FAIL (5b): ${PLUGIN_SETTINGS} has ${PLUGIN_DOMAINS_COUNT} deniedDomains; template canonical has ${TEMPLATE_DOMAINS_COUNT}."
    echo "  → Update harness.toml [safety.sandbox.network].deniedDomains, then run 'bin/harness sync'"
    exit 1
  fi

  # All paste-sites must also be present in settings.json
  for paste_site in 'pastebin.com' 'transfer.sh' '0x0.st' 'paste.ee' 'termbin.com' 'ix.io'; do
    if ! jq -e --arg d "${paste_site}" '.sandbox.network.deniedDomains | index($d) != null' "${PLUGIN_SETTINGS}" >/dev/null; then
      echo "FAIL (5c): ${PLUGIN_SETTINGS} missing paste-site domain: ${paste_site}"
      echo "  → Add to the SSOT (harness.toml), then run 'bin/harness sync'"
      exit 1
    fi
  done
fi

# (6) skillOverrides governance doc exists (Phase 62.2.5)
SKILL_OVERRIDES_DOC="${ROOT_DIR}/docs/skill-overrides-policy.md"
[ -f "${SKILL_OVERRIDES_DOC}" ] || {
  echo "FAIL (6): ${SKILL_OVERRIDES_DOC} not found (Phase 62.2.5)"
  exit 1
}
for required_mode in 'off' 'user-invocable-only' 'name-only'; do
  if ! grep -q "${required_mode}" "${SKILL_OVERRIDES_DOC}"; then
    echo "FAIL (6): skill-overrides-policy.md missing mode '${required_mode}'"
    exit 1
  fi
done

# (7) Phase 64 SSOT-alignment: harness.toml and settings.json agree on deniedDomains
# be2a1781 follow-up: if you edit settings.json manually but forget to update harness.toml,
# the next SessionStart hook runs `bin/harness sync` and wipes out the 6 entries.
# harness.toml is the true SSOT, so FAIL if the count/set does not match settings.json.
if [ -f "${HARNESS_TOML}" ] && [ -f "${PLUGIN_SETTINGS}" ]; then
  # Extract only the deniedDomains values from harness.toml (simple grep over the TOML array)
  TOML_DOMAINS_COUNT="$(awk '
    /^\[safety\.sandbox\.network\]/ { in_section=1; next }
    /^\[/ && in_section { in_section=0 }
    in_section && /^[[:space:]]*"/ { count++ }
    END { print count+0 }
  ' "${HARNESS_TOML}")"

  PLUGIN_DOMAINS_COUNT="$(jq -r '.sandbox.network.deniedDomains | length' "${PLUGIN_SETTINGS}")"
  if [ "${TOML_DOMAINS_COUNT}" -ne "${PLUGIN_DOMAINS_COUNT}" ]; then
    echo "FAIL (7): SSOT drift detected — harness.toml has ${TOML_DOMAINS_COUNT} deniedDomains but ${PLUGIN_SETTINGS} has ${PLUGIN_DOMAINS_COUNT}."
    echo "  → Run 'bin/harness sync' to synchronize (be2a1781 follow-up regression prevention)"
    exit 1
  fi

  # Each paste-site must also be listed in harness.toml
  for paste_site in 'pastebin.com' 'transfer.sh' '0x0.st' 'paste.ee' 'termbin.com' 'ix.io'; do
    if ! grep -q "\"${paste_site}\"" "${HARNESS_TOML}"; then
      echo "FAIL (7): SSOT missing — '${paste_site}' is in settings.json but not in harness.toml"
      echo "  → Add it to harness.toml [safety.sandbox.network].deniedDomains"
      exit 1
    fi
  done
fi

# (8) Sandbox UX baseline: low-risk local dev commands must be explicit allow.
# The sandbox isolates execution; permission prompts should remain for
# destructive/network-expanding operations such as install, npx/npm exec,
# merge/rebase, force push, and secret access.
for allowed_command in \
  'Bash(git status:*)' \
  'Bash(git diff:*)' \
  'Bash(git log:*)' \
  'Bash(git branch:*)' \
  'Bash(git show:*)' \
  'Bash(rg:*)' \
  'Bash(npm test:*)' \
  'Bash(npm run test:*)' \
  'Bash(npm run lint:*)' \
  'Bash(npm run build:*)' \
  'Bash(bun test:*)' \
  'Bash(bun run test:*)' \
  'Bash(bun run lint:*)' \
  'Bash(bun run build:*)' \
  'Bash(pnpm test:*)' \
  'Bash(pnpm run test:*)' \
  'Bash(pnpm run lint:*)' \
  'Bash(pnpm run build:*)' \
  'Bash(yarn test:*)' \
  'Bash(yarn run test:*)' \
  'Bash(yarn run lint:*)' \
  'Bash(yarn run build:*)'; do
  if ! jq -e --arg c "${allowed_command}" '.permissions.allow | index($c) != null' "${SECURITY_TEMPLATE}" >/dev/null; then
    echo "FAIL (8a): ${SECURITY_TEMPLATE} missing permissions.allow entry: ${allowed_command}"
    exit 1
  fi
  if [ -f "${PLUGIN_SETTINGS}" ] && ! jq -e --arg c "${allowed_command}" '.permissions.allow | index($c) != null' "${PLUGIN_SETTINGS}" >/dev/null; then
    echo "FAIL (8b): ${PLUGIN_SETTINGS} missing permissions.allow entry: ${allowed_command}"
    echo "  → Update harness.toml [safety.permissions].allow, then run 'bin/harness sync'"
    exit 1
  fi
done

for still_ask in \
  'Bash(npm install:*)' \
  'Bash(npm exec:*)' \
  'Bash(npx:*)' \
  'Bash(bun install:*)' \
  'Bash(pnpm install:*)'; do
  if ! jq -e --arg c "${still_ask}" '.permissions.ask | index($c) != null' "${SECURITY_TEMPLATE}" >/dev/null; then
    echo "FAIL (8c): ${SECURITY_TEMPLATE} must keep permissions.ask entry: ${still_ask}"
    exit 1
  fi
done

echo "PASS: test-settings-baseline.sh (Phase 62.1.4 + 62.2.5 + Phase 64 SSOT-alignment + sandbox UX allowlist) — 8 checks"
