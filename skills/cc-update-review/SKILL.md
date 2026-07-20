---
name: cc-update-review
description: "Quality guardrail for Claude Code update integration. Detects doc-only Feature Table additions and requires implementation or explicit planning. Internal use only."
description-en: "Quality guardrail for Claude Code update integration. Detects doc-only Feature Table additions and requires implementation or explicit planning. Internal use only."
user-invocable: false
disable-model-invocation: true
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Claude Code Update Review Guardrail

A quality guardrail that prevents "just written into the Feature Table" during Claude Code update integration.
It classifies whether a Feature Table addition is accompanied by implementation, verification, or an explicit future task, and forces an implementation proposal when something is missing.

## Quick Reference

This skill is triggered in the following situations:

- Reviewing a Claude Code upstream update integration PR
- Detecting a diff that adds a new row to `docs/CLAUDE-feature-table.md`
- Internal invocation when `/harness-review` determines a PR is an upstream update integration
- Reviewing an update to the `claude-upstream-update` skill

Situations that do NOT trigger it:

- Normal implementation work
- Changes unrelated to the Feature Table / upstream tracking
- Setup / initialization work

## Obtaining the diff input

Since this skill is dedicated to diff-aware review, always determine the review-target diff by one of the following.

1. The calling `/harness-review` passes the PR diff / changed files / Feature Table added lines
2. This skill itself runs read-only Bash such as `git status --short`, `git diff --name-only`, `git diff -- docs/CLAUDE-feature-table.md`, `git show --stat --name-only` to confirm

Use Bash only for read-only git inspection. Do not run commands that involve test execution, formatting, generation, network access, or file changes.
If the diff cannot be obtained, do not assume `B: doc-only 0 items`; stop the review as "cannot classify because the diff is not provided."

## Prerequisite checks

Always confirm at the start of the review:

- Whether the diff source is determined by either caller-provided or read-only git inspection
- For a PR that edits `skills/` or `hooks/`, whether `/reload-plugins` was run immediately afterward to refresh the runtime cache (per the `{skills,hooks}/**` guideline)
- Whether there is a per-version breakdown table of the upstream
- Whether the Claude Code primary-source URL is `anthropics/claude-code` or the official docs
- Whether any `B: doc-only` remains
- If touching skill mirrors, whether the diffs in `skills/`, `.agents/skills/` are as intended

Prohibited stale references:

- Old TypeScript guardrail path
- Old TypeScript implementation glob

## A/B/C/P classification

Classify each item added to the Feature Table as one of A/B/C/P below.

### (A) Has implementation

Definition: the Feature Table addition is accompanied by changes to hooks / settings / Go / scripts / agents / skills / tests in the same PR.

Criteria:

- Files related to the feature mentioned in the Feature Table row are changed
- There is a real diff in one of `hooks/hooks.json`, `.claude-plugin/hooks.json`, `.claude-plugin/settings.json`, `go/internal/guardrail/`, `go/internal/hookhandler/`, `scripts/`, `agents/`, `skills/`, `tests/`
- It is fixed by a target test or verification script

Examples:

| Feature Table addition | Corresponding implementation change | Verdict |
|-------------------|----------------|------|
| `AskUserQuestion updatedInput` | Go handler + hooks wiring + upstream integration test | A |
| `sandbox.network.deniedDomains` | `.claude-plugin/settings.json` + jq test | A |
| `find -delete hardening` | `go/internal/guardrail/` + unit test | A |

Result: OK. No additional action needed.

---

### (B) Doc-only

Definition: only a row is added to the Feature Table, with no Harness-side implementation change and no planning. And it does not qualify as upstream auto-inheritance either.

Criteria:

- There is a new row in the Feature Table
- There is no related implementation / test / skill / Plans change in the same PR
- It is a feature where Harness should provide its own added value

Examples:

| Feature Table addition | Corresponding implementation change | Verdict |
|-------------------|----------------|------|
| `PreCompact hook` | None | B |
| `permission hardening` | No confirmation of settings / guardrail / tests | B |

Result: NG. Block the PR and require an implementation proposal or planning.

---

### (C) Upstream auto-inheritance

Definition: items where a Harness-side change is unnecessary due to Claude Code core performance improvements, bug fixes, internal optimizations, etc.

Criteria:

- It is a fix in the upstream core, with no room for Harness to wrap or extend
- It does not affect Harness's settings / hooks / guardrail / workflow / tests
- The Feature Table explicitly states "upstream auto-inheritance" or "CC auto-inheritance"

Notes:

- Do not casually mark permission / sandbox / security / Bash allowlist / MCP trust boundary as C
- Only mark as C after confirming the item does not affect Harness's own guardrail or settings
- For Claude Code 2.1.113 hardening, do not judge as C until confirming `sandbox.network.deniedDomains`, wrapper Bash deny, `find -exec/-delete`, and macOS dangerous rm paths

Examples:

| Feature Table addition | Reason | Verdict |
|-------------------|------|------|
| `Agent Teams permission dialog crash fix` | A crash fix in the CC core. No Harness-side change needed | C |

Result: OK. But state the reason explicitly.

---

### (P) Planned

Definition: items not implemented directly this time but worth incorporating into Harness, so they are left as explicit tasks in `Plans.md`.

Criteria:

- The Feature Table's added-value column reads as `A: future task` or `P: planned`
- There is a corresponding task in `Plans.md`, with the implementation side (setup / guardrails / memory / workflow, etc.) explicitly noted
- The reason for not implementing immediately (alpha release, large design change, etc.) is written

Examples:

| Feature Table addition | Carve-out into Plans | Verdict |
|-------------------|-------------------|------|
| `MCP Apps` | Workflow comparison-axis task | P |
| `New alpha-release feature` | Compare/investigate task after stabilization | P |

Result: OK. Can be picked up in the next cycle.

## Upstream update PR checklist

```markdown
## Claude Code update integration checklist

### 1. Primary sources and breakdown table
- [ ] The diff source is determined by either caller-provided or read-only git inspection
- [ ] Confirmed the official Claude Code URLs
- [ ] There is a table of Version / Upstream item / Category / Harness surface / Action
- [ ] There is a distinction of alpha / stable / docs-only

### 2. Feature Table diff
- [ ] Enumerated the added rows of `docs/CLAUDE-feature-table.md`
- [ ] Each row has one of A / C / P
- [ ] B is 0 items

### 3. Confirmation by category
- [ ] (A) Has implementation: there are corresponding implementation files and tests
- [ ] (B) Doc-only: 0 items. If any remain, block the PR
- [ ] (C) Auto-inheritance: confirmed permission / sandbox / security / workflow impact
- [ ] (P) Planned: there is a future task in `Plans.md`

### 4. Mirror and stale path
- [ ] No unintended drift between `skills/` and the `.agents/skills/` mirror
- [ ] If `.agents/skills/` exists, the notation is not broken
- [ ] No stale references such as the old TypeScript guardrail path

### 5. CHANGELOG / tests
- [ ] The CHANGELOG has "before / after" or an equivalent user-facing description
- [ ] An upstream integration test or a target unit test is added / updated
```

## Output format when Category B is detected

When one or more Category B items are detected, output an implementation proposal in the following format.
Outputting this format is mandatory; omission is not allowed.

```markdown
## Category B detected: implementation proposal

### B-{number}. {Feature Table item name}

**Current state**: Only listed in the Feature Table. No Harness-side implementation / verification / planning.

**Value unique to Harness**:
{Concrete explanation of how Harness should leverage this feature}

**Implementation proposal**:

| Target file | Change content |
|------------|---------|
| `{file path}` | {concrete change content} |
| `{file path}` | {concrete change content} |

**User experience improvement**:
- Before: {current user experience}
- After: {user experience after implementation}

**Implementation priority**: {high / medium / low}
**Estimated effort**: {small / medium / large}
```

## Related skills

- `claude-upstream-update` - upstream diff investigation and implementation cycle
- `harness-review` - code review
- `harness-work` - implementation of Category B / P
- `memory` - making the classification criteria an SSOT
