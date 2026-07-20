---
name: migrate-workflow-files
description: "Migrate an existing project's AGENTS.md/CLAUDE.md/Plans.md to the new format — reviewing existing content and confirming carry-over items interactively (with backups; Plans uses a task-preserving merge)."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
---

# Migrate Workflow Files (Interactive Merge)

## Purpose

Update the following files in use in an existing project **to the new format while respecting the existing content**.

- `AGENTS.md`
- `CLAUDE.md`
- `Plans.md`

Key points:

- **Confirm carry-over information interactively** (never discard or overwrite without consent)
- **Always keep a backup** before making changes
- For `Plans.md`, follow the `merge-plans` approach to **update the structure while preserving tasks**

---

## Prerequisites (Important)

To balance "safety on first application" with "intended behavior (new format)", this skill
proceeds in the order **user consent → backup → generation → diff review**.

---

## Inputs (may be auto-detected within this skill)

- `project_name`: inferred with `basename $(pwd)`
- `date`: `YYYY-MM-DD`
- Presence of existing files:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `Plans.md`
- Reference templates for the new format:
  - `templates/AGENTS.md.template`
  - `templates/CLAUDE.md.template`
  - `templates/Plans.md.template`

---

## Execution Flow

### Step 0: Detection and Consent (required)

1. Use `Read` to confirm whether `AGENTS.md` / `CLAUDE.md` / `Plans.md` exist.
2. If they exist, confirm with the user:
   - **Whether it's OK to migrate (update to the new format)**
   - Important: migration **includes reorganizing content** (= some rearrangement and wording changes may occur)

If the user says NO:

- Abort this skill (rewrite nothing)
- Instead, propose safe work such as "just a safe merge of `.claude/settings.json`"

### Step 1: Review the Existing Content (summary)

`Read` each file, then extract and present a short summary of:

- **AGENTS.md**: role split, handoff procedures, prohibitions, environment/assumptions
- **CLAUDE.md**: important constraints (prohibitions/permissions/branch operation), test procedures, commit conventions, operational rules
- **Plans.md**: task structure, marker usage, current WIP / requested tasks

### Step 2: Confirm Carry-over Items (interactive)

Based on the summary, ask the user which items to **preserve/adjust** (5–10 questions is enough):

- Constraints that must absolutely be kept (e.g. no production deploys, forbidden directories, security requirements)
- Role-split (Solo/2-agent) assumptions
- Branch operation (main/staging, etc.)
- Representative test/build commands
- Plans marker usage (align with existing rules if any)

### Step 3: Create Backups (required)

Collect backups under the project's `.harness/backups/` (often you won't want these in git).

Example:

- `.harness/backups/2025-12-13/AGENTS.md`
- `.harness/backups/2025-12-13/CLAUDE.md`
- `.harness/backups/2025-12-13/Plans.md`

You may use `mkdir -p` and `cp` via `Bash`.

### Step 4: Generate the New Format (merge)

#### 4-1. Plans.md (task-preserving merge)

Run using the `merge-plans` approach:

- Preserve existing 🔴🟡🟢📦 tasks
- Update the marker legend and last-updated info from the template
- If unparseable, keep a backup and adopt the template

#### 4-2. AGENTS.md / CLAUDE.md (template + carry-over block)

Build the skeleton from the template, and **relocate the items confirmed in Step 2 to the appropriate places in the new format**.

Minimum policy:

- Do not drop existing "important rules"; keep them as a **"Project-specific Rules (migrated)"** section
- Rewrite the role split/flow to match the template's format (keeping the meaning)

### Step 5: Diff Review and Completion

- Briefly summarize the changes via `git diff` (or file diff)
- Final check that key points (permissions/prohibitions/task state) are as intended
- Fix immediately if there are issues

---

## Deliverables (completion criteria)

- **New-format versions** of `AGENTS.md` / `CLAUDE.md` / `Plans.md` that reflect the existing content
- Backups remain under `.harness/backups/`
- No Plans tasks are lost (preserved)


