# Branch Alignment Ledger

This ledger tracks safety commits from main that must be ported or explicitly waived before redesign/mainline alignment proceeds. Status values are intentionally closed: `ported` or `waived` only.

| Commit | Area | Status | Why |
|--------|------|--------|-----|
| `1873c8a3` | R15 secret-file staging block | ported | Translated into `go/internal/policy` in Phase 104.1. |
| `6ac3eec0` | R15 git `-C` / subshell bypass | ported | Covered by Phase 104.1 bypass tests. |
| `4d7b6245` | R15 quote-aware lexing | ported | Covered by Phase 104.1 parser/policy port. |
| `3b8e64db` | R15 backslash escape | ported | Covered by Phase 104.1 bypass tests. |
| `5249ad76` | PR #218 safety contract | waived | Product contract already represented on this branch; no additional source delta required for S1. |
| `5a2d0df9` | PR #218 follow-up | waived | Same boundary as `5249ad76`; tracked to avoid silent omission. |
| `d4b8573c` | PR #219 safety contract | waived | Not required for the Phase 104 P0 gate after current source audit. |
| `d9b3fd34` | Egress owner-scope | waived | Owner-scope policy is outside Phase 104 gate implementation; keep as explicit branch-alignment item. |
| `2141c7ef` | setup-hook guard | waived | Setup hook guard does not block S1 gate completion on this branch. |
| `8097802e` | setup-hook guard follow-up | waived | Same boundary as `2141c7ef`; tracked as a paired main commit. |
| `fa88d4cf` | autonomous-confirmation scope | ported | Ported `.claude/rules/autonomous-confirmation-scope.md` (52 lines) to redesign in Phase 104.5. |

## 2026-07-07 Full Inventory (Phase 109.1 — release alignment)

Scope: `git log --no-merges 794bfc36..main` = **86 commits** (the 116 noted in Plans.md includes 30 merge commits). The S1-era waives above were judged "not needed for the Phase 104 P0 gate"; release alignment reclassifies them (the table below takes precedence).

| Group | Commits | Class | Basis | Rep SHA |
|---|---|---|---|---|
| 2026-07-07 guard hardening | 4 | **port (reimplement)** | The redesign guard has no bookkeeping exemption, and the hooks.json wrapper still has a CLAUDE_PROJECT_DIR/$PWD hole. Cherry-pick not possible; reimplement per feature | ed6b18c9 |
| bookkeeping exemption base + 2 rounds | 3 | **port (decision 2026-07-07)** | Without the exemption, harness-release's multi-commit flow (109.5) is blocked in the same way as #219. Port together with the hardening | d4b8573c |
| runtimefloor egress owner-scope | 1 | **port** | The redesign lacks the HARNESS_RUNTIME_FLOOR_EGRESS=off exemption. Additive (no conflict with the secret-read side) | d9b3fd34 |
| SubagentStop reviewer-persist backstop | 1 | **port (Go reimplementation)** | The redesign's runSubagentStop only handles lifecycle and does not write review-result.json | 5249ad76 |
| dependency/security bumps | 5 | **port (verify each)** | Low risk. Only verify version drift under benchmarks/.github | 4f962eb3 |
| known-limitations doc | 1 | **port** | No equivalent doc in the redesign; standalone | 08fa2331 |
| autonomous-confirmation-scope / runtimefloor 5-cat base / R15 hardening / review-result part-1 | 7 | already-included | Byte-identical, or already superseded by an implementation in Phase 104.1/108.x | 1873c8a3 |
| skill refactor chain / mirror sync / release bookkeeping / Phase 94 bookkeeping / #200 trims / hooks doc-drift / P35 footer / 15 cross-session relay commits | 43 | waive | Structurally replaced on the redesign side (channelswake/livemsg/sublead, etc.) or main-specific bookkeeping | b1141223 |
| Phase 95 release delegation | 9 | conflict-review → verify in 109.1b | The redesign harness-release's references/ not yet checked | f499f577 |
| Windows harness-mem companion | 2 | conflict-review → 109.1b | No Windows branch in the redesign companion.go. Need to confirm whether it has been made Go-native | c8706db8 |
| setup-hook harness.toml bootstrap | 3 | conflict-review → 109.1b | Need to confirm whether it's required for fresh install | 8097802e |
| real fixes within release-chore / bc96f759 / small docs / HOTL wip | 7 | conflict-review → 109.1b | Verify each individually and settle port/waive | 7dd175c5 |

**Totals**: port 15 / already-included 7 / waive 43 / conflict-review (settled in 109.1b) 21 = 86, unclassified 0.

## 2026-07-07 DP-2 / DP-4 Rulings Applied (Phase 109.2, operator-approved)

- **DP-2 (cut list)**: bridge/mailbox/bridgedelivery/triaddispatcher = already deleted in Phase 104.4 (importer 0). impactscore = unified in Go (importer: go/cmd/harness/impact_score.go). Ambiguous skills gogcli-ops/cc-cursor-cc = deleted + registered in retired-aliases.v1.yaml. agent-browser/cc-update-review = retained per the retention ruling. → No additional work; the rulings are already reflected in the implementation.
- **DP-4 (auto-approve claim retracted)**: The README already says "ledger only, prompts not skipped." Added the retraction text to the previously empty auto-approve scope section of the sub-spec docs/spec/operations-memory-and-collaboration.md (984456bf). → The retraction path for GOD_plans §7-6 is green.

## 2026-07-07 Settling the 21 conflict-review Items (Phase 109.1b)

Review result: port 7 groups / waive 3 groups. The 21 raw commits were grouped by representative SHA, so they are resolved individually below.

| Commit group | Ruling | Basis | Files to port |
|---|---|---|---|
| Phase 95 release delegation (9, f499f577) | waive | The redesign already has no gh release create call, plus release.yml and test-release-skill-no-gh-release.sh exist. Redundant | — |
| Windows harness-mem companion (0e3d5ab6, c8706db8) | **port** | Zero Windows branches in the redesign companion.go. On Windows, "%1 is not a valid Win32 application" (#207) | go/internal/harnessmem/companion.go (manual re-port) |
| setup-hook harness.toml bootstrap (8097802e) | **port** | runSetupInit does not generate harness.toml. harness sync fails on fresh install (#201) | setup_hook.go + scaffold extraction |
| 7dd175c5 plugin runtime cache | **port (partial)** | The direct-script hook wrapper lacks a file-existence guard, and codex-companion.sh has MODEL_ARGS unbound (4 sites). The version-bump hunk is waived | hooks.json ×2 / sync-plugin-cache.sh / build-host-plugin-dist.sh / codex-companion.sh |
| 631ed798 CI gate | **port (test fix)** | runtimefloor_test.go's t.TempDir() conflicts with the /tmp allowlist and falsely fails on Linux CI. The CHANGELOG hunk is waived | Only pinning the home path in runtimefloor_test.go |
| 5d537b7c codex AGENTS.md | **port** | codex/AGENTS.md has stale "Hooks not supported" in 3 places (contradicts reality, inconsistent with the MEMORY North Star note) | codex/AGENTS.md 3 lines |
| 08fa2331 reviewer + known-limitations | **port** | known-limitations.md missing + reviewer.md lacks the neutral-enumeration instruction | agents/reviewer.md + docs/known-limitations.md |
| a6f58e20 i18n.md SSOT | **port** | docs/i18n.md missing + no pointer | docs/i18n.md + CLAUDE.md/README pointer |
| 451b4a68 cursor tier | waive (moot) | The redesign's cursor tier is still a candidate. The PR #174 promotion is not merged into the redesign lineage. There is nothing to fix | — |
| f6cdb042 HOTL wip | waive (moot) | plan-brief/accept are independently wired in the redesign (superseded). The progress-tracker hook is dead code because its dependent script is missing. Self-labeled wip | — |

**Settled**: conflict-review 21 → equivalent to port 12 commits (8 rep SHA) / waive 9 commits. → Classification of all 86 commits complete (port 27 / already-included 7 / waive 52, unclassified 0).

## 2026-07-08 Mainlining Merge Strategy (Phase 109.4, operator-approved Strategy 1)

Use `git merge -s ours origin/main` to take main in as an ancestor while adopting the redesign tree. Rationale: the 27 port commits were manually ported in 109.1a/109.1b, and the 52 waives are not taken in because they conflict with subsystems the redesign intentionally replaced or removed. After the merge, `git rev-list HEAD..origin/main` = 0 (0 PR conflicts).

**main-side deltas dropped by -s ours and how they're handled**:
- `go/go.mod` / `go.sum`: main's indirect→direct promotion + jsonschema/yaml additions. The redesign has its own dependency tree with go test green across 44 packages, so there is no functional gap. Not a security bump.
- `benchmarks/breezing-bench/*/package-lock.json`: Node dependencies for benchmarks. Outside the production distribution payload.
- **Dependabot 21 vulnerabilities (M6)**: Specific to the main default branch. A human-only item to re-evaluate separately after the redesign is mainlined. Not addressed in this merge.
