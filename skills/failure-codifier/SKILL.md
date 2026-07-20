---
name: failure-codifier
description: "Extract recurring failure patterns from breezing orchestration logs and Judgment Ledger, emit failure-rule.v1 proposals with confidence scores. SSOT promotion to patterns.md or decisions.md is proposal-only — human-approval-required. Use when user mentions failure codifier, failure patterns, self-learning loop, codify failures, or failure-rule proposals. Do NOT load for: direct SSOT edits, auto-promotion, or implementation unrelated to failure analysis."
description-en: "Extract recurring failure patterns from breezing orchestration logs and Judgment Ledger, emit failure-rule.v1 proposals with confidence scores. SSOT promotion to patterns.md or decisions.md is proposal-only — human-approval-required. Use when user mentions failure codifier, failure patterns, self-learning loop, codify failures, or failure-rule proposals. Do NOT load for: direct SSOT edits, auto-promotion, or implementation unrelated to failure analysis."
allowed-tools: ["Read", "Bash", "Grep"]
argument-hint: "[propose|explain]"
user-invocable: true
---

# Failure Codifier

Extracts recurring failures **read-only** from the breezing orchestration ledger + Judgment Ledger and proposes `failure-rule.v1` candidates with confidence scores.

## Core contract

- **human-approval-required**: the codifier makes dry-run proposals only. Auto-promotion to `patterns.md` / `decisions.md` is structurally prohibited.
- Confidence thresholds: occurrence **count ≥ 3 → medium**, **count ≥ 5 → high** (`go/internal/failurecodifier/confidence.go`).
- Promotion-target heuristic: only **proposes** `patterns.md` or `decisions.md` via the `proposed_ssot_target` field.

## Usage

### Dry-run proposal (recommended)

```bash
./scripts/failure-codifier-propose.sh --dry-run
```

stdout is a JSON array (`failure-rule.v1` candidates). It writes nothing to SSOT files.

### Go tests

```bash
cd go && go test ./internal/failurecodifier/... -count=1
```

## References

- Promotion workflow: [references/promotion-workflow.md](${CLAUDE_SKILL_DIR}/references/promotion-workflow.md)
- Schema: `templates/schemas/failure-rule.v1.json`
- Core: `go/internal/failurecodifier/`

## Prohibited

- Write / Edit to `patterns.md` / `decisions.md` (not allowed via the codifier even after human approval)
- `AutoPromote` / unattended SSOT updates
- Changing the `cc:*` markers in Plans.md
