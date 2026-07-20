---
name: init-memory-ssot
description: "Initialize the project's SSOT memory (decisions/patterns) and an optional session-log. Use during first-time setup or in projects where .claude/memory is not yet set up."
allowed-tools: ["Read", "Write"]
---

# Init Memory SSOT

Initializes the **SSOT** under `.claude/memory/`.

- `decisions.md` (SSOT for important decisions)
- `patterns.md` (SSOT for reusable solutions)
- `session-log.md` (session log; local operation recommended)

Detailed policy: `docs/MEMORY_POLICY.md`

---

## Execution Steps

### Step 1: Check for Existing Files

- `.claude/memory/decisions.md`
- `.claude/memory/patterns.md`
- `.claude/memory/session-log.md`

**Do not overwrite** any that already exist.

### Step 2: Initialize From Templates (only when absent)

Templates:

- `templates/memory/decisions.md.template`
- `templates/memory/patterns.md.template`
- `templates/memory/session-log.md.template`

Generate by replacing `{{DATE}}` with today's date (e.g. `2025-12-13`).

### Step 3: Completion Report

- List of created files
- Git policy (`decisions/patterns` recommended to share; `session-log/.claude/state` recommended local)


