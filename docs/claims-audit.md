# Claims Audit

Last updated: 2026-07-21

This document is an audit note that classifies public-facing claims by "proven now" versus "needs additional evidence".
Review this table first when updating the README or release copy.

## Current Classification

| Claim | Status | Current evidence | Before stronger wording |
|------|--------|------------------|-------------------------|
| Harness is built around **5 verb skills** | Proven now | `skills/`, `README`, `validate-plugin.sh` | None |
| Harness uses a **Go-native guardrail engine** | Proven now | `go/`, `bin/harness`, `go test ./...`, `hooks/hooks.json` | None |
| Guardrail rules are **enforced at runtime**, not just documented | Proven now | `hooks/hooks.json` PreToolUse/PostToolUse wiring into `bin/harness`, R01-R13 rule tests under `go/` | None |
| README / docs / Plans no longer contradict each other on version and missing links | Proven now | `README*`, `docs/CLAUDE_CODE_COMPATIBILITY.md`, `check-consistency.sh` | Continue updating them together on future doc changes |
| Every top-level path is classified as distribution-included or development-only, with clear boundaries | Proven now | `docs/distribution-scope.md`, `.gitattributes`, `tests/test-distribution-archive.sh` | Update the scope table in the same PR whenever a top-level path is added or removed |
| `/harness-work all` has a rerunnable success/failure contract | Proven now | `docs/evidence/work-all.md`, fixture smoke, failure contract, success replay-fallback artifact | A strict-live success artifact would let us add live proof too |
| `/harness-work all` can be trusted as a default production path | Not yet safe to claim strongly | README now avoids this wording | Add stable reproduction of a successful full run, plus CI or a captured artifact if needed |
| README includes a dated feature matrix against popular GitHub harness plugins | Proven as dated snapshot | `docs/github-harness-plugin-benchmark.md`, linked GitHub repos, README / README_ja comparison table | Update stars and comparison targets before release |

## Notes

- The 2026-03-06 success full runner was fixed to automatically fall back to a replay overlay when it detects the Claude Code usage limit (`You've hit your limit · resets 12pm (Asia/Tokyo)`).
- As a result, artifact generation itself is not blocked by quota. However, **evidence of a run that completed on a live Claude run alone** still requires a separate `--strict-live` success artifact.
- The failure path is structured so that the "do not commit while red" contract is easy to verify.
