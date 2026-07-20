#!/bin/bash
# test-project-detection.sh
# Verification script for /harness-init's project detection logic (3-value judgment)
#
# Usage: ./tests/test-project-detection.sh
#
# Test cases:
# 1. empty directory → "new"
# 2. existing code (10+ files + src/) → "existing"
# 3. template only (package.json present, 0 code) → "ambiguous" (template_only)
# 4. README.md only → "ambiguous" (readme_only)
# 5. 3-9 code files → "ambiguous" (few_files)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR=$(mktemp -d)

# color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# counter
PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

log_pass() {
  echo -e "${GREEN}✅ PASS${NC}: $1"
  PASSED=$((PASSED + 1))
}

log_fail() {
  echo -e "${RED}❌ FAIL${NC}: $1"
  echo "  Expected: $2"
  echo "  Actual: $3"
  FAILED=$((FAILED + 1))
}

# ================================
# simulation of the detection logic
# ================================

detect_project_type() {
  local dir="$1"
  cd "$dir"

  # count code files (excluding node_modules, .venv, dist)
  local code_count
  code_count=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) \
    ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/dist/*" ! -path "*/.next/*" ! -path "*/__pycache__/*" 2>/dev/null | wc -l | tr -d ' ')

  # total file count (excluding hidden files)
  local total_files
  total_files=$(find . -type f ! -name ".*" ! -path "*/.*" 2>/dev/null | wc -l | tr -d ' ')

  # check if only hidden files/directories
  local visible_files
  visible_files=$(ls 2>/dev/null | wc -l | tr -d ' ')

  # check for source directory
  local has_src_dir=false
  [ -d "src" ] || [ -d "app" ] || [ -d "lib" ] && has_src_dir=true

  # check for package manager file
  local has_package_file=false
  [ -f "package.json" ] || [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Cargo.toml" ] || [ -f "go.mod" ] && has_package_file=true

  # detection logic

  # Step 1: empty directory check
  if [ "$visible_files" -eq 0 ]; then
    echo "new"
    return
  fi

  # check for only .gitignore/.git
  local only_git=true
  for f in $(ls -A 2>/dev/null); do
    if [ "$f" != ".git" ] && [ "$f" != ".gitignore" ]; then
      only_git=false
      break
    fi
  done
  if [ "$only_git" = true ]; then
    echo "new"
    return
  fi

  # Step 2: check for substantial code presence
  if [ "$code_count" -ge 10 ] && [ "$has_src_dir" = true ]; then
    echo "existing"
    return
  fi

  if [ "$has_package_file" = true ] && [ "$code_count" -ge 3 ]; then
    echo "existing"
    return
  fi

  # Step 3: classify ambiguous cases
  if [ "$has_package_file" = true ] && [ "$code_count" -eq 0 ]; then
    echo "ambiguous:template_only"
    return
  fi

  if [ "$code_count" -ge 1 ] && [ "$code_count" -lt 10 ]; then
    echo "ambiguous:few_files"
    return
  fi

  # only README.md/LICENSE
  local readme_only=true
  for f in $(ls 2>/dev/null); do
    if [ "$f" != "README.md" ] && [ "$f" != "LICENSE" ] && [ "$f" != "LICENSE.md" ]; then
      readme_only=false
      break
    fi
  done
  if [ "$readme_only" = true ]; then
    echo "ambiguous:readme_only"
    return
  fi

  # config files only
  echo "ambiguous:scaffold_only"
}

# ================================
# test cases
# ================================

echo "================================"
echo "Project detection logic test"
echo "================================"
echo ""

# Test 1: empty directory
echo "--- Test 1: empty directory ---"
TEST1_DIR="$TEST_DIR/test1_empty"
mkdir -p "$TEST1_DIR"
RESULT=$(detect_project_type "$TEST1_DIR")
if [ "$RESULT" = "new" ]; then
  log_pass "empty directory -> new"
else
  log_fail "empty directory" "new" "$RESULT"
fi

# Test 2: .git only
echo "--- Test 2: .git only ---"
TEST2_DIR="$TEST_DIR/test2_git_only"
mkdir -p "$TEST2_DIR/.git"
RESULT=$(detect_project_type "$TEST2_DIR")
if [ "$RESULT" = "new" ]; then
  log_pass ".git only -> new"
else
  log_fail ".git only" "new" "$RESULT"
fi

# Test 3: existing project (10+ files + src/)
echo "--- Test 3: existing project (10+ files + src/) ---"
TEST3_DIR="$TEST_DIR/test3_existing"
mkdir -p "$TEST3_DIR/src"
for i in $(seq 1 15); do
  touch "$TEST3_DIR/src/file$i.ts"
done
touch "$TEST3_DIR/package.json"
RESULT=$(detect_project_type "$TEST3_DIR")
if [ "$RESULT" = "existing" ]; then
  log_pass "10+ files + src/ -> existing"
else
  log_fail "10+ files + src/" "existing" "$RESULT"
fi

# Test 4: template only (package.json present, 0 code)
echo "--- Test 4: template only ---"
TEST4_DIR="$TEST_DIR/test4_template"
mkdir -p "$TEST4_DIR"
echo '{"name": "test"}' > "$TEST4_DIR/package.json"
touch "$TEST4_DIR/README.md"
RESULT=$(detect_project_type "$TEST4_DIR")
if [ "$RESULT" = "ambiguous:template_only" ]; then
  log_pass "package.json + 0 code -> ambiguous:template_only"
else
  log_fail "package.json + 0 code" "ambiguous:template_only" "$RESULT"
fi

# Test 5: README.md only
echo "--- Test 5: README.md only ---"
TEST5_DIR="$TEST_DIR/test5_readme"
mkdir -p "$TEST5_DIR"
touch "$TEST5_DIR/README.md"
RESULT=$(detect_project_type "$TEST5_DIR")
if [ "$RESULT" = "ambiguous:readme_only" ]; then
  log_pass "README.md only -> ambiguous:readme_only"
else
  log_fail "README.md only" "ambiguous:readme_only" "$RESULT"
fi

# Test 6: 5 code files (few)
echo "--- Test 6: 5 code files ---"
TEST6_DIR="$TEST_DIR/test6_few_files"
mkdir -p "$TEST6_DIR"
for i in $(seq 1 5); do
  touch "$TEST6_DIR/file$i.ts"
done
RESULT=$(detect_project_type "$TEST6_DIR")
if [[ "$RESULT" == ambiguous:few_files ]]; then
  log_pass "5 code files -> ambiguous:few_files"
else
  log_fail "5 code files" "ambiguous:few_files" "$RESULT"
fi

# Test 7: package.json + 3+ code → existing
echo "--- Test 7: package.json + 3 code -> existing ---"
TEST7_DIR="$TEST_DIR/test7_package_code"
mkdir -p "$TEST7_DIR"
echo '{"name": "test"}' > "$TEST7_DIR/package.json"
for i in $(seq 1 4); do
  touch "$TEST7_DIR/file$i.ts"
done
RESULT=$(detect_project_type "$TEST7_DIR")
if [ "$RESULT" = "existing" ]; then
  log_pass "package.json + 4 code -> existing"
else
  log_fail "package.json + 4 code" "existing" "$RESULT"
fi

# ================================
# result summary
# ================================

echo ""
echo "================================"
echo "Test result summary"
echo "================================"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -gt 0 ]; then
  exit 1
else
  echo ""
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
