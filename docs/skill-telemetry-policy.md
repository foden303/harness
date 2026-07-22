# Skill Telemetry Policy (Phase 62.2.3)

> **Status**: Active (2026-05-07)
> **Scope**: operational rules for when the `invocation_trigger` field of the `claude_code.skill_activated` OTel event
> fired by Claude Code `2.1.126+` is recorded to a local ledger.

## In one line

Record the trigger type of skill activation (human / model / skill chain) to a **local ledger**,
as material to identify skills that activate needlessly.
When recording, always observe **privacy / retention / opt-out**.

## By analogy

It is similar to writing only the title of a book you read into a household budget book.
The content (the text = skill input / output) is not written; only when, by which type, and which book was read (the skill_activated event) is recorded.

## Premises of the telemetry sink design

Phase 58.2.3 already decided "the telemetry sink design comes first". This doc defines that sink specification.

| Item | Specification |
|------|------|
| Sink type | **local-only JSON Lines ledger** (no external transmission) |
| ledger path | `.claude/state/skill-trigger-stats.jsonl` |
| append method | **append-only** (append only; no compaction, no deletion) |
| acquisition path | receive the Claude Code OTel event via `scripts/skill-trigger-telemetry.sh` |
| output format | 1 JSON object per line |

## Recorded fields

Each record contains only the following fields. **No personally identifiable information is recorded**.

```json
{
  "timestamp": "2026-05-07T00:00:00Z",
  "skill_name": "harness-work",
  "invocation_trigger": "human|model|skill-chain",
  "session_id": "session-abc123",
  "duration_ms": 0
}
```

| field | Required | Description |
|-------|------|------|
| `timestamp` | yes | RFC3339 UTC |
| `skill_name` | yes | activated skill name (`harness-work`, `harness-review`, etc.) |
| `invocation_trigger` | yes | one of `human` / `model` / `skill-chain` |
| `session_id` | yes | CC session ID (truncated to the first 12 characters if 12 or more) |
| `duration_ms` | no | skill execution time. Recorded only when CC provides it |

**Fields not recorded**:
- the skill's input prompt
- the skill's output text
- user name / email address
- API token / credentials
- individual file paths (not recorded at a finer granularity than the skill name)

## Privacy principles

1. **local-only**: the ledger is placed in `.claude/state/` and not transmitted externally
2. **identifier minimization**: session_id is truncated to a prefix of 12 characters or fewer
3. **content opacity**: the skill's input/output text is not recorded
4. **opt-out capable**: disable via the environment variable `HARNESS_SKILL_TELEMETRY_DISABLE=1`

## retention

| Trigger | Retention period | Deletion timing |
|---------|---------|--------------|
| Default | **30 days** | `scripts/maintenance/prune-skill-telemetry.sh` (manual or cron) |
| user deletion request | immediate | `rm .claude/state/skill-trigger-stats.jsonl` |
| on repo clone / share | not shared | added to `.gitignore` (the existing .gitignore covers it via the blanket state-path exclusion) |

Manual deletion of records older than 30 days is **recommended**, but automatic deletion is not done (assuming cases where long-term retention is desired for audit purposes).
If deletion is implemented, use a rotation method (moving to `stats.jsonl.{date}`) to preserve the append-only property.

## opt-out

### Full disable

Disable via `.claude/settings.json` or an environment variable:

```bash
export HARNESS_SKILL_TELEMETRY_DISABLE=1
```

Or:

```json
{
  "env": {
    "HARNESS_SKILL_TELEMETRY_DISABLE": "1"
  }
}
```

### Partial disable (per skill)

Write an exclude list in `.claude/settings.local.json`:

```json
{
  "harness": {
    "skill_telemetry_exclude": ["harness-work", "harness-loop"]
  }
}
```

## Related docs

- Phase 58.2.3 (`docs/upstream-followups-phase58-2026-05-03.md`) — telemetry sink design decision
- The `.claude/state/elicitation/events.jsonl` ledger — follows the same append-only design
- Claude Code OTel reference (Anthropic docs)

## Acceptance conditions (Phase 62.2.3 DoD)

- [x] `docs/skill-telemetry-policy.md` exists (this doc)
- [x] privacy / retention / opt-out are documented
- [x] does not conflict with the Phase 58.2.3 decision (the sink design is fixed to local-only)
- [x] sink path: `.claude/state/skill-trigger-stats.jsonl`
- [x] schema: timestamp / skill_name / invocation_trigger / session_id / duration_ms

## References

- Claude Code 2.1.126 CHANGELOG: `claude_code.skill_activated` OTel event includes `invocation_trigger`
- Weak-supervision ledger design (privacy-first, append-only)
