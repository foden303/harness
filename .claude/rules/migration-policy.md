# Migration Residue Policy

The policy for operating Harness's **exclusion-based verification (checking for residue of deleted concepts)**.
It defines the operational rules for `deleted-concepts.yaml` + `check-residue.sh`,
introduced in Phase 40 (v4.1.0).

## Why this rule is needed

Right after the v4.0.0 "Hokage" release, the full migration from TypeScript to Go was supposed to be "complete."
And yet, within 2 days of the release, 13 "relics of the old era" were found one after another.
File paths that should have vanished lurking inside test scripts, old version names remaining in docs,
a README stating that Node.js is required — none of these could be found through individual reviews or
"does it contain X" style checks.

To confirm "after a big migration, whether anything old truly remains,"
you need the reverse-direction check of "whether anything deleted still remains" (exclusion-based verification).
Follow this rule and the same failure will not recur in future major migrations.

## The 5 rules

### Rule 1: Always update deleted-concepts.yaml at a major version migration

Submit "the PR that deletes X" and "the PR that adds X to deleted-concepts.yaml" at the same time.
Delay is forbidden.

**Why**: If you delete first and postpone the yaml update, in the meantime another PR can introduce a
reference to X, which gets merged unnoticed. Bundling the yaml update into the deletion PR makes
"deletion = becoming a scan target" an indivisible single transaction.

### Rule 2: The update timing is "simultaneous with the deletion PR"

A stronger form of Rule 1. Example: if you submit a PR that deletes the TypeScript guardrail engine,
add `"TypeScript guardrail engine"` to `deleted_concepts` in the same PR.

"Deleted it" and "made it a scan target" must always complete as a set. Either one alone is only half done.

### Rule 3: Operate the allowlist under 3 principles

The `allowlist` field of deleted-concepts.yaml may include the following:

- **Historical records**: CHANGELOG.md and `.claude/memory/archive/` are always allowlisted.
  Recording "such a thing existed in the past" is a legitimate mention, not residue.
- **Migration guides**: documents that describe old → new comparisons, such as `docs/MIGRATION-*.md`.
  Listing old names within a comparison table is intentional writing.
- **Individual context**: when a mention of an old concept in a specific document is **intentionally legitimate**.
  Example: `.claude/memory/archive/Plans-pre-1.0.md` is a frozen record of the pre-1.0 task
  ledger, so it naturally contains the names of removed hosts and features.

The allowlist is applied by prefix match. Keep the **granularity of each entry minimal**.
Allowlisting all of `CHANGELOG.md` is legitimate, but
allowlisting the entire `docs/` directory is excessive and renders the scanner meaningless.

### Rule 4: Always perform retroactive validation (retroactive checking against past commits)

After adding a new deleted-concepts.yaml entry, **go back to past commits, run the
scanner, and confirm that residue is detected as expected**:

```bash
git checkout <past-commit>
bash scripts/check-residue.sh
# → detects the expected count (must be 0 or more)
git checkout -
```

This verifies "whether the yaml can really detect the problem."
If it is not detected, the allowlist may be written too broadly, or the pattern may be wrong.
The goal is to catch, early, a false allowlist that happens to pass.

### Rule 5: Keep false positives at zero (current HEAD is always 0)

When you run the scanner at the current HEAD, the **detection count must always be 0**.
If something is detected, handle it in one of the following ways:

1. If it is **true residue**, fix it immediately (edit the file and remove the old reference)
2. If it **should be allowlisted as a historical record, etc.**, update the yaml
3. If it is **misclassified** (the yaml pattern matched unintentionally), remove it from the yaml

Both CI (validate-plugin.sh section 9) and the release preflight (harness-release Phase 0)
check this automatically, so **0 is guaranteed before merge**.

## Appendix: the 13 v3 residue cases from this session (v4.0.0 → v4.0.1)

The cases that motivated Phase 40. **The story of why this feature was born.**

### How they were discovered

The v4.0.0 "Hokage" release (2026-04-09) was a full migration from the TypeScript implementation to the
Go native implementation. The migration itself was completed, but **references from the TypeScript era
remained as residue scattered across test scripts, docs, and SKILL.md**.
These were discovered by chance through the following routes:

1. Test runs failed → validate-plugin.sh / check-consistency.sh fell over
2. The user noticed via the slash palette → "Harness v3" in SKILL.md frontmatter
3. Found in code review → v3 narrative in agents/*.md
4. Found in doc review → mention of core/ engine in README.md

The problem is that they were "found by chance." Without a mechanism, the same thing will happen at the next release.

### Classification of the 13 cases

| Category | Count | Representative example |
|---------|------|--------|
| Deleted path references | 2 | `core/src/guardrails/rules.ts` |
| Deleted concept terms | 3 | "TypeScript guardrail engine" |
| SKILL.md version suffix | 2 | `# Harness Work (v3)` |
| Old runtime requirements | 1 | "Node.js 18+ is installed" |
| History tables | 1 | `core/` in the README file tree |
| Other (individual formatting bugs) | 4 | README duplicate lines, Japanese/English drift |

### Lessons learned

All 13 of these were undetectable by **inclusion-based verification** (a "does it contain X" check).
This is because the check "X does not remain" cannot be performed
without first knowing "X was deleted."

The perspective of **exclusion-based verification** (the reverse-direction check "does the deleted X still remain")
is required. Phase 40 was born to embed that perspective into Harness's verification layer.

## Related files

- `.claude/rules/deleted-concepts.yaml` — SSOT catalog of deleted paths/concepts
- `scripts/check-residue.sh` — scanner implementation (keep false positives immediately at 0)
- `go/cmd/harness/doctor.go` — `bin/harness doctor --residue` flag
- `tests/validate-plugin.sh` — Section 9: Migration residue check (CI gate)
- `skills/harness-release/SKILL.md` — Phase 0 preflight step 2 (release gate)
