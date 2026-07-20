---
name: harness-release
description: "Generic release automation for projects using Keep a Changelog + GitHub. Single confirmation gate then end-to-end automation: bump detection, CHANGELOG promotion, PR/main merge, tag, GitHub Release. Trigger: release, version bump, publish. Do NOT load for: implementation, review, planning, setup."
description-en: "Generic release automation for projects using Keep a Changelog + GitHub. Single confirmation gate then end-to-end automation: bump detection, CHANGELOG promotion, PR/main merge, tag, GitHub Release. Trigger: release, version bump, publish. Do NOT load for: implementation, review, planning, setup."
kind: workflow
purpose: "Release projects through changelog, version, PR/main merge, tag, and GitHub Release gates"
trigger: "release, version bump, publish"
shape: workflow
role: orchestrator
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Bash", "AskUserQuestion", "Skill"]
argument-hint: "[patch|minor|major|--dry-run]"
context: fork
effort: high
user-invocable: true
---

# Harness Release (generic)

A generic release automation skill **for any project** using Keep a Changelog + GitHub.

**Design principle**: a single confirmation gate. The user reviews and approves the whole plan just once. After approval, it runs uninterrupted from file rewrite → commit → branch push → PR create/update → merge into the default branch → tag on the default branch → GitHub Release.

**Definition of "release complete"**: a release is not complete just because "a tag and a GitHub Release were created." It is complete when the target work and the release bump are merged into the default branch (usually `main`), the release tag points at a commit reachable from the default branch, and the GitHub Release publishes that tag.

## PR ready vs release ready

In Harness V2, do not conflate PR closeout and release closeout.

| Gate | Meaning | Required conditions | Stop lane |
|------|---------|---------------------|-----------|
| **PR ready** | The branch is reviewable and merge can be decided | `harness-review` `APPROVE`, focused tests PASS, complete evidence pack (accepted/rejected findings, tests, release-preflight warnings handled, residual risk) | `[lane:fast]` / `[lane:gate]` may stop here |
| **release ready** | The public distribution path passes preflight | PR ready conditions + version surface sync + tag + GitHub Release + CI/public artifact verification | `[lane:release]` only |

- PR ready is decided by `harness-review` APPROVE + evidence pack. `harness-review` does not push / PR / merge.
- release ready is decided only by `harness-release`'s Preflight / Post-Gate. version bump / tag / GitHub Release are release-lane only.
- "local tests passed" alone is neither PR ready nor release ready (`not_observed != absent`).

> **Literal invocation note**: this skill's entry point uses literal commands as-is, such as `harness-release`, `/release`, `/release patch`, `/release --dry-run`.

## Relationship to the CC runtime hard floor

The runtime hard floor in Claude Code 2.1.183+ structurally denies GitHub CLI release-publish commands (an Anthropic product spec; it cannot be overridden by `settings.json`'s `permissions.ask`). This skill does not perform the publish itself; it delegates to `.github/workflows/release.yml` (tag push trigger). The skill completes its responsibility at the tag push, then verifies the workflow's publish with `scripts/release-verify-publish.sh`.

**Revert condition**: if CC provides a user-explicit-approval path to the runtime hard floor, consider restoring a direct publish step in the Post-Gate.

## Bare invocation contract

if $ARGUMENTS == "":
  → interpret it as "commit the work so far, complete PR/main merge, and release," and run Review Gate detection
  → auto-advance to Step 0 (Review Gate) only when the target work can be uniquely determined
  → if the target is unclear or there is no review state, present options via AskUserQuestion before proceeding

On the first response of a no-argument invocation, always emit the following literal marker:

`RELEASE_AUTOSTART: target=<work-summary>, base_ref=<ref>, mode=<patch|minor|major|auto>`

"The task is unclear," "I will wait for instructions," "There is no task," and "I await further instructions" are prohibited behaviors.

<!-- The block above is the AUTO-START CONTRACT. Follows the skill-editing.md "within the first 3 lines" rule. patterns.md P27 solution triple (machine-readable condition + prohibited-behavior literal + AUTOSTART marker) -->

### Output Contract (P35: countermeasure for the "looks stuck" UX)

The **last line** of the output at the skill's conclusion must always include the following literal:

`↑ Claude will summarize this result. Press Enter to continue, or give a new instruction with a fresh prompt.`

This is an explicit instruction (patterns.md P35) for the UX problem where, when shown as a text response via `<local-command-stdout>`, the user feels it has "stopped."

When only `harness-release` / `/release` is entered, treat it as
**"commit the work so far, complete PR/main merge, and release."**
The older phrasing **"commit the work so far and release"** has the same intent, but the completion condition must always include PR/main merge.
Do not stop with "there is no task" or "I will wait for instructions."

For a bare release, run the **Review Gate** and the **Work Commit Gate** before the normal release preflight.

The Review Gate is for **release ready**. For work that only needs PR ready in `[lane:fast]` / `[lane:gate]`, do not start `harness-release` unless the user explicitly asks for a release.

1. Check `git status --porcelain` and `git log @{upstream}..HEAD` / `main..HEAD` to identify the target of "the work so far"
2. Check `.claude/state/review-result.json` and `.claude/state/review-approved.json` to confirm the target work has an `APPROVE`d review and an evidence pack
3. If there is no `APPROVE`d review, confirm via `AskUserQuestion`
4. If the user chooses "start from review," start `harness-review` and do not proceed to release until it is `APPROVE`
5. If `harness-review` returns `REQUEST_CHANGES`, hold the release, fix with `harness-work`, then re-run `harness-review`. Loop this until `APPROVE`
6. After `harness-review` returns `APPROVE`, create a work commit for the working tree
7. Once the working tree is clean, proceed to the normal release preflight / confirmation gate / PR merge / tag / GitHub Release

### Review Gate AskUserQuestion

When review approval cannot be confirmed at `harness-release` time, do not release on a guess.
Emit the following Ask.

```text
question: "harness-release commits the work so far and releases it, but no APPROVE review was found for this work. How do you want to proceed?"
options:
  - label: "Start from review (Recommended)"
    description: "Run harness-review, and proceed to commit/release only if it becomes APPROVE."
  - label: "release dry-run"
    description: "Do not rewrite files; only check the release plan and the missing gates."
  - label: "Cancel"
    description: "Stop without doing review or release."
```

If the user chooses "Start from review," start from `harness-review` within the same session.
The target determination for `harness-review` follows `harness-review`'s bare review contract.
If the review is `APPROVE`, return to `harness-release`'s Work Commit Gate as-is.
If the review is `REQUEST_CHANGES`, hold the release, fix with `harness-work`, then re-run `harness-review`.
This fix-then-re-review loop continues until `APPROVE`.

You may return to the user only in the following cases.

1. The fix requires a decision on the spec source of truth / Plans.md / API / permission / migration / billing, etc., and `AskUserQuestion` is needed
2. There are multiple fix approaches, and the choice changes user value or compatibility
3. The user chose `release dry-run` or `Cancel` at the Ask

Do not make `REQUEST_CHANGES` alone the final stop reason.

### Work Commit Gate

When a bare release has uncommitted changes in the working tree, create the reviewed work commit first,
separately from the release version bump commit.

```bash
git status --short
git diff --stat
git add <reviewed files>
git commit -m "<type>: <summary>"
```

Generate the commit message briefly from the review summary / Plans.md task / branch name.
If you cannot decide, offer 2-3 commit message candidates via `AskUserQuestion`.
After creating the work commit, check or update `commit_hash` in `.claude/state/review-result.json`,
then proceed to the release preflight.

Once in the normal release preflight, treat a dirty working tree as a failure as before.
Do not proceed to version bump / tag / GitHub Release with a dirty tree.

## Quick Reference

```bash
/release              # review gate → commit → PR/main merge → release the work so far
/release patch        # explicitly specify a patch bump
/release minor        # explicitly specify a minor bump
/release major        # explicitly specify a major bump
/release --dry-run    # show the plan only, do not execute
```

## Prerequisites

A project this skill runs on must satisfy the following:

1. `CHANGELOG.md` is in [Keep a Changelog](https://keepachangelog.com/) format
2. An `[Unreleased]` section exists
3. It has one of the following version files:
   - `VERSION` (a standalone file)
   - `package.json` (npm)
   - `pyproject.toml` (Python, `[project]` or `[tool.poetry]`)
   - `Cargo.toml` (Rust, `[package]`)
4. The `gh` CLI is installed and authenticated
5. The git remote `origin` points at GitHub
6. For a Claude Code plugin project, the `claude` CLI supports `plugin tag`

If these are not satisfied, Preflight detects it and aborts.

Multi-host review URLs via `prUrlTemplate` are recognized as a future candidate, but
this skill's release automation still uses the `gh` CLI and a GitHub remote as the primary path.
Auto-fetching owner / branch / release asset / CI metadata varies greatly per host, so Phase 56.2.3 keeps it docs-only.

## Single-gate flow

```
[Bare release only: pre-stage for work review/commit]
  ↓
  0. Review Gate (if unreviewed, AskUserQuestion → harness-review)
  0.5 Work Commit Gate (commit the review-APPROVEd work separately from the release bump)
  ↓
[Pre-Gate: information gathering only, files unchanged]
  ↓
  1. Preflight (confirm working tree clean / CHANGELOG / gh, etc.)
  2. Auto-detect the version file
  3. Read the current version
  4. Claude plugin tag preflight (plugin projects only)
  5. Analyze the [Unreleased] content → estimate the bump level
  6. Compute the new version
  7. Draft the CHANGELOG diff (in memory)
  8. Draft the GitHub Release notes (in memory)

★━━━━━━ Single confirmation gate ━━━━━━★
  Present the whole plan to the user just once:
    - The detected version file
    - Current version → new version
    - Bump rationale ("minor because [Unreleased] has ### Added," etc.)
    - CHANGELOG change preview
    - GitHub Release notes draft
    - List of files to commit
    - Final actions (branch push + PR merge + tag + release publish)

  User response:
    "yes"          → proceed to Post-Gate
    "<amendment>"  → regenerate the draft per the instruction, re-confirm
    "cancel/no"    → end without doing anything
★━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━★
  ↓
[Post-Gate: after approval, no interruption]

  9. Rewrite the version file
  10. Rewrite CHANGELOG.md ([Unreleased] → promote to [X.Y.Z] + compare link)
  11. git add + commit
  12. Push the release branch
  13. Create/update the PR
  14. Merge into the default branch
  15. Fetch/checkout the default branch and confirm the release commit is reachable
  16. Claude plugin tag validation + tag (plugin projects only)
  17. semver tag for the GitHub Release (only projects that need it)
  18. git push origin <default-branch> --tags
  19. After the tag push, `.github/workflows/release.yml` publishes the release, and `release-verify-publish.sh` verifies it
  20. Completion report
```

## Pre-Gate details

### 1. Preflight

release ready gate: in addition to the PR ready conditions, confirm the version / tag / GitHub Release / CI artifact path.

```bash
# Required tools
command -v gh >/dev/null || { echo "gh CLI is missing"; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }

# working tree
if [ -n "$(git status --porcelain)" ]; then
  echo "the working tree has uncommitted changes"; exit 1;
fi

# CHANGELOG
[ -f CHANGELOG.md ] || { echo "CHANGELOG.md is missing"; exit 1; }
grep -q "^## \[Unreleased\]" CHANGELOG.md || { echo "there is no [Unreleased] section"; exit 1; }

# plugin/mirror projects
scripts/release-preflight.sh
```

This working-tree-clean check is the normal release preflight gate.
For a bare release where you want to commit "the work so far," complete the Review Gate and the Work Commit Gate before this check.
Do not abort and finish on this check alone for an unreviewed dirty tree.

`scripts/release-preflight.sh` also detects mirror drift in the `.agents/skills/` mirror before tag creation. If `./scripts/sync-skill-mirrors.sh` produces a diff, stop the release, commit that diff, then proceed to the tag.

### 2. Version file auto-detection

Search in priority order. Treat the first one found as the source of truth:

```python
# Python snippet to run inline
import os, json, re
import tomllib  # Python 3.11+

def detect_version_file():
    if os.path.exists("VERSION"):
        with open("VERSION") as f:
            return ("VERSION", f.read().strip(), None)
    if os.path.exists("package.json"):
        with open("package.json") as f:
            data = json.load(f)
        return ("package.json", data["version"], None)
    if os.path.exists("pyproject.toml"):
        with open("pyproject.toml", "rb") as f:
            data = tomllib.load(f)
        if "project" in data:
            return ("pyproject.toml", data["project"]["version"], "[project]")
        if "tool" in data and "poetry" in data["tool"]:
            return ("pyproject.toml", data["tool"]["poetry"]["version"], "[tool.poetry]")
    if os.path.exists("Cargo.toml"):
        with open("Cargo.toml", "rb") as f:
            data = tomllib.load(f)
        return ("Cargo.toml", data["package"]["version"], "[package]")
    raise RuntimeError("No supported version file found")
```

Details: [version-files.md](${CLAUDE_SKILL_DIR}/references/version-files.md)

### 3. Claude Plugin Tag Preflight

In a project where `.claude-plugin/plugin.json` exists, create a Claude plugin release tag in addition to the normal GitHub Release tag.

In short, before hand-assembling `git tag -a`, pass Claude Code's own plugin validation, then create the `{plugin-name}--v{version}` tag.

The Pre-Gate does not rewrite files; it confirms the following.
Do not pick up version sync with `grep` / `sed`; read JSON with a structured parser:

```bash
command -v claude >/dev/null || { echo "claude CLI is missing"; exit 1; }
claude plugin validate .claude-plugin/plugin.json

HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .

claude plugin tag .claude-plugin --dry-run
```

`${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py` reads all existing release surfaces and decides the canonical one in the order `VERSION > package.json > .claude-plugin/plugin.json > .claude-plugin/marketplace.json`.
On top of that, it does not proceed to tag / release if there is even one of the following mismatches / omissions:

- `VERSION`
- `.version` in `package.json`
- `.version` in `.claude-plugin/plugin.json`
- `.metadata.version` in `.claude-plugin/marketplace.json`
- `.plugins[].version` in `.claude-plugin/marketplace.json` (each plugin entry in the array)

On a mismatch, it shows which surface differs from the canonical, or which field is missing / invalid.
For machine processing or CI, use `--json`:

```bash
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root . --json
```

This check exists to prevent 3 accidents:

- Cutting a tag while the versions of `VERSION` and `.claude-plugin/plugin.json` are out of sync
- Proceeding to the release workflow while the version in `package.json` / a marketplace entry is stale
- Getting stuck later on plugin install / update by not passing the plugin manifest / marketplace entry validation

With `--dry-run`, you can see the tag name `claude plugin tag` will actually create and the internal `git tag -a` / push-equivalent commands. Include the commands you see here in the Confirmation Gate plan.

### 4. Bump auto-estimation

Analyze the headings directly under `[Unreleased]` to determine the bump level:

| Heading within [Unreleased] | Estimated bump |
|-----------------------------|----------------|
| Includes `### Breaking Changes` or `### Removed` | **major** |
| Includes `### Added` (no Removed/Breaking) | **minor** |
| Only `### Fixed` / `### Changed` / `### Security` | **patch** |
| Empty section | **error: nothing to release** |

If the user explicitly specifies with `/release patch|minor|major`, that takes precedence.
Details: [bump-detection.md](${CLAUDE_SKILL_DIR}/references/bump-detection.md)

### 5. Draft the CHANGELOG (in memory)

Compute the following; do not write yet:

1. Cut out the body of `## [Unreleased]`
2. Build a form that inserts `## [<new>] - YYYY-MM-DD` between `## [Unreleased]` and `## [<previous>]`
3. Trailing compare link:
   - `[Unreleased]: .../compare/v<prev>...HEAD` → `v<new>...HEAD`
   - Add `[<new>]: .../compare/v<prev>...v<new>`
4. Extract the repo URL dynamically from the existing `[Unreleased]: ` line

### 6. Draft the Release Notes (in memory)

Generate the markdown for the GitHub Release based on the content of the `## [<new>]` section:

```markdown
## What's Changed

**<release theme (one line)>**

### Before / After
<table>

### Added / Changed / Fixed / Removed
<copy the relevant sections>

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Details: [release-notes.md](${CLAUDE_SKILL_DIR}/references/release-notes.md)

## Confirmation Gate

Once all drafts are ready, present them to the user just once:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Release Plan: v<old> → v<new> (<bump>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Version file: <detected file>
 Bump reason:  <why this level was chosen>

 CHANGELOG changes:
   Detected <N> changes in [Unreleased]
   Finalize as [<new>] - YYYY-MM-DD
   Add the compare link

 GitHub Release notes preview:
   <first 10 lines>
   ...

 Files to modify:
   - <version file>
   - CHANGELOG.md

 Final actions:
   - git commit -m "chore: release v<new>"
   - git push origin <release-branch>
   - gh pr create/update + gh pr merge into <default-branch>
   - git fetch origin <default-branch> && git checkout <default-branch>
   - claude plugin tag .claude-plugin --push --remote origin  # for plugin projects. Run on the default branch
   - git tag -a v<new>                                        # when a semver tag for the GitHub Release is needed. Create on the default branch
   - git push origin <default-branch> --tags
   - (after the tag push, the GitHub Actions release workflow publishes the release automatically)

Proceed? [yes / cancel / <amendment>]
```

## Post-Gate details

Runs uninterrupted after approval. On failure, the policy is:

| Failure point | Recovery |
|---------------|----------|
| File rewrite failed | Abort there; the local tree stays dirty for a human to judge |
| commit failed | Hook rejection, etc. Present the cause to the user and prompt a fix |
| PR create/merge failed | Stop with the release incomplete. Do not proceed to tag / GitHub Release |
| plugin tag validation failed | Fix the `VERSION` / `.claude-plugin/plugin.json` / marketplace entry mismatch, and do not proceed to tag creation |
| push failed | A remote-side problem. Keep the local commit/tag |

### PR / Main Merge Gate

After the Post-Gate release commit, merge the GitHub PR into the default branch before creating the tag.

```bash
release_branch="$(git branch --show-current)"
default_branch="${HARNESS_RELEASE_DEFAULT_BRANCH:-main}"

git push -u origin "$release_branch"
gh pr create --base "$default_branch" --head "$release_branch" --title "chore: release v<new>" --body "<release summary>"
gh pr merge --merge --delete-branch=false

git fetch origin "$default_branch" --tags
git checkout "$default_branch"
git pull --ff-only origin "$default_branch"
git merge-base --is-ancestor "<release-commit>" "origin/$default_branch"
```

If an existing PR exists, do not create a new one; update the existing PR's body and merge it. If the repository policy requires a squash merge, confirm that the release bump content (version files + CHANGELOG + source commits) is included in the default branch, not the release commit hash.

Create the tag after this Gate completes, on the default branch's HEAD or on a commit reachable from the release commit. Do not create a GitHub Release with a tag pointing at a commit that exists only on the release branch.

### Tag creation for a Claude plugin project

In a project with `.claude-plugin/plugin.json`, confirm version sync once more on the default branch after the PR/main merge, then create the plugin tag:

```bash
HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .

claude plugin tag .claude-plugin --dry-run
claude plugin tag .claude-plugin --push --remote origin
```

The tag `claude plugin tag` creates is in `{plugin-name}--v{version}` format. In a project whose existing GitHub Release workflow assumes a `vX.Y.Z` tag, create a `git tag -a v<new>` separately from the plugin tag. Leave the plugin distribution tag to `claude plugin tag`, and treat the semver tag for the GitHub Release as the release automation's compatibility surface.

### Verify Workflow Publish

After the tag push, `.github/workflows/release.yml` publishes the release automatically. The skill verifies the result with:

```bash
OWNER="$(git remote get-url origin | sed 's|.*github.com[:/]\([^/]*/[^/]*\)\.git|\1|')"
bash scripts/release-verify-publish.sh "v${NEW_VERSION}" "${OWNER}"
```

Timeout: 5-second interval × 60 = up to 5 minutes of polling.

- exit 0: PASS — `draft=false` and all 4 platform assets published
- exit 2: WARN — timeout (the tag is already pushed, so do not abort; prompt human judgment)
- exit 3: ERROR — API error (permission/auth problem, requires manual investigation)

Verify is done via `gh api`. Do not use the GitHub CLI release subcommand prefix, since it is denied by the CC runtime hard floor.

## `--dry-run` mode

Runs the entire Pre-Gate and shows the content up to the Confirmation Gate, but **stops at the gate and does not proceed to the Post-Gate**.

For a Claude plugin project, even in dry-run it runs `python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .` and `claude plugin tag .claude-plugin --dry-run` to show the plugin tag name that will actually be created and the push target. If the version surfaces of `VERSION` / `package.json` / `.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` are mismatched or missing here, stop at the dry-run point.

## Environment variables

Used for per-project adjustment:

| Variable | Description |
|----------|-------------|
| `HARNESS_RELEASE_PROJECT_ROOT` | Repository root (default: `$(pwd)`) |
| `HARNESS_RELEASE_BRANCH` | Branch to push (default: the current branch) |
| `HARNESS_RELEASE_DEFAULT_BRANCH` | The default branch to merge the PR into (default: `main`) |
| `HARNESS_RELEASE_HEALTHCHECK_CMD` | An additional command to run in Preflight |
| `HARNESS_RELEASE_SKIP_GH` | `1` skips GitHub Release creation |

## CHANGELOG writing rules

The `[Unreleased]` section must always have one of the following subsections:

```markdown
## [Unreleased]

### Added       ← minor
### Changed     ← patch
### Deprecated  ← minor
### Removed     ← major
### Fixed       ← patch
### Security    ← patch
### Breaking Changes  ← major (non-standard in Keep a Changelog but common)
```

This skill parses these headings mechanically, so it cannot recognize heading variants (`### Fix` / `### Bug Fixes`, etc.). Use the KaCL standard headings.

## Pre-shipping acceptance decision (for non-engineers)

Propose `harness-accept` before finalizing the release. It is an "acceptance decision" screen that summarizes, on a single HTML page, whether each acceptance condition was met and a ship/wait/reject recommendation, so a requester can judge whether to ship without technical knowledge.

## Related skills

- `harness-release-internal` - a harness-specific preflight/finalization run additionally when releasing the main harness itself (not distributed)
- `harness-plan` - Plans.md management
- `harness-review` - code review before release
- `harness-accept` - acceptance decision HTML (for non-engineers, proposed before release)

## Design philosophy

- **PR ready / release ready separation**: PR ready is review + evidence pack. release ready goes all the way to version/tag/GitHub Release/CI. lane:fast / lane:gate may stop at PR ready
- **Single gate**: the user's decision point is just once. Inserting mini-confirmations turns it into a rubber stamp and loses meaning
- **Draw everything up front**: prohibit "rethinking" after entering the Post-Gate. Have all drafts ready before the Gate
- **Main merge is the completion condition**: create the release tag / GitHub Release only after the default branch merge. Treat a branch-only release as incomplete
- **Failures are transparent**: on a mid-way failure, do not attempt an automatic rollback; present the current state to the user for a decision
- **Project-agnostic**: do not assume a specific environment such as VERSION file format, mirror, or residue check. Split main-harness-specific processing into `harness-release-internal`
