# Release Notes Format

Rules for converting a CHANGELOG `## [X.Y.Z]` section into notes for a GitHub Release.

## Language

- **GitHub Release notes: English** (standard for public repositories)
- **CHANGELOG.md: Japanese** (when the project's primary language is Japanese)

If the CHANGELOG is written in Japanese, an English translation is needed when creating the GitHub Release.
The skill calls Claude to generate a draft and has the user confirm it at the Confirmation Gate.

## Required Elements

```markdown
## What's Changed

**<1-line value summary>**

### Before / After

| Before | After |
|--------|-------|
| <previous UX> | <new UX> |

---

### Added
- <item>

### Changed
- <item>

### Fixed
- <item>

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## How to Generate Each Element

### "What's Changed" summary

Extract from the `### Theme` line of the CHANGELOG `[X.Y.Z]` section.
If absent, summarize in one sentence from the first item under Added/Changed/Fixed.

### Before / After table

Extract from the "Before / After" descriptions in the CHANGELOG.
If absent, infer from:
- Fixed item → "<bug description>" vs "Fixed"
- Added item → "<feature> was unavailable" vs "now available"
- Changed item → "<old behavior>" vs "<new behavior>"

### Added / Changed / Fixed

Translate the corresponding CHANGELOG sections into English and transcribe as-is.

### Footer

Fixed: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

## Draft Confirmation

At the Confirmation Gate, present the following:

```
GitHub Release Preview:
━━━━━━━━━━━━━━━━━━━━━━
Title: v4.0.4 - Fix CI validation gap
Body (first 20 lines):

  ## What's Changed

  **Fixed a gap in validate-plugin.sh ...**
  ...

(Full body: 45 lines)
━━━━━━━━━━━━━━━━━━━━━━
```

If the user instructs "fix it: ...", regenerate.

## Validation

Before passing release notes to the workflow, check that the following are satisfied:

1. A `## What's Changed` section exists
2. A **bold summary** line exists
3. A `### Before / After` table exists
4. The footer `Generated with [Claude Code]` exists

If not satisfied, return to the Gate and prompt for a fix.

## How to Combine Multiple Changes

When the CHANGELOG `[X.Y.Z]` contains two or more features:

- Title: represent with the single most important one (or "Multiple fixes and improvements")
- Body: split each feature into `### N. <feature name>` and translate into English

Releasing multiple versions on the same day is discouraged (versioning.md). Combine them into a batch release.
