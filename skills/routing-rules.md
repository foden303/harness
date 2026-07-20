# Skill Routing Rules (Reference)

A reference document for the routing rules between skills.

> **Where the SSOT lives**: Each skill's `description` field is the SSOT for routing.
> This file is a reference that provides detailed explanations and examples; actual routing depends on each skill's description.
>
> **Important**: Each skill's description and the "Do NOT Load For" table in its body must match exactly.

## Key Skill Routing

### harness-review

**Purpose**: Multi-angle review of code, plans, and scope before acceptance

**Trigger keywords** (quoted from description):
- "review", "code review", "plan review"
- "scope analysis", "security", "performance"
- "quality checks", "PRs", "diffs"
- "/harness-review"

**Exclusion keywords** (quoted from description):
- "implementation", "new features", "bug fixes"
- "setup", "release"

### harness-work

**Purpose**: Implement tasks from `Plans.md` (solo / parallel / breezing topologies)

**Trigger keywords**:
- "implement", "execute", "/work"
- "breezing", "team run"
- "--parallel"

**Exclusion keywords** (quoted from description):
- "planning", "code review", "release"
- "setup", "initialization"

**Invocation**: Run with `/harness-work`

## Routing Decision Flow (reference)

> This section explains Claude Code's internal behavior and is not an additional keyword definition.
> Actual routing is decided solely by the keywords in each skill's description.

```
User input
    │
    ├── Matches a trigger keyword in a description → load that skill
    ├── Matches an exclusion keyword in a description → exclude that skill
    └── Neither → normal skill matching
```

## Priority Rules (reference)

Priority when a keyword matches multiple skills:

1. **Exclusion takes top priority**: A skill matched by an exclusion keyword is never loaded
2. **Specific keywords win**: exact match > partial match

> **Note**: "Contextual judgment" is not used because it introduces ambiguity. Routing is decided deterministically by description keywords.

## Update Rules

1. **description = SSOT**: Each skill's `description` field is the formal definition for routing
2. **Match the body**: Each skill's "Do NOT Load For" table must match the description exactly
3. **This file's role**: A reference for detailed explanations and the decision flow (not the SSOT)
4. **Keep the list complete**: Avoid generic phrasing (e.g. "everything related to ~"); list specific keywords
