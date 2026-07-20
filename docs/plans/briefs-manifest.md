# Optional Briefs and Skill Manifest

`harness-plan create` adds a brief only when needed. A brief does not replace Plans.md; it is a supporting document that briefly pins down the premises of an implementation.

The project spec SSOT is treated as the authoritative source above briefs. A brief pins down the short premises of an individual task such as a screen or an API, while the spec SSOT pins down the correctness conditions for the whole project.

Details: `docs/plans/spec-ssot.md`

## Design Brief

For tasks that involve UI, create a `design brief`.

Minimum content to include:

- What you want to achieve
- Who will use it
- Important screen states
- Constraints on look and feel
- Completion conditions

## Contract Brief

For tasks that involve an API, create a `contract brief`.

Minimum content to include:

- What it receives / returns
- Input validation conditions
- Behavior on failure
- External dependencies
- Completion conditions

## Skill Manifest

`scripts/generate-skill-manifest.sh` turns the `SKILL.md` frontmatter across the repo into stable JSON.

When to use:

- Auditing the skill surface
- Comparing between mirrors
- Input for automatic docs generation

The output includes the following.

- `name`
- `description`
- `do_not_use_for`
- `allowed_tools`
- `argument_hint`
- `effort`
- `user_invocable`
- `surface`
- `related_surfaces`

`related_surfaces` also includes mirror information such as `skills`.

## Execution Example

```bash
scripts/generate-skill-manifest.sh --output .claude/state/skill-manifest.json
```
