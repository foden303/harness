# Positioning Notes

Last updated: 2026-07-21

To put it briefly for public messaging, the value of `harness` is not "adding more skill packs" but **being able to run Plan -> Work -> Review with runtime enforcement and verification**.

## Core Message

- Harness treats `5 verb skills + Go-native guardrail engine` as the core product
- The guardrail engine is a single Go binary (`bin/harness`, built from `go/`) wired into Claude Code's native hook events, so the rules (R01-R13) are adjudicated at runtime rather than merely documented
- The value is not the sheer number of commands, but that `guardrail`, `review`, `consistency`, and `evidence` work together as one
- The distribution boundary is documented rather than implied: `docs/distribution-scope.md` classifies every top-level path as distribution-included or development-only

## Public Comparison Language

- Avoid: "overwhelmingly better than competitors," "total victory"
- Use: "strong runtime enforcement," "clear verification path," "ties claims to reproducible evidence"
- In competitor comparisons, do not deny their philosophy or adoption record; explain Harness's strengths in terms of guardrail / evidence / operator clarity

## Recommended One-liner

> A harness that not only extends Claude Code with skill packs but also lets you operate Plan -> Work -> Review with guardrails and verification.

## Proof Points

- Go-native guardrail engine (`go/`, shipped as `bin/harness`)
- 5 verb skills (`skills/`)
- consistency check (`scripts/ci/check-consistency.sh`) and plugin validation (`tests/validate-plugin.sh`)
- `/harness-work all` evidence pack
