# cross-project-group.v1 Schema

Introduced in Phase 65.3 (Cross-Project Group + 3-Layer Redaction).
Schema specification for `.claude/rules/cross-project-groups.yaml`.

## Purpose

The SSOT for group definitions that let client-side skills such as
Plan Brief / Acceptance Demo / Progress Tracker opt into **cross-project search**.

Cross-project search is disabled by default. Only when a group name is
explicitly specified with the `--cross-project-group <name>` flag does it issue
`mcp__harness__harness_mem_search` against that group's member projects.

## Schema

```yaml
schema_version: cross-project-group.v1

groups:
  - name: <string>            # group identifier
    description: <string?>    # optional (description of the group's purpose)
    members:                  # array, unique elements, may be empty
      - <string>              # member project name
      - <string>
```

## Constraints

| Field | Type | Required | Constraint |
|---|---|---|---|
| `schema_version` | string | ✓ | Fixed to `cross-project-group.v1` |
| `groups` | array | ✓ | Empty array `[]` allowed |
| `groups[].name` | string | ✓ | Unique within `groups`, non-empty |
| `groups[].description` | string | optional | Optional |
| `groups[].members` | array | ✓ | Array, unique elements, may be empty |
| `groups[].members[]` | string | - | Non-empty, no duplicates |

## Validation

`scripts/load-cross-project-groups.sh` parses the yaml and halts with
**exit 1** when it detects an invalid schema.

Invalid conditions detected:

1. `schema_version` mismatch (anything other than `cross-project-group.v1`)
2. `groups` is not an array
3. `groups[].name` missing / empty / duplicated
4. `groups[].members` is not an array / has duplicate elements / empty string
5. `groups[].members[]` is not a string

## Usage Examples

### CLI (calling the loader script directly)

```bash
# Output all groups as JSON
bash scripts/load-cross-project-groups.sh

# Output a specific group's members as a JSON array
bash scripts/load-cross-project-groups.sh --group "Personal Tools"
# → ["my-cli","my-dotfiles","my-scripts"]

# A non-existent group exits 1
bash scripts/load-cross-project-groups.sh --group "Unknown"
# → stderr: "group not found: Unknown" / exit 1
```

### Via Skill (planned for Phase 65.3.5)

```bash
# No cross-project search (default, current project only)
/harness-plan-brief "I want to introduce a new CI"

# Cross-project search opt-in (search all members of the Personal Tools group)
/harness-plan-brief "I want to introduce a new CI" --cross-project-group "Personal Tools"
```

## Cross-Project Search Implementation (D43 Option α)

```
client skill (Plan Brief / Accept / Progress)
   │
   │ --cross-project-group <name>
   ▼
load-cross-project-groups.sh --group <name>
   │
   │ JSON array of member projects
   ▼
For each member in members:
   mcp__harness__harness_mem_search(project=member, ...)
   │
   ▼
merge and dedupe on the client side (by relevance_score)
   │
   ▼
Layer 2a (dictionary) redacts proper nouns → generate HTML
```

For the detailed responsibility boundary between the server-side (Layer 1) and
client-side (Layer 2a) redaction layers, see [cross-project-safety.md](cross-project-safety.md).

## Related

- `.claude/rules/cross-project-groups.yaml` — SSOT for this schema (default `groups: []`)
- `scripts/load-cross-project-groups.sh` — yaml → JSON parser + validator
- `tests/test-cross-project-groups-schema.sh` — 4-case machine verification
- `.claude/rules/client-redaction.yaml` — Layer 2a dictionary (planned for Phase 65.3.2)
- Plans.md §65.3.1-65.3.7 — all Phase C tasks
