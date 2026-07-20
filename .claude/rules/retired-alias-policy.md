# Retired Alias Policy

The SSOT for operating Harness's **exclusion-based verification (residue check for deleted aliases)**.
Reintroduced in Phase 97 as `templates/registry/retired-aliases.v1.yaml` + `bin/harness retired-alias scan`.

## Why This Rule Is Needed

After a major migration, inclusion-based verification of "does the new feature work" alone
easily misses **accidental residue** of deleted paths, old concepts, and retired command names.
From the lesson of the 13 v3 residues accidentally discovered right after v4.0.0 Hokage,
a gate that verifies "whether deleted things remain" in the reverse direction is needed.

## The 5 Rules

### Rule 1: Update the registry at the same time as retirement

Perform "the PR that deletes/renames/retires X" and "adding the entry to `retired-aliases.v1.yaml`"
in the **same PR**. Do not merge only the deletion first and defer the registry update.

### Rule 2: Entries must conform to the schema + reason required

Following `templates/schemas/retired-alias.v1.json`, `id` / `kind` / `pattern` are required.
Write "why it was retired" in `reason`. Keep the allowlist at minimal granularity with prefix match.

### Rule 3: The allowlist follows 3 principles

- **Historical description**: `CHANGELOG.md` and `.claude/memory/archive/` are always allowlist targets
- **Migration guide**: old→new comparison documents such as `docs/MIGRATION-*.md`
- **Individual context**: add by prefix only for intentional mentions in a specific file (a whole directory is prohibited)

### Rule 4: Perform retroactive validation

After adding a new entry, run `harness retired-alias scan` on a past commit
to confirm that the residue is detected as expected. If 0 hits appear,
the allowlist may be too broad or the pattern too weak.

### Rule 5: Zero false positives (HEAD is always 0 hits)

Maintain **0 hits** when scanning the current HEAD.
If there is a hit, resolve it by one of: (1) fixing the true residue, (2) adding to the allowlist if it is a legitimate historical description,
(3) fixing the entry if the pattern is wrong.

## Operating exclusion-based verification

| Operation | Command / gate |
|------|-------------------|
| Local check | `bin/harness retired-alias scan` |
| CI | `scripts/ci/check-consistency.sh` retired-alias section |
| Source-of-truth registry | `templates/registry/retired-aliases.v1.yaml` |
| schema | `templates/schemas/retired-alias.v1.json` |

The scanner walks the repo with fixed strings (equivalent to grep -F)
and excludes by prefix using each entry's allowlist (+ the global allowlist).
Even a single hit results in exit 1.

## Update Procedure

1. Identify the retirement target and choose its `kind` (`path` / `concept` / `command` / `skill`)
2. Add an entry to `templates/registry/retired-aliases.v1.yaml`
3. Verify schema / HeadZeroHits with `cd go && go test ./internal/retiredalias/...`
4. Confirm that `bin/harness retired-alias scan` returns 0 hits
5. Append Before/After (deletion reason + replacement) to CHANGELOG `[Unreleased]` in the PR

This is the current version that reintroduced, at minimal scope into the Go selfaudit layer, the philosophy of the
old `deleted-concepts.yaml` + `check-residue.sh` (removed in Phase 40 and Phase 91.7).
