# Distribution Scope

Last updated: 2026-05-14

This document is a scope table that spells out, for `harness`, "things that exist in the repo but are not included in the Claude Code plugin distribution payload."
When in doubt about `Plans.md`, the README, `.gitattributes`, distribution scripts, or validation scripts, treat this table as the canonical source.

## Scope Table

| Path | Status | Why it exists | Enforcement signal |
|------|--------|---------------|--------------------|
| `.claude-plugin/` | Distribution-included | Claude Code plugin manifest / hooks / settings | `claude plugin validate`, `test-distribution-archive.sh` |
| `bin/harness*` | Distribution-included | Go-native guardrail / lifecycle runtime | `validate-plugin`, `go test`, archive required entries |
| `skills/` | Distribution-included | Primary skill surface for Claude Code | `validate-plugin`, mirror sync checks |
| `agents/` | Distribution-included | worker / reviewer / advisor | `validate-plugin`, agent frontmatter tests |
| `hooks/`, `monitors/` | Distribution-included | Runtime hook / monitor definitions | `hooks/hooks.json`, `validate-plugin` |
| `output-styles/` | Distribution-included | Claude Code output style | `plugin.json`, archive required entries |
| `templates/` | Distribution-included | project init / rules / templates | `check-consistency.sh`, template registry checks |
| `scripts/` runtime files | Distribution-included | hook handlers, setup, sync, review, plan, loop runtime | `validate-plugin`, runtime hook tests |
| `assets/`, public `docs/` | Distribution-included | README assets and public user documentation | README claim drift checks |
| `go/`, `tests/`, `.github/` | Development-only and distribution-excluded | source / CI / validation | `.gitattributes`, `test-distribution-archive.sh` |
| `.claude/`, `CLAUDE.md`, `AGENTS.md`, `Plans.md` | Development-only and distribution-excluded | repo-local agent context, local plans, editor setup | `.gitattributes`, `test-distribution-archive.sh` |
| `.private/` | Local-only and distribution-excluded | Holding area for private/dev-only skills that would appear in the `claude --plugin-dir .` inventory if placed directly under `skills/` | `.gitignore`, `test-public-plugin-inventory.sh` |
| `scripts/ci/`, `scripts/evidence/`, `scripts/sandbox-test/` | Development-only and distribution-excluded | CI helpers, evidence fixtures, local sandbox examples | `.gitattributes`, `test-distribution-archive.sh` |
| `docs/research/`, `docs/private/`, `docs/notebooklm/`, `docs/slides/`, `docs/presentation/`, `docs/social/` | Private or generated reference | Research records, pre-publication drafts, generation intermediates | `.gitignore`, `.gitattributes`, `test-distribution-archive.sh` |

## Current Decisions

- This table classifies only directories that actually exist in the tree. A path that has disappeared from the tree gets its row deleted rather than being kept with a "retired" status; retirement is tracked in `templates/registry/retired-aliases.v1.yaml` instead.
- `.claude/` / `CLAUDE.md` / `AGENTS.md` / `Plans.md` are repo-local context, not plugin payload.
- Do not place private/dev-only skills under `skills/`. Even when `.gitignore`d, they are exposed in the local inventory of `claude --plugin-dir .`, so move them outside the public plugin surface, e.g., to `.private/skills/`.
- `scripts/hook-handlers/memory-bridge.sh` and `memory-*.sh` are **Distribution-included** even though they are local bridges. Because hooks reference them, they must be tracked in the repo.
- When writing "deleted" in the README or `Plans.md`, use it only when something has actually disappeared from the tree.
- Use "distribution-excluded," "compatibility-retained," and "development-only" in line with the labels in this document.

## Update Rule

Update this table in the same PR / commit whenever any of the following happens.

1. When you change the architecture / install / compatibility descriptions in the README
2. When you change the exclusion rules in `.gitignore` or build scripts
3. When a top-level directory is added to or removed from the tree (add its row, or delete the row of a path that no longer exists)
4. When you change the `export-ignore` in `.gitattributes` or the required / forbidden list in `tests/test-distribution-archive.sh`
