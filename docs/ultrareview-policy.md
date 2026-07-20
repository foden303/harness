# Integration policy for `/ultrareview` and `/harness-review`

Policy document finalized in Phase 44.8.1.

---

## 1. Behavior of `/ultrareview`

`/ultrareview` is a **built-in slash command** added in Claude Code 2.1.111.
From Claude Code 2.1.120 onward, `claude ultrareview [target] --json` is also available for use from CI or scripts.

| Attribute | Content |
|------|------|
| Session type | single-turn dedicated review session |
| Executor | CC native (outside the Harness agent) |
| Input | current working tree diff (collected automatically) |
| Output | inline natural-language review result |
| Output schema | undefined (CC internal format) |
| CLI entry | `claude ultrareview [target] --json` (for CI / ad-hoc second-opinion) |
| Plans.md integration | none |
| sprint-contract verification | none |
| Reviewer agent invocation | none |

`/ultrareview` is an entrypoint where "the user directly asks CC for an ad-hoc review", and it operates outside Harness's automation flow (Plan → Work → Review).
`claude ultrareview [target] --json` has the same positioning: it is an entry to call auxiliarily from CI, not a replacement for `/harness-review`.

---

## 2. Differences from `/harness-review`

| Aspect | `/ultrareview` | `/harness-review` |
|------|----------------|-------------------|
| Executor | CC native | Harness skill (context: fork) |
| Session | single-turn | multi-step (Step 0–4) |
| Plans.md integration | none | yes (cc:WIP check, cc:done update) |
| sprint-contract verification | none | yes (`.claude/state/contracts/<task>.sprint-contract.json`) |
| Reviewer agent | none | yes (`reviewer` agent, `review-result.v1` output) |
| Output schema | undefined | `review-result.v1` (machine-readable JSON) |
| AI Residuals scan | none | yes (`scripts/review-ai-residuals.sh`) |
| Fix loop | none | yes (on REQUEST_CHANGES, up to 3 times) |
| Security-only mode | none | yes (`--security`, OWASP Top 10) |
| UI Rubric mode | none | yes (`--ui-rubric`, 4-axis scoring) |
| Target user | the user directly | automatic invocation by the Lead / breezing flow |

### 2.1 Positioning of `claude ultrareview [target] --json`

`claude ultrareview [target] --json` is a CLI entry to invoke CC-native ad-hoc review from non-interactive CI or a local script.

Harness handles it as follows.

| Use | Decision |
|------|------|
| Auxiliary review in PR CI | Allowed. Treat as a second opinion |
| Replacement for `/harness-review` | Not allowed. Does not produce the `review-result.v1` contract |
| Deciding the REQUEST_CHANGES fix loop | Not allowed. The output schema is not a Harness contract |
| Quickly scanning a large diff locally | Allowed. Treat as an ad-hoc review |

---

## 3. Finalized policy: **(B) `/harness-review` priority — do not call `/ultrareview` within the Harness flow**

### 3.1 rationale

**Consistency with rule 5**: `.claude/rules/opus-4-7-prompt-audit.md` states that
"`/ultrareview` is the caller's review entrypoint; on the agent-definition side, make `review-result.v1` the contract".
The Harness Reviewer agent and the harness-review skill make `review-result.v1` their output contract.
Calling `/ultrareview` inside them would forfeit the machine-readable guarantee of `review-result.v1`.

**Schema mismatch**: The output of `/ultrareview` is a CC internal format and does not contain the `verdict`, `critical_issues`, `major_issues` fields of `review-result.v1`.
Harness's fix loop, commit guard, and sprint-contract verification all depend on `review-result.v1`, and there is no benefit that justifies the overhead of schema conversion.

**Separation of responsibilities**: `/ultrareview` is an entrypoint the user requests ad-hoc from CC.
Automatic review within the Harness flow is covered by the `reviewer` agent (`review-result.v1`). The two have different uses and coexist without issue.

**Fallback safety**: The `reviewer` agent runs across static / runtime / browser profiles.
Adding `/ultrareview` would increase the fallback paths and make debugging harder.

### 3.2 Usage guide

| Scene | Recommended command |
|--------|------------|
| Comprehensive check before PR merge (outside Harness) | `/ultrareview` |
| Auxiliary second opinion in CI | `claude ultrareview [target] --json` |
| Automatic review after Harness Plan→Work | `/harness-review` (automatic invocation) |
| Security-focused audit | `/harness-review --security` |
| UI quality scoring | `/harness-review --ui-rubric` |

---

## 4. Future work

- Re-evaluate `/ultrareview` once it matures as a CC built-in (next evaluation Phase: 45 or later)
- Calling `/ultrareview` within Harness will only happen after a schema conversion layer to `review-result.v1` is implemented (currently not implemented)
- Any policy change is made simultaneously with a revision of rule 5 in `.claude/rules/opus-4-7-prompt-audit.md`

---

*Decision: Phase 44.8.1 / 2026-04-18*
