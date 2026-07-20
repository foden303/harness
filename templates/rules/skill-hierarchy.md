---
_harness_template: rules/skill-hierarchy.md
_harness_version: 2.6.1
---

# Skill Hierarchy Guidelines

## Overview

harness skills use a two-layer structure of **parent skills (categories)** and **child skills (concrete features)**.

```
skills/
├── impl/                      # Parent skill (SKILL.md)
│   ├── SKILL.md              # Category overview / routing
│   └── work-impl-feature/    # Child skill
│       └── doc.md            # Concrete procedure
├── harness-review/
│   ├── SKILL.md
│   ├── code-review/
│   │   └── doc.md
│   └── security-review/
│       └── doc.md
...
```

## Required Rules

### 1. After reading a parent skill, read the child skill too

After launching a parent skill with the Skill tool, **always Read the child skill (doc.md) that matches the user's intent**.

```
✅ Correct flow:
1. Launch "impl" with the Skill tool → obtain SKILL.md content
2. Judge the user's intent (e.g., feature implementation)
3. Read work-impl-feature/doc.md with the Read tool
4. Follow the procedure in doc.md

❌ Wrong:
1. Launch "impl" with the Skill tool
2. Read only SKILL.md and start working (ignoring the child skill)
```

### 2. How to choose the child skill

| User's intent | Skill to launch | Child skill to read |
|---------------|---------------|-----------------|
| "Implement a feature" | impl | work-impl-feature/doc.md |
| "Do a code review" | harness-review | code-review/doc.md |
| "Security check" | harness-review | security-review/doc.md |
| "Build it" | verify | build-verify/doc.md |

### 3. When multiple child skills apply

Confirm with the user, or pick the single most relevant one and start.

---

## Why it matters

- The parent SKILL.md only holds "overview and routing"
- The child doc.md holds "concrete procedures, checklists, and pattern collections"
- Not reading the child skill leads to incomplete work

---

## Integration with the PostToolUse Hook

A reminder is shown automatically after using the Skill tool.
From the displayed list of child skills, Read the one that applies.
