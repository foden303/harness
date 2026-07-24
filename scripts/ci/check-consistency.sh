#!/bin/bash
# check-consistency.sh
# Plugin consistency check
#
# Usage: ./scripts/ci/check-consistency.sh
# Exit codes:
#   0 - All checks passed
#   1 - Inconsistencies found

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=0

echo "🔍 harness consistency check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ================================
# 1. Verify existence of template files
# ================================
echo ""
echo "📁 [1/20] Verifying template files exist..."

REQUIRED_TEMPLATES=(
  "templates/AGENTS.md.template"
  "templates/CLAUDE.md.template"
  "templates/Plans.md.template"
  "templates/.harness-version.template"
  "templates/.harness.config.yaml.template"
  "templates/claude/settings.security.json.template"
  "templates/claude/settings.local.json.template"
  "templates/rules/workflow.md.template"
  "templates/rules/coding-standards.md.template"
  "templates/rules/plans-management.md.template"
  "templates/rules/testing.md.template"
  "templates/rules/ui-debugging-agent-browser.md.template"
)

for template in "${REQUIRED_TEMPLATES[@]}"; do
  if [ ! -f "$PLUGIN_ROOT/$template" ]; then
    echo "  ❌ Missing: $template"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ $template"
  fi
done

# ================================
# 2. Command <-> skill consistency
# ================================
echo ""
echo "🔗 [2/20] Command ↔ skill reference consistency..."

# Check whether templates referenced by commands exist
check_command_references() {
  local cmd_file="$1"
  local cmd_name=$(basename "$cmd_file" .md)

  # Extract references to templates
  local refs=$(grep -oE 'templates/[a-zA-Z0-9/_.-]+' "$cmd_file" 2>/dev/null || true)

  for ref in $refs; do
    if [ ! -e "$PLUGIN_ROOT/$ref" ] && [ ! -e "$PLUGIN_ROOT/${ref}.template" ]; then
      echo "  ❌ $cmd_name: reference target does not exist: $ref"
      ERRORS=$((ERRORS + 1))
    fi
  done
}

for cmd in "$PLUGIN_ROOT/commands"/*.md; do
  check_command_references "$cmd"
done
echo "  ✅ Command reference check complete"

# ================================
# 3. Version number consistency
# ================================
echo ""
echo "🏷️ [3/20] Version number consistency..."

VERSION_FILE="$PLUGIN_ROOT/VERSION"
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"

if [ -f "$VERSION_FILE" ] && [ -f "$PLUGIN_JSON" ]; then
  FILE_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  JSON_VERSION=$(grep '"version"' "$PLUGIN_JSON" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

  if [ "$FILE_VERSION" != "$JSON_VERSION" ]; then
    echo "  ❌ Version mismatch: VERSION=$FILE_VERSION, plugin.json=$JSON_VERSION"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ VERSION and plugin.json match: $FILE_VERSION"
  fi
fi

LATEST_RELEASE_URL="https://github.com/foden303/harness/releases/latest"
LATEST_RELEASE_BADGE="https://img.shields.io/github/v/release/foden303/harness?display_name=tag&sort=semver"

# ================================
# 4. Expected file structure of skills
# ================================
echo ""
echo "📋 [4/20] Expected file structure of skill definitions..."

# 2agent config has been merged into harness-setup
# Verify existence of skills/harness-setup/SKILL.md
SETUP_SKILL="$PLUGIN_ROOT/skills/harness-setup/SKILL.md"
if [ -f "$SETUP_SKILL" ]; then
  echo "  ✅ skills/harness-setup/SKILL.md exists (includes 2agent config)"
else
  echo "  ❌ skills/harness-setup/SKILL.md not found"
  ERRORS=$((ERRORS + 1))
fi

# ================================
# 5. Hooks configuration consistency
# ================================
echo ""
echo "🪝 [5/20] Hooks configuration consistency..."

HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_JSON" ]; then
  # Verify script references within hooks.json
  SCRIPT_REFS=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[a-zA-Z0-9_./-]+' "$HOOKS_JSON" 2>/dev/null || true)

  for ref in $SCRIPT_REFS; do
    script_name=$(echo "$ref" | sed 's|\${CLAUDE_PLUGIN_ROOT}/scripts/||')
    if [ ! -f "$PLUGIN_ROOT/scripts/$script_name" ]; then
      echo "  ❌ hooks.json: script does not exist: scripts/$script_name"
      ERRORS=$((ERRORS + 1))
    else
      echo "  ✅ scripts/$script_name"
    fi
  done
fi

# ================================
# 6. Regression check for retired /start-task
# ================================
echo ""
echo "🚫 [6/20] Regression check for retired /start-task..."

# Operational-path files (history such as CHANGELOG is excluded)
START_TASK_TARGETS=(
  "commands/"
  "skills/"
  "workflows/"
  "profiles/"
  "templates/"
  "scripts/"
  "DEVELOPMENT_FLOW_GUIDE.md"
  "IMPLEMENTATION_GUIDE.md"
  "README.md"
)

START_TASK_FOUND=0
for target in "${START_TASK_TARGETS[@]}"; do
  if [ -e "$PLUGIN_ROOT/$target" ]; then
    # Search for references to /start-task (history / explanatory context excluded)
    # Exclusion patterns: history / migration notes / CHANGELOG (matched by the English keywords below)
    REFS=$(grep -rn "/start-task" "$PLUGIN_ROOT/$target" 2>/dev/null \
      | grep -v "Removed" \
      | grep -v "CHANGELOG" \
      | grep -viE "removed|retired|absorb|replaced|migrated|legacy|deprecated|equivalent|consolidat" \
      | grep -v "check-consistency.sh" \
      || true)
    if [ -n "$REFS" ]; then
      echo "  ❌ /start-task reference remains: $target"
      sed -n '1,3p' <<<"$REFS" | sed 's/^/      /'
      START_TASK_FOUND=$((START_TASK_FOUND + 1))
    fi
  fi
done

if [ $START_TASK_FOUND -eq 0 ]; then
  echo "  ✅ No /start-task references (operational paths)"
else
  ERRORS=$((ERRORS + START_TASK_FOUND))
fi

# ================================
# 7. Regression check for docs/ normalization
# ================================
echo ""
echo "📁 [7/20] Regression check for docs/ normalization..."

# Check root-level references to proposal.md / priority_matrix.md
DOCS_TARGETS=(
  "commands/"
  "skills/"
)

DOCS_ISSUES=0
for target in "${DOCS_TARGETS[@]}"; do
  if [ -d "$PLUGIN_ROOT/$target" ]; then
    # Search for references to root-level proposal.md / technical-spec.md / priority_matrix.md
    # Detect ones lacking the docs/ prefix
    REFS=$(grep -rn "proposal.md\|technical-spec.md\|priority_matrix.md" "$PLUGIN_ROOT/$target" 2>/dev/null | grep -v "docs/" | grep -v "\.template" || true)
    if [ -n "$REFS" ]; then
      echo "  ❌ Reference without docs/ prefix: $target"
      sed -n '1,3p' <<<"$REFS" | sed 's/^/      /'
      DOCS_ISSUES=$((DOCS_ISSUES + 1))
    fi
  fi
done

if [ $DOCS_ISSUES -eq 0 ]; then
  echo "  ✅ docs/ normalization OK"
else
  ERRORS=$((ERRORS + DOCS_ISSUES))
fi

# ================================
# 8. Regression check for bypassPermissions-based operation
# ================================
echo ""
echo "🔓 [8/20] Regression check for bypassPermissions-based operation..."

BYPASS_ISSUES=0

# Check 1: disableBypassPermissionsMode has not returned to templates
SECURITY_TEMPLATE="$PLUGIN_ROOT/templates/claude/settings.security.json.template"
if [ -f "$SECURITY_TEMPLATE" ]; then
  if grep -q "disableBypassPermissionsMode" "$SECURITY_TEMPLATE"; then
    echo "  ❌ disableBypassPermissionsMode remains in settings.security.json.template"
    echo "      Under bypassPermissions-based operation, remove this setting"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ No disableBypassPermissionsMode"
  fi
fi

# Check 2: the permissions.ask section does not contain Edit / Write
# NOTE: Edit/Write in the deny section is legitimate as defense-in-depth. Only check ask.
if [ -f "$SECURITY_TEMPLATE" ]; then
  # Extract only the ask section and search for Edit/Write
  ASK_EDIT_WRITE=$(sed -n '/"ask"/,/\]/p' "$SECURITY_TEMPLATE" | grep -E '"(Edit|Write|MultiEdit)' || true)
  if [ -n "$ASK_EDIT_WRITE" ]; then
    echo "  ❌ settings.security.json.template ask section contains Edit/Write"
    echo "      Under bypassPermissions-based operation, do not put Edit/Write in ask"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ No Edit/Write in ask"
  fi
fi

# Check 2.5: Regression check for Bash permission syntax (prefix requires :*)
if [ -f "$SECURITY_TEMPLATE" ]; then
  # Portable regex: use [(] / [*] instead of escaping to avoid BSD grep issues.
  if grep -nEq 'Bash[(][^)]*[^:][*]' "$SECURITY_TEMPLATE"; then
    echo "  ❌ settings.security.json.template contains invalid Bash permission syntax"
    echo "      Use :* for prefix matching (e.g. Bash(git status:*))"
    grep -nE 'Bash[(][^)]*[^:][*]' "$SECURITY_TEMPLATE" | sed -n '1,3p' | sed 's/^/      /'
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ Bash permission syntax OK (:*)"
  fi
fi

# Check 3: settings.local.json.template exists and defaultMode is a documented permission mode
# NOTE: the shipped default keeps bypassPermissions; Auto Mode is treated as a follow-up rollout on the teammate execution path
LOCAL_TEMPLATE="$PLUGIN_ROOT/templates/claude/settings.local.json.template"
if [ -f "$LOCAL_TEMPLATE" ]; then
  if grep -q '"defaultMode"[[:space:]]*:[[:space:]]*"bypassPermissions"' "$LOCAL_TEMPLATE"; then
    mode_val=$(grep '"defaultMode"' "$LOCAL_TEMPLATE" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "  ✅ settings.local.json.template: defaultMode=${mode_val}"
  else
    echo "  ❌ settings.local.json.template missing defaultMode=bypassPermissions"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  fi
else
  echo "  ❌ settings.local.json.template does not exist"
  BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
fi

# Check 4: the managed sandbox precedence key is exclusive to managed settings.
# Mixing it into normally distributed harness.toml / plugin settings / templates
# makes the responsibility ambiguous vs Claude Code's own managed settings precedence.
MANAGED_SANDBOX_KEY_RE='allowManagedDomainsOnly|allowManagedReadPathsOnly'
MANAGED_SANDBOX_DEFAULT_TARGETS=(
  "$PLUGIN_ROOT/harness.toml"
  "$PLUGIN_ROOT/.claude-plugin/settings.json"
  "$PLUGIN_ROOT/templates/claude/settings.security.json.template"
  "$PLUGIN_ROOT/templates/sandbox-settings.json.template"
)
MANAGED_SANDBOX_ISSUES=0
for target in "${MANAGED_SANDBOX_DEFAULT_TARGETS[@]}"; do
  if [ ! -f "$target" ]; then
    continue
  fi
  FOUND_KEYS=$(grep -nE "$MANAGED_SANDBOX_KEY_RE" "$target" || true)
  if [ -n "$FOUND_KEYS" ]; then
    echo "  ❌ managed sandbox key should not be in a normal template/default: ${target#$PLUGIN_ROOT/}"
    sed -n '1,3p' <<<"$FOUND_KEYS" | sed 's/^/      /'
    MANAGED_SANDBOX_ISSUES=$((MANAGED_SANDBOX_ISSUES + 1))
  fi
done

if [ $MANAGED_SANDBOX_ISSUES -eq 0 ]; then
  echo "  ✅ managed sandbox key isolated to managed settings only"
else
  BYPASS_ISSUES=$((BYPASS_ISSUES + MANAGED_SANDBOX_ISSUES))
fi

if [ $BYPASS_ISSUES -eq 0 ]; then
  echo "  ✅ bypassPermissions-based operation OK"
else
  ERRORS=$((ERRORS + BYPASS_ISSUES))
fi

# ================================
# 9. Regression check for retired ccp-* skills
# ================================
echo ""
echo "🚫 [9/20] Regression check for retired ccp-* skills..."

CCP_ISSUES=0

# Check 1: no name: ccp- appears in skills
CCP_NAMES=$(grep -rn "^name: ccp-" "$PLUGIN_ROOT/skills/" 2>/dev/null || true)
if [ -n "$CCP_NAMES" ]; then
  echo "  ❌ name: ccp-* remains in skills"
  sed -n '1,3p' <<<"$CCP_NAMES" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ No name: ccp-* in skills"
fi

# Check 2: no skill: ccp- appears in workflows
CCP_WORKFLOWS=$(grep -rn "skill: ccp-" "$PLUGIN_ROOT/workflows/" 2>/dev/null || true)
if [ -n "$CCP_WORKFLOWS" ]; then
  echo "  ❌ skill: ccp-* remains in workflows"
  sed -n '1,3p' <<<"$CCP_WORKFLOWS" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ No skill: ccp-* in workflows"
fi

# Check 3: no ccp-* directory remains
CCP_DIRS=$(find "$PLUGIN_ROOT/skills" -type d -name "ccp-*" 2>/dev/null || true)
if [ -n "$CCP_DIRS" ]; then
  echo "  ❌ ccp-* directory remains"
  sed -n '1,3p' <<<"$CCP_DIRS" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ No ccp-* directory"
fi

if [ $CCP_ISSUES -eq 0 ]; then
  echo "  ✅ ccp-* skill retirement OK"
else
  ERRORS=$((ERRORS + CCP_ISSUES))
fi

# ================================
# 10. Skill Mirror check
# ================================
echo ""
echo "📦 [10/20] Skill mirror check..."

FULL_MIRROR_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-skill-mirrors.XXXXXX")"
if bash "$PLUGIN_ROOT/scripts/sync-skill-mirrors.sh" --check >"$FULL_MIRROR_LOG" 2>&1; then
  echo "  ✅ all shipped skill mirrors are in sync"
else
  echo "  ❌ full skill mirror check failed"
  sed 's/^/      /' "$FULL_MIRROR_LOG" | tail -80
  ERRORS=$((ERRORS + 1))
fi
rm -f "$FULL_MIRROR_LOG"

# ================================
# 10.5 Skill orchestration design contract
# ================================
echo ""
echo "🧭 [11/20] Skill orchestration design contract..."

SKILL_DESIGN_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-skill-design.XXXXXX")"
if bash "$PLUGIN_ROOT/tests/test-skill-design-contract.sh" >"$SKILL_DESIGN_LOG" 2>&1; then
  echo "  ✅ core skill design metadata is consistent"
else
  echo "  ❌ core skill design metadata check failed"
  sed 's/^/      /' "$SKILL_DESIGN_LOG" | tail -80
  ERRORS=$((ERRORS + 1))
fi
rm -f "$SKILL_DESIGN_LOG"

# ================================
# 10.6 Weak-supervision contract tests
# ================================
echo ""
echo "🧪 [12/20] Weak-supervision contract tests..."

WEAK_SUPERVISION_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-weak-supervision.XXXXXX")"
if bash "$PLUGIN_ROOT/tests/test-weak-supervision-report.sh" >"$WEAK_SUPERVISION_LOG" 2>&1; then
  echo "  ✅ weak-supervision report/schema fixtures pass"
else
  echo "  ❌ weak-supervision report/schema fixture check failed"
  sed 's/^/      /' "$WEAK_SUPERVISION_LOG" | tail -80
  ERRORS=$((ERRORS + 1))
fi
rm -f "$WEAK_SUPERVISION_LOG"

# ================================
# 11. CHANGELOG format validation
# ================================
echo ""
echo "📝 [13/20] CHANGELOG format validation..."

CHANGELOG_ISSUES=0

for changelog in "$PLUGIN_ROOT/CHANGELOG.md" "$PLUGIN_ROOT/CHANGELOG_ja.md"; do
  if [ ! -f "$changelog" ]; then
    continue
  fi

  cl_name=$(basename "$changelog")

  # Check 1: Keep a Changelog header (## [x.y.z] - YYYY-MM-DD format)
  BAD_DATES=$(grep -nE '^\#\# \[[0-9]' "$changelog" | grep -vE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | grep -v "Unreleased" || true)
  if [ -n "$BAD_DATES" ]; then
    echo "  ❌ $cl_name: entry with a non-ISO 8601 date"
    sed -n '1,3p' <<<"$BAD_DATES" | sed 's/^/      /'
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  fi

  # Check 2: non-standard section headings (other than the 6 in Keep a Changelog 1.1.0)
  NON_STANDARD=$(grep -nE '^\#\#\# ' "$changelog" \
    | grep -viE '(Added|Changed|Deprecated|Removed|Fixed|Security|What.*Changed)' \
    | grep -viE '(Internal|Breaking|Migration|Summary|Before)' \
    || true)
  if [ -n "$NON_STANDARD" ]; then
    echo "  ⚠️ $cl_name: non-standard section heading (review recommended)"
    sed -n '1,3p' <<<"$NON_STANDARD" | sed 's/^/      /'
    # Warning only (does not raise an error)
  fi

  # Check 3: whether an [Unreleased] section exists
  if ! grep -q '^\#\# \[Unreleased\]' "$changelog"; then
    echo "  ❌ $cl_name: missing [Unreleased] section"
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  fi
done

if [ $CHANGELOG_ISSUES -eq 0 ]; then
  echo "  ✅ CHANGELOG format OK"
else
  ERRORS=$((ERRORS + CHANGELOG_ISSUES))
fi

# ================================
# 12. README claim drift check
# ================================
echo ""
echo "📚 [14/20] README claim drift check..."

README_ISSUES=0
README_EN="$PLUGIN_ROOT/README.md"
SCOPE_DOC="$PLUGIN_ROOT/docs/distribution-scope.md"
RUBRIC_DOC="$PLUGIN_ROOT/docs/benchmark-rubric.md"
POSITIONING_DOC="$PLUGIN_ROOT/docs/positioning-notes.md"
WORK_ALL_DOC="$PLUGIN_ROOT/docs/evidence/work-all.md"

check_fixed_string() {
  local file_path="$1"
  local needle="$2"
  local label="$3"

  if [ ! -f "$file_path" ]; then
    echo "  ❌ ${label}: file does not exist: $file_path"
    README_ISSUES=$((README_ISSUES + 1))
    return
  fi

  if grep -qF "$needle" "$file_path"; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}: required string not found"
    README_ISSUES=$((README_ISSUES + 1))
  fi
}

check_absent_string() {
  local file_path="$1"
  local needle="$2"
  local label="$3"

  if [ ! -f "$file_path" ]; then
    echo "  ❌ ${label}: file does not exist: $file_path"
    README_ISSUES=$((README_ISSUES + 1))
    return
  fi

  if grep -qF "$needle" "$file_path"; then
    echo "  ❌ ${label}: stale claim remains"
    README_ISSUES=$((README_ISSUES + 1))
  else
    echo "  ✅ ${label}"
  fi
}

check_exists() {
  local file_path="$1"
  local label="$2"

  if [ -f "$file_path" ]; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}: file does not exist"
    README_ISSUES=$((README_ISSUES + 1))
  fi
}

check_fixed_string "$README_EN" "$LATEST_RELEASE_URL" "README.md latest release link"
check_fixed_string "$README_EN" "$LATEST_RELEASE_BADGE" "README.md latest release badge"

check_exists "$SCOPE_DOC" "distribution-scope.md"
check_exists "$RUBRIC_DOC" "benchmark-rubric.md"
check_exists "$POSITIONING_DOC" "positioning-notes.md"
check_exists "$WORK_ALL_DOC" "work-all evidence doc"

check_fixed_string "$README_EN" "docs/CLAUDE_CODE_COMPATIBILITY.md" "README.md compatibility doc link"
check_fixed_string "$README_EN" "docs/evidence/work-all.md" "README.md work-all evidence link"
check_fixed_string "$README_EN" "docs/distribution-scope.md" "README.md distribution scope link"
check_fixed_string "$README_EN" "5 verb skills" "README.md 5 verb skills message"
check_fixed_string "$README_EN" "Go-native guardrail engine" "README.md Go-native guardrail engine message"
check_absent_string "$README_EN" "Production-ready code." "README.md stale production-ready wording"

check_fixed_string "$SCOPE_DOC" '| `skills/` | Distribution-included |' "distribution-scope skills classification"
check_fixed_string "$SCOPE_DOC" '| `go/`, `tests/`, `.github/` | Development-only and distribution-excluded |' "distribution-scope dev-only classification"
# Guards: these directories were removed from the repo. If a row for one reappears,
# the table has drifted back to describing paths that do not exist.
check_absent_string "$SCOPE_DOC" '`commands/`' "distribution-scope stale commands row"
check_absent_string "$SCOPE_DOC" '`mcp-server/`' "distribution-scope stale mcp-server row"
check_absent_string "$SCOPE_DOC" '`benchmarks/`' "distribution-scope stale benchmarks row"
check_absent_string "$SCOPE_DOC" '`workflows/`' "distribution-scope stale workflows row"
check_fixed_string "$RUBRIC_DOC" "| Static evidence |" "benchmark-rubric static evidence"
check_fixed_string "$RUBRIC_DOC" "| Executed evidence |" "benchmark-rubric executed evidence"
check_fixed_string "$POSITIONING_DOC" "runtime enforcement" "positioning-notes runtime enforcement"

if [ $README_ISSUES -eq 0 ]; then
  echo "  ✅ README claim drift check OK"
else
  ERRORS=$((ERRORS + README_ISSUES))
fi

# ================================
# 15. Verify existence of the Shared File Discipline rule
# ================================
echo ""
echo "📜 [15/20] Verifying the Shared File Discipline rule exists..."

SHARED_FILE_DISCIPLINE="$PLUGIN_ROOT/.claude/rules/shared-file-discipline.md"

if [ ! -f "$SHARED_FILE_DISCIPLINE" ]; then
  echo "  ❌ Missing: .claude/rules/shared-file-discipline.md"
  echo "      Shared file editing rule for parallel worktrees (Phase 92.1.3)."
  echo "      See: docs/team-composition.md, spec.md Tri-Tool Contract"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✅ .claude/rules/shared-file-discipline.md"
  # Verify the 3 invariant key phrases are present in the rule body (prevent hollowing out)
  for phrase in \
    "owner-assigned append-only" \
    "VERSION" \
    "Do not bump \`VERSION\` inside a worktree" \
    "Regenerate generated artifacts once on the trunk"
  do
    if ! grep -qF "$phrase" "$SHARED_FILE_DISCIPLINE"; then
      echo "  ❌ shared-file-discipline.md missing required phrase: $phrase"
      ERRORS=$((ERRORS + 1))
    fi
  done
  if grep -q "owner-assigned append-only" "$SHARED_FILE_DISCIPLINE" \
    && grep -qF "Do not bump \`VERSION\` inside a worktree" "$SHARED_FILE_DISCIPLINE" \
    && grep -qF "Regenerate generated artifacts once on the trunk" "$SHARED_FILE_DISCIPLINE"; then
    echo "  ✅ 3 invariant key phrases verified OK"
  fi
fi

# ================================
# 16. Invariant for Reviewer cyber-safeguard relaxation
# ================================
echo ""
echo "🛡️ [16/20] Invariant for Reviewer cyber-safeguard relaxation..."

REVIEWER_AGENT="$PLUGIN_ROOT/agents/reviewer.md"
SECURITY_PROFILE="$PLUGIN_ROOT/skills/harness-review/references/security-profile.md"

# (a) reviewer.md must be pinned to a non-Fable model (prevents cyber-safeguard auto-switching via Fable inheritance)
if [ ! -f "$REVIEWER_AGENT" ]; then
  echo "  ❌ Missing: agents/reviewer.md"
  ERRORS=$((ERRORS + 1))
else
  REVIEWER_MODEL="$(grep -E '^model:' "$REVIEWER_AGENT" | head -1 | sed 's/^model:[[:space:]]*//')"
  if [ -z "$REVIEWER_MODEL" ]; then
    echo "  ❌ agents/reviewer.md has no model: pin (a non-Fable pin is required to prevent Fable inheritance)"
    ERRORS=$((ERRORS + 1))
  elif printf '%s' "$REVIEWER_MODEL" | grep -qiE 'fable|inherit'; then
    echo "  ❌ agents/reviewer.md model is Fable/inherit: $REVIEWER_MODEL"
    echo "      Pin to a fixed non-Fable model to avoid cyber-safeguard auto-switching"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ reviewer non-Fable model pin: $REVIEWER_MODEL"
  fi
fi

# (b) security-profile.md must contain the key phrases of the findings feedback contract (prevent hollowing out)
if [ ! -f "$SECURITY_PROFILE" ]; then
  echo "  ❌ Missing: skills/harness-review/references/security-profile.md"
  ERRORS=$((ERRORS + 1))
else
  for phrase in \
    "Contract for fresh-context isolation and findings return" \
    "Neutral return of findings" \
    "safeguard invariant"
  do
    if ! grep -q "$phrase" "$SECURITY_PROFILE"; then
      echo "  ❌ security-profile.md missing required phrase: $phrase"
      ERRORS=$((ERRORS + 1))
    fi
  done
  if grep -q "Contract for fresh-context isolation and findings return" "$SECURITY_PROFILE" \
    && grep -q "Neutral return of findings" "$SECURITY_PROFILE"; then
    echo "  ✅ findings return contract phrases OK"
  fi
fi

# ================================
# 17. Retired alias residue gate
# ================================
echo ""
echo "🧹 [17/20] Retired alias residue gate..."

HARNESS_BIN="$PLUGIN_ROOT/bin/harness"
if [ ! -x "$HARNESS_BIN" ]; then
  echo "  ❌ bin/harness not found (regenerate on trunk after Lead integration)"
  ERRORS=$((ERRORS + 1))
else
  RETIRED_ALIAS_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-retired-alias.XXXXXX")"
  if (cd "$PLUGIN_ROOT" && "$HARNESS_BIN" retired-alias scan) >"$RETIRED_ALIAS_LOG" 2>&1; then
    echo "  ✅ retired-alias scan: 0 hits"
  else
    echo "  ❌ retired-alias scan detected residue"
    sed 's/^/      /' "$RETIRED_ALIAS_LOG" | tail -40
    ERRORS=$((ERRORS + 1))
  fi
  rm -f "$RETIRED_ALIAS_LOG"
fi

# ================================
# 19. Client Mirror drift gate
# ================================
echo ""
echo "🪞 [18/20] Client Mirror drift gate..."

MIRROR_SCHEMA="$PLUGIN_ROOT/templates/schemas/mirror-state.v1.json"
MIRROR_HOOK="$PLUGIN_ROOT/scripts/hook-handlers/skill-mirror-drift.sh"

for required in "$MIRROR_SCHEMA" "$MIRROR_HOOK"; do
  if [ ! -f "$required" ]; then
    echo "  ❌ Missing: ${required#$PLUGIN_ROOT/}"
    ERRORS=$((ERRORS + 1))
  fi
done

MIRROR_BIN="$PLUGIN_ROOT/bin/harness"
case "$(uname -s)" in
  Darwin) MIRROR_BIN="$PLUGIN_ROOT/bin/harness-darwin-$(uname -m | sed 's/x86_64/amd64/')" ;;
esac
[ -x "$MIRROR_BIN" ] || MIRROR_BIN="$PLUGIN_ROOT/bin/harness"

if [ -x "$MIRROR_BIN" ]; then
  MIRROR_LOG="$(mktemp "${TMPDIR:-/tmp}/mirror-verify.XXXXXX")"
  if (cd "$PLUGIN_ROOT" && "$MIRROR_BIN" mirror verify) >"$MIRROR_LOG" 2>&1; then
    echo "  ✅ mirror verify: 0 drift (in-sync)"
  else
    echo "  ❌ mirror verify detected drift"
    sed 's/^/      /' "$MIRROR_LOG" | tail -20
    ERRORS=$((ERRORS + 1))
  fi
  rm -f "$MIRROR_LOG"
else
  echo "  ⚠️ bin/harness missing; skipping mirror verify (build first)"
fi

if (cd "$PLUGIN_ROOT/go" && go test ./internal/clientmirror/... -count=1 >/dev/null 2>&1); then
  echo "  ✅ go test ./internal/clientmirror/... PASS"
else
  echo "  ❌ go test ./internal/clientmirror/... failed"
  ERRORS=$((ERRORS + 1))
fi


# ================================
# 20. Plans Depends/Status gate
# ================================
echo ""
echo "📌 [19/20] Plans Depends/Status gate..."

# Plans.md is gitignored (a per-project working file), so it is absent on a
# clean checkout (e.g. CI). There is nothing to validate then — skip rather
# than fail, mirroring the missing-binary skip in the mirror gate above.
if [ ! -f "$PLUGIN_ROOT/Plans.md" ]; then
  echo "  ⚠️ Plans.md not present (gitignored / per-project); skipping dependency closure"
elif (cd "$PLUGIN_ROOT/go" && go run ./cmd/harness plans check-deps "$PLUGIN_ROOT/Plans.md") >/tmp/harness-plans-deps.$$ 2>&1; then
  echo "  ✅ Plans dependency closure OK"
else
  echo "  ❌ Plans dependency closure failed"
  sed 's/^/      /' /tmp/harness-plans-deps.$$ | tail -40
  ERRORS=$((ERRORS + 1))
fi
rm -f /tmp/harness-plans-deps.$$

# ================================
# 22. Binary/source drift gate
# ================================
echo ""
echo "🧱 [20/20] Binary/source drift gate..."

if bash "$PLUGIN_ROOT/scripts/ci/check-binary-source-drift.sh" >/tmp/harness-bin-drift.$$ 2>&1; then
  echo "  ✅ binary/source drift OK"
else
  echo "  ❌ binary/source drift failed"
  sed 's/^/      /' /tmp/harness-bin-drift.$$ | tail -40
  ERRORS=$((ERRORS + 1))
fi
rm -f /tmp/harness-bin-drift.$$

# ================================
# Result summary
# ================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
  echo "✅ All checks passed"
  exit 0
else
  echo "❌ Found $ERRORS problems"
  exit 1
fi
