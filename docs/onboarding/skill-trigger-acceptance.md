# Bootstrap / Skill Trigger Acceptance

Phase 73 treats installation as incomplete until the first workflow trigger is
observable. Superpowers inspired this gate with explicit and implicit skill
trigger tests, but Harness keeps the claim boundary stricter: static packaging
evidence is not runtime support evidence.

## Required Harness Workflows

These workflows must exist on every claimed or internal-compatible surface:

| Workflow | Claude Code trigger | Intent fixture |
|---|---|---|
| `harness-plan` | `/harness-plan` | Create a scoped plan with acceptance criteria. |
| `harness-work` | `/harness-work` | Execute the next `Plans.md` task with TDD and verification. |
| `harness-review` | `/harness-review` | Review changes before merge. |
| `harness-release` | `/harness-release` | Prepare release or PR closeout evidence. |
| `harness-setup` | `/harness-setup` | Check install/setup health. |
| `breezing` | `/harness-work breezing all` | Run team execution for ready tasks. |

## Acceptance Rules

- Claude Code explicit and implicit trigger acceptance checks the shipped
  `skills/<name>/SKILL.md` entries.
- `not_observed != absent`: if a host runtime is unavailable, record the reason
  and keep the host at its current support tier.
- Release preflight must run the skill-trigger acceptance gate for claimed
  adapter surfaces. Claimed hosts without smoke evidence are release blockers;
  candidate and unsupported hosts stay as evidence docs only.
