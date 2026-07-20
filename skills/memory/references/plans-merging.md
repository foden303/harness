---
name: merge-plans
description: "Skill that merge-updates Plans.md (preserving user tasks). Use when you need to consolidate multiple Plans.md files."
allowed-tools: ["Read", "Write", "Edit"]
---

# Merge Plans Skill

A skill that applies the template structure while preserving the user's task data
when updating an existing Plans.md.

---

## Purpose

- Preserve user tasks (🔴🟡🟢📦 sections)
- Update the template structure and marker definitions
- Update the last-updated info

---

## Plans.md Structure

```markdown
# Plans.md - Task Management

> **Project**: {{PROJECT_NAME}}
> **Last updated**: {{DATE}}
> **Updated by**: Claude Code

---

## 🔴 In-progress tasks        ← user data (preserved)

## 🟡 Not-started tasks         ← user data (preserved)

## 🟢 Completed tasks           ← user data (preserved)

## 📦 Archive                   ← user data (preserved)

## Marker Legend                ← updated from template

## Last-updated Info            ← date updated
```

---

## Merge Algorithm

### Step 1: Section Splitting

```
Split the existing Plans.md into these sections:

1. Header part (# Plans.md ... ---)
2. 🔴 In-progress tasks (up to the next section)
3. 🟡 Not-started tasks (up to the next section)
4. 🟢 Completed tasks (up to the next section)
5. 📦 Archive (up to the next section)
6. Marker legend (up to the next section)
7. Last-updated info (to end of file)
```

### Step 2: Extracting Task Sections

```bash
extract_section() {
  local file="$1"
  local start_marker="$2"
  local end_markers="$3"  # pipe-separated end markers

  awk -v start="$start_marker" -v ends="$end_markers" '
    BEGIN { in_section = 0; split(ends, end_arr, "|") }
    $0 ~ start { in_section = 1; next }
    in_section {
      for (i in end_arr) {
        if ($0 ~ end_arr[i]) { in_section = 0; exit }
      }
      if (in_section) print
    }
  ' "$file"
}

# Extract each section
TASKS_WIP=$(extract_section "$PLANS_FILE" "## 🔴" "## 🟡|## 🟢|## 📦|## Marker|---")
TASKS_TODO=$(extract_section "$PLANS_FILE" "## 🟡" "## 🔴|## 🟢|## 📦|## Marker|---")
TASKS_DONE=$(extract_section "$PLANS_FILE" "## 🟢" "## 🔴|## 🟡|## 📦|## Marker|---")
TASKS_ARCHIVE=$(extract_section "$PLANS_FILE" "## 📦" "## 🔴|## 🟡|## 🟢|## Marker|---")
```

### Step 3: Validating Tasks

```bash
# Confirm not empty
count_tasks() {
  echo "$1" | grep -c "^\s*- \[" || echo "0"
}

WIP_COUNT=$(count_tasks "$TASKS_WIP")
TODO_COUNT=$(count_tasks "$TASKS_TODO")
DONE_COUNT=$(count_tasks "$TASKS_DONE")
ARCHIVE_COUNT=$(count_tasks "$TASKS_ARCHIVE")

echo "Tasks preserved:"
echo "  In progress: $WIP_COUNT"
echo "  Not started: $TODO_COUNT"
echo "  Completed: $DONE_COUNT"
echo "  Archived: $ARCHIVE_COUNT"
```

### Step 4: Generating the New Plans.md

```markdown
# Plans.md - Task Management

> **Project**: {{PROJECT_NAME}}
> **Last updated**: {{DATE}}
> **Updated by**: Claude Code

---

## 🔴 In-progress tasks

<!-- List cc:WIP tasks here -->

{{TASKS_WIP}}

---

## 🟡 Not-started tasks

<!-- List cc:TODO, pm:pending tasks here -->

{{TASKS_TODO}}

---

## 🟢 Completed tasks

<!-- List cc:done, pm:confirmed tasks here -->

{{TASKS_DONE}}

---

## 📦 Archive

<!-- Move old completed tasks here -->

{{TASKS_ARCHIVE}}

---

## Marker Legend

| Marker | Meaning |
|--------|---------|
| `pm:pending` | Task requested by PM |
| `cc:TODO` | Claude Code not started |
| `cc:WIP` | Claude Code in progress |
| `cc:done` | Claude Code done (awaiting review) |
| `pm:confirmed` | PM review complete |
| `blocked` | Blocked (note the reason) |

---

## Last-updated Info

- **Updated at**: {{DATE}}
- **Last session by**: Claude Code
- **Branch**: main
- **Update type**: Plugin update
```

---

## Handling Empty Sections

When a task list is empty, insert default text:

```markdown
## 🔴 In-progress tasks

<!-- List cc:WIP tasks here -->

(none currently)
```

---

## Error Handling

### When Plans.md Cannot Be Parsed

```bash
if ! validate_plans_structure "$PLANS_FILE"; then
  echo "⚠️ Could not parse the Plans.md structure"
  echo "Keeping a backup and using a fresh template"

  # Backup
  cp "$PLANS_FILE" "${PLANS_FILE}.bak.$(date +%Y%m%d%H%M%S)"

  # Use template
  use_template_instead=true
fi
```

### When Required Sections Are Missing

Fill in missing sections with the template defaults.

---

## Output

| Item | Description |
|------|-------------|
| `merge_successful` | Merge success flag |
| `tasks_wip_count` | In-progress task count |
| `tasks_todo_count` | Not-started task count |
| `tasks_done_count` | Completed task count |
| `tasks_archive_count` | Archived task count |
| `backup_created` | Whether a backup was created |

---

## Usage Example

```bash
# Invoke the skill
merge_plans \
  --existing "./Plans.md" \
  --template "$PLUGIN_PATH/templates/Plans.md.template" \
  --output "./Plans.md" \
  --project-name "my-project" \
  --date "$(date +%Y-%m-%d)"
```

---

## Related Skills

- `update-2agent-files` - Whole update flow
- `generate-workflow-files` - Fresh generation
