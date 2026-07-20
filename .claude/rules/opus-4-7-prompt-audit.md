---
description: Agent prompt audit rule for Phase 44 / 2.1.111
globs:
  - "agents/worker.md"
  - "agents/reviewer.md"
  - "agents/advisor.md"
  - "docs/team-composition.md"
---

# Opus 4.7 Prompt Audit Rule

The audit criteria for updating agent prompts and team composition in Phase 44 / 2.1.111.

## Pass conditions

1. Every action instruction must include one of the following.
   - An executable command name
   - A file path
   - A JSON schema name
   - A numeric threshold
   - A condition whose truth value can be determined
2. When writing count control, write the upper bound as a number.
   - Example: `up to 3 times`
   - Example: `when the same-cause failure occurs twice in a row`
3. When writing an output format, fix the schema name and enum values.
   - `advisor-request.v1`
   - `advisor-response.v1`
   - `review-result.v1`
   - `worker-report.v1`
   - `PLAN | CORRECTION | STOP`
   - `APPROVE | REQUEST_CHANGES`
   - `self_review[].rule` enum values (default 6): `dry-violation-none | plans-cc-markers-untouched | all-declared-symbols-called | dod-items-verified-with-evidence | no-existing-test-regression | tdd-red-evidence-attached`
   - `memory_updates[].scope` enum values: `universal | task-specific` (a plain string array is treated as `task-specific` for backward compatibility)
4. Write the 2.1.111 operational knobs by separating the agent contract from the operator entrypoint.
   - `xhigh`: the reasoning effort the caller chooses. The agent prompt does not infer it from a free-text marker
   - `/ultrareview`: the caller's review entrypoint. On the agent definition side, make `review-result.v1` the contract
   - `--auto-mode`: opt-in rollout. Do not write it as a default value
5. Make the boundary of permissions and responsibilities determinable in one line per agent.
   - Only the Lead spawns teammates
   - The Worker returns `advisor-request.v1` and does not spawn the Advisor directly
   - The Reviewer only makes quality judgments and does not implement
6. In `team-composition.md`, write the condition for the number of parallel workers as a number.
   - `1`: the change targets one group, or the files being written overlap
   - `2`: two independent write groups
   - `3`: three or more independent write groups
7. In this phase, do not include `skills/`, `docs/`, or `mirror` as update targets.

## Handling ambiguous words

When using the following words, supplement the condition in the same sentence immediately after or in the following bullet list.
(These are the literal search targets of the `rg` command under "Recommended verification commands". Now that agent prompts are English, the audit searches for English vague words.)

- `as needed`
- `as appropriate`
- `properly`
- `sufficiently`
- `flexibly`
- `firmly`
- `if possible`
- `depending on the case`
- `independent task`
- `high risk`

If there is no supplement, it fails.

## Checklist

- [ ] No undocumented keys added to the frontmatter
- [ ] There is a file to read or a check item within the first 3 steps of `initialPrompt`
- [ ] The retry / escalation / review loop count limits are written as numbers
- [ ] The output JSON schema names and enum values are fixed
- [ ] No legacy free-text markers like `ultrathink` are left in the agent contract
- [ ] `xhigh` and `/ultrareview` are written as operator-side specifications
- [ ] `--auto-mode` is not written as a default value
- [ ] The reviewer's verdict conditions are consistent with `critical | major | minor`
- [ ] The advisor's `STOP` condition has a `stop_reason`
- [ ] The spawn permission in team composition is limited to the Lead
- [ ] Instructions that should apply broadly explicitly state their scope (all items / each file, etc.)
- [ ] Requests for deep reasoning are written as an effort tier and do not use free-text markers (`ultrathink`, etc.)

## Recommended verification commands

```bash
rg -ni "as needed|as appropriate|properly|sufficiently|flexibly|if possible|depending on the case" \
  agents/worker.md agents/reviewer.md agents/advisor.md docs/team-composition.md

rg -n "ultrathink|xhigh|/ultrareview|auto-mode|advisor-request.v1|advisor-response.v1|review-result.v1|worker-report.v1|REQUEST_CHANGES|PLAN|CORRECTION|STOP" \
  .claude/rules/opus-4-7-prompt-audit.md agents/worker.md agents/reviewer.md agents/advisor.md docs/team-composition.md
```
