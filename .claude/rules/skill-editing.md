# Skill File Editing Rules

SSOT (Single Source of Truth) rules for editing skill files (`skills/<skill-name>/`).

> **Note**: As of v2.17.0, custom slash commands have been migrated to skills.
> Skills are the preferred approach for new functionality.

## SSOT Principles

### 1. Directory Structure

Each skill lives in its own directory:

```
skills/
└── <skill-name>/
    ├── SKILL.md           # Main skill definition (required)
    └── references/        # Supporting files (optional)
        ├── feature1.md
        ├── feature2.md
        └── ...
```

> **Recommended (CC v2.1.69+)**: When linking from `SKILL.md` to reference files,
> use `${CLAUDE_SKILL_DIR}/references/...` instead of the relative path `references/...`.
> This gives a stable reference independent of where the skill runs.

### 2. YAML Frontmatter Format (Required)

**All SKILL.md files must use this frontmatter**:

```yaml
---
name: skill-name
description: "English description for auto-loading. Include trigger phrases."
allowed-tools: ["Read", "Write", "Edit", "Bash", ...]
---
```

### 3. Available Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (matches directory name) |
| `description` | Yes | English description for auto-loading (include trigger phrases). Token-efficient. |
| `allowed-tools` | No | Tools the skill can use (allowlist — not a restriction list) |
| `disallowed-tools` | No | CC 2.1.152+: tools to remove from the model while the skill is active |
| `argument-hint` | No | Usage hint (e.g., `"[option1|option2]"`) |
| `disable-model-invocation` | No | Set `true` for dangerous operations |
| `user-invocable` | No | Set `false` for internal-only skills |
| `context` | No | `fork` for isolated context |
| `hooks` | No | Event hooks configuration |

### 4. File Size Guidelines

| Guideline | Recommendation |
|-----------|----------------|
| SKILL.md | 500 lines or fewer recommended |
| Large content | Split into `references/` files |
| References | Use descriptive filenames |

> **Note (CC 2.1.32+)**: A skill's character budget auto-scales to **2%** of the context window.
> 500 lines is only a recommendation; the effective limit depends on the model's context window size.
> Large skill files may be trimmed automatically, so place important information
> near the top of SKILL.md and split details into `references/`.

### 5. Description Best Practices

The `description` field is critical for auto-loading. Include:
- What the skill does
- Trigger phrases (e.g., "Use when user mentions...")
- What NOT to load for (e.g., "Do NOT load for: ...")

**Good example**:
```yaml
description: "Manages CI/CD failures. Use when user mentions CI failures, build errors, or test failures. Do NOT load for: local builds or standard implementation."
```

## Client Mirror Contract (Phase 99.2)

`skills/` is the SSOT for shared skills.
Mirrors are read-only distribution copies — never edit mirror roots directly:

| Mirror root | Source |
|-------------|--------|
| `.agents/skills/` | Optional; missing root is `not-configured`, not drift |

After editing any file under `skills/`:

1. Run `./scripts/sync-skill-mirrors.sh` to refresh mirrors (or `./scripts/sync-skill-mirrors.sh --check` / `harness mirror verify --json` to verify only).
2. Expect a PostToolUse warning when `mirror-state.v1` reports `reason: "drift"`.
3. Treat missing `.agents/skills/` as unconfigured — do not create it unless your host requires that mirror.

Drift detection emits `mirror-state.v1` JSON (`schema_version`, `fingerprint`, `healthy`, `reason`, `mirrors[]`).
Tri-state per mirror: `in-sync`, `drift`, `not-configured`. Auto-sync is **not** enabled by default; mirrors are updated deliberately via the sync script.

**Bad example**:
```yaml
description: "CI skill"
```

## Skill File Structure Template

### SKILL.md Template

```markdown
---
name: skill-name
description: "Description with trigger phrases. Use when... Do NOT load for..."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[subcommand|option]"
---

# Skill Name

Overview description of the skill.

## Quick Reference

- "**trigger phrase 1**" → this skill
- "**trigger phrase 2**" → this skill

## Features / Deliverables

| Feature | Reference |
|---------|-----------|
| **Feature 1** | See [feature1.md](${CLAUDE_SKILL_DIR}/references/feature1.md) |
| **Feature 2** | See [feature2.md](${CLAUDE_SKILL_DIR}/references/feature2.md) |

## Execution Flow

1. Parse user request
2. Load appropriate reference file
3. Execute steps from reference
4. Report results

## Related Skills

- `related-skill-1` - Description
- `related-skill-2` - Description
```

### Reference File Template

```markdown
# Feature Name Reference

Detailed documentation for this feature.

## When to Use

- Condition 1
- Condition 2

## Execution Steps

### Step 1: ...

### Step 2: ...

## Examples

### Example 1

...

## Troubleshooting

### Issue 1

**Cause**: ...
**Solution**: ...
```

## Editing Checklist

When creating or editing skill files:

- [ ] SKILL.md has required frontmatter (`name`, `description`)
- [ ] `name` matches directory name
- [ ] `description` includes trigger phrases and exclusions
- [ ] SKILL.md is 500 lines or fewer (recommended; use references for large content; 2% budget scaling applies)
- [ ] References are under `references/` and linked via `${CLAUDE_SKILL_DIR}/references/...`
- [ ] Related skills documented
- [ ] Add entry to CHANGELOG.md (for new skills)
- [ ] Bump VERSION (automatic or manual)

## Migration from Commands

Commands have been migrated to skills. Key differences:

| Aspect | Commands (Legacy) | Skills (Current) |
|--------|-------------------|------------------|
| Location | `commands/` | `skills/` |
| Structure | Single file | Directory with SKILL.md + references |
| Frontmatter | `description` only | Full skill configuration |
| Auto-loading | Limited | Full description-based matching |
| Supporting files | Not supported | `references/` subdirectory |

## auto-start pattern for `context: fork` + `disable-model-invocation: true`

A skill with `context: fork` runs in an isolated context and does not inherit the host project's CLAUDE.md.
In practice, however, host session-start rules have leaked into the fork, causing the skill to halt with "task is unclear" —
a phenomenon observed 6 times in total (Issue #84). This section defines the countermeasure pattern.

### fork inheritance behavior

- A `context: fork` skill creates a new isolated context on startup
- The parent session's CLAUDE.md / session-start rules are, in principle, not inherited
- However, due to CC's implementation, cases have been confirmed where host project rules flow into the fork (#84)
- The leaked-in rules act as a halt trigger, e.g. "first confirm clear instructions"

### auto-start pattern implementation guide

When a `context: fork` skill needs to start immediately and automatically, implement the following 3 points at the top of Step 0 in SKILL.md:

#### (1) Place a machine-readable condition literally within the first 3 lines

```
if $ARGUMENTS == "":
  → start {the automatic processing}
  → "task is unclear" / "wait for further instructions" are prohibited actions
```

By placing this conditional block within 3 lines directly under the Step 0 heading,
you guarantee the branch is read first, mechanically, even if other rules flow in.

#### (2) Explicitly enumerate prohibited actions

List halt patterns as concrete wording, at least 3 items.
Rather than a vague "do not halt," literally enumerate the observed patterns ("task is unclear," "awaiting further instructions," etc.)
to override host rules at the wording level.

#### (3) State the `*_AUTOSTART` marker contract

Write a contract that always outputs an identifying marker in the first response when called without arguments:

```
REVIEW_AUTOSTART: base_ref={ref}, type=code
```

This contract has the following effects:
- Humans and monitoring scripts can confirm the auto-start
- The behavioral contract of emitting a marker fixes the first move of the response from "halt" to "execute"
- `grep -c 'REVIEW_AUTOSTART' skills/*/SKILL.md` can check for missing implementations

### Reference: harness-review implementation example

Step 0 of `skills/harness-review/SKILL.md` is the reference implementation of the 3 patterns above.
Apply the same pattern if a similar problem occurs in another skill.

## Related Documentation

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [CLAUDE.md](../../CLAUDE.md) - Project Development Guide
