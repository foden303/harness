# GitHub Release Notes Rules

Formatting rules applied when creating GitHub Release notes.

## Required Format

### Structure

```markdown
## What's Changed

**One-line description of the change's value**

### Before / After

| Before | After |
|--------|-------|
| Previous state | New state |
| ... | ... |

---

## Added

- **Feature name**: Description
  - Detail 1
  - Detail 2

## Changed

- **Change**: Description

## Fixed

- **Fix**: Description

## Requirements (if applicable)

- **Claude Code vX.X.X+** (recommended)
- Link: [Documentation](URL)

---

Generated with [Claude Code](https://claude.com/claude-code)
```

### Required Elements

| Element | Required | Description |
|---------|----------|-------------|
| `## What's Changed` | Yes | Section heading |
| **Bold summary** | Yes | One-line value description |
| `Before / After` table | Yes | User-facing changes |
| `Added/Changed/Fixed` | When applicable | Detailed changes |
| Footer | Yes | `Generated with [Claude Code](...)` |

### Language

- **GitHub Release**: English required (because the repository is public)
- **CHANGELOG.md**: detailed Before/After format in **English** (see below)
- Keep descriptions user-focused

## CHANGELOG format (detailed Before/After)

Describe each feature in the CHANGELOG concretely in the Before → After format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Theme: [the whole change in one line]

**[the value to the user in 1-2 sentences]**

---

#### 1. [Feature name]

**Before**: [old behavior; concretely describe the inconvenience the user experienced]

**After**: [new behavior; what it solves + a concrete example]

```output or command example```

#### 2. [Next feature name]

**Before**: ...
**After**: ...
```

**Writing rules**:
- Make each feature an independent section with `#### N. Feature name`
- The **Before** part is a **problem description** (in the "you had to ..." form)
- The **After** part is a **concrete picture of the solution** (include command and output examples)
- Length is fine; readability is the top priority
- Keep technical details (file names, step numbers) minimal, as supplements to the **After** part

## Prohibited

- No skipping the Before / After (CHANGELOG) or Before / After table (GitHub Release)
- No skipping the footer (GitHub Release)
- No technical-only descriptions (user perspective required)
- No bare change lists without value explanation

## Good Example (GitHub Release — English)

```markdown
## What's Changed

**`/work --full` now automates implement -> self-review -> improve -> commit in parallel**

### Before / After

| Before | After |
|--------|-------|
| `/work` executes tasks one at a time | `/work --full --parallel 3` runs in parallel |
| Reviews required separate manual step | Each task-worker self-reviews autonomously |
```

## Good Example (CHANGELOG)

```markdown
#### 1. Automatic re-ticketing of failed tasks

**Before**: When a test/CI failed, it would just retry three times and stop.
After it stopped, you had to investigate "what caused it" yourself and manually add a fix task to Plans.md.

**After**: When it stops after three failures, Harness classifies the failure cause and auto-generates a fix-task proposal.
Once approved, it is automatically added to Plans.md as a `.fix` task.
```

## Bad Example

```markdown
## What's New

### Added
- Added task-worker.md
- Added --full option
```

-> Doesn't communicate user value

## Release Creation Command

```bash
gh release create vX.X.X \
  --title "vX.X.X - Title" \
  --notes "$(cat <<'EOF'
## What's Changed
...
EOF
)"
```

## Editing Past Releases

```bash
gh release edit vX.X.X --notes "$(cat <<'EOF'
...
EOF
)"
```

## CHANGELOG pattern for CC version integration

For releases that include integration of a new Claude Code version, use the
**"CC update → use in Harness" format** instead of the usual Before / After format.
Explaining from the reason for the upstream (CC) change lets readers understand from context "why this change is relevant to me".

### Applicability conditions

Apply this pattern when any of the following holds:

- The version notation in the Feature Table is updated
- A new CC-derived event is added to hooks.json
- A usage guide for a new CC feature is added to the skills

### Structure

```markdown
#### N. Claude Code X.Y.Z integration

(one-line overview)

##### N-1. Feature name

**CC update**: What changed in Claude Code. Explain from the user's perspective so it is clear what the feature does.

**Use in Harness**: How Harness leverages that change. Include the concrete mechanism (script name, flow).

##### N-2. Next feature name

**CC update**: ...
**Use in Harness**: ...
```

### Writing rules

- Make each feature an independent section with `##### N-X.`
- For the CC update, write the **change in user experience**, not the file changes
- For the use in Harness, write the **concrete mechanism** (what runs, what is prevented)
- Avoid listing file names. Write "prevents Worker freeze" rather than "updates hooks.json"
- Do not give documentation-only changes (Feature Table updates, adding a detail section) their own entry; include them in the one-line overview at the top

### Good Example

```markdown
##### 5-1. Automatic handling of MCP Elicitation

**CC update**: MCP servers can now "ask" the user a question during task execution (Elicitation).
For example, you may be prompted for form input like "Which repository do you want to push to?".

**Use in Harness**: Breezing Workers run in the background and cannot respond to a question form.
Left alone, the Worker freezes. We added a new elicitation-handler.sh that
auto-skips during a Breezing session, and passes through normally in a regular session so the user answers.
```

### Bad Example

```markdown
#### CC 2.1.76 integration

- Add Elicitation to hooks.json
- Create elicitation-handler.sh
- Update CLAUDE.md
```

→ A list of file changes that does not convey why the change was needed or what changes for the user

## Reference

- Good examples: v2.8.0, v2.8.2, v2.9.1, v3.10.3 (CC integration pattern)
- Keep consistent with CHANGELOG
