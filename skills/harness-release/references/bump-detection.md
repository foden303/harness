# Bump Level Detection

Logic to infer the bump level (patch/minor/major) from the contents of the `[Unreleased]` section.

## Detection Rules

Scan all `### <category>` headings directly under `[Unreleased]` and decide using the following priority:

```
1. Contains "### Breaking Changes"              → major
2. Contains "### Removed"                        → major
3. Contains "### Added" (none of the above)      → minor
4. Contains "### Deprecated" (none of the above) → minor
5. Only "### Fixed" / "### Changed" / "### Security" → patch
6. No subsections at all (empty)                 → error
```

## Implementation

```python
import re

def detect_bump(changelog_text: str) -> str:
    """Return 'major' | 'minor' | 'patch'. Raises on empty [Unreleased]."""
    # Extract the [Unreleased] section
    m = re.search(
        r"## \[Unreleased\]\s*\n(.*?)(?=\n## \[|\Z)",
        changelog_text,
        re.S,
    )
    if not m:
        raise RuntimeError("[Unreleased] section not found")
    body = m.group(1).strip()
    if not body:
        raise RuntimeError("[Unreleased] is empty. Nothing to release")

    # Collect headings
    headings = set(re.findall(r"^### (.+?)\s*$", body, re.M))

    if "Breaking Changes" in headings or "Removed" in headings:
        return "major"
    if "Added" in headings or "Deprecated" in headings:
        return "minor"
    if headings & {"Fixed", "Changed", "Security"}:
        return "patch"
    raise RuntimeError(f"No recognizable subsections in [Unreleased]: {headings}")
```

## Why Deprecated Is Minor

Per the Keep a Changelog spec, Deprecated is "a notice that something will be Removed in the future."
It has the same user impact as a feature addition/change, so it is treated as minor.
It bumps to major at the point of actual Removal.

## User Override

When `/release patch|minor|major` is specified explicitly, this automatic detection is skipped and the specified value is used.
However, if the **section to bump is empty**, abort even when overridden (because there is nothing to release).

## Notation Variants Not Supported

The following are not recognized:

| Commonly written notation | Correct notation |
|-----------------|-----------|
| `### Features` | `### Added` |
| `### Bug Fixes` / `### Fix` | `### Fixed` |
| `### BREAKING CHANGE` / `### Breaking` | `### Breaking Changes` |
| `### Enhancements` | `### Changed` or `### Added` |

Align to the standard KaCL headings before calling `/release`.
If unrecognized headings are detected before the Gate, emit a warning and prompt the user to fix them.

## Handling pre-release / build metadata

When the current version has a pre-release suffix like `1.0.0-alpha.1`, this skill:

1. Ignores the suffix when computing the bump (`1.0.0-alpha.1` → patch → `1.0.1`)
2. Discards the suffix (does not produce `1.0.1-alpha.1`)

If you want to bump while staying on a pre-release, specifying a bump via override does not change this behavior.
Projects that intentionally continue pre-releases are not supported by this skill.

## Handling an empty [Unreleased]

When `/release` is called with an empty [Unreleased], suggest the following:

- "Nothing to release. Add `### Fixed` etc. to `[Unreleased]`, or if you want a marker-only maintenance release, consider the `--empty` flag."

The `--empty` flag is not supported by this skill (empty releases are not created as a rule).
