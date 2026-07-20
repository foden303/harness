#!/usr/bin/env bash
# Phase 64.1.1 / 64.1.3: archive-aware Plans.md grep helper (shared library)
#
# Succeed if the pattern matches in either Plans.md or
# .claude/memory/archive/Plans-*.md (the archive set).
# For consistency with Plans.md archive operations (cleanup that splits old
# Phases into separate files), route the persistent Phase 51-58 requirement
# greps through this helper.
# Intent = keep "verify the record still exists", only widen the search scope
# (= not test tampering).
# Approval: explicitly approved by the user via the .claude/rules/test-quality.md exception format (2026-05-08).
#
# Usage:
#   source "${ROOT_DIR}/tests/lib/grep_plans_or_archive.sh"
#   grep_plans_or_archive 'PATTERN' || { echo "..."; exit 1; }
#
# Required environment variables:
#   ROOT_DIR — absolute path to the repo root. Must be exported or set by the caller beforehand.
#
# Test overrides:
#   GPOA_PLANS_FILE     — override the Plans.md path (default: ${ROOT_DIR}/Plans.md)
#   GPOA_ARCHIVE_DIR    — override the archive directory path (default: ${ROOT_DIR}/.claude/memory/archive)
#   tests/test-grep-plans-or-archive.sh verifies 4 states (Plans only / archive only / both / miss).

grep_plans_or_archive() {
    local pattern="$1"
    local plans="${GPOA_PLANS_FILE:-${ROOT_DIR}/Plans.md}"
    local archive_dir="${GPOA_ARCHIVE_DIR:-${ROOT_DIR}/.claude/memory/archive}"

    if [ -f "${plans}" ] && grep -q -- "${pattern}" "${plans}" 2>/dev/null; then
        return 0
    fi

    if [ -d "${archive_dir}" ]; then
        for archive_file in "${archive_dir}"/Plans-*.md; do
            [ -f "${archive_file}" ] || continue
            if grep -q -- "${pattern}" "${archive_file}" 2>/dev/null; then
                return 0
            fi
        done
    fi

    return 1
}
