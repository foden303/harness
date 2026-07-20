# Hokage Spin-Off Readiness

Last updated: 2026-05-22

## Conclusion

No public spin-off yet.

Claude Code Harness remains a Claude-first product. "Hokage" is currently the
v4 Go-native runtime line, and Hokage Core extraction is underway as an internal
architecture direction. Do not present `Hokage Harness` as a public cross-host
product until the gates below pass.

## Gate Scope

The Phase 73 support claim freeze covers these hosts:

| Host | Current tier | Public claim boundary |
|---|---|---|
| Claude Code | `supported` | Claude-first product support is allowed. |

`not_observed != absent`: unavailable local runtime smoke stays unknown or not
observed. It must not be promoted into support, and it must not be treated as
proof that no route can exist.

## Gate Status

| Adapter readiness | Result | Evidence | Public boundary |
|---|---|---|---|
| Claude Code adapter | PARTIAL | Claude-first plugin baseline remains the product surface | Does not prove cross-host spin-off readiness |

| Gate | Current result | Verification evidence | Remaining blocker |
|---|---|---|---|
| Claude Code support | SUPPORTED | Claude-first plugin baseline and existing validation path are the product surface | Do not imply this proves other hosts |
| Capability matrix | PASS | `docs/tool-capability-matrix.md` and `bash tests/test-tool-capability-matrix.sh` cover Phase 73 tiers and false parity | None for the 73.1.2 contract freeze |
| Bootstrap routing | PASS | `docs/bootstrap-routing-contract.md` and `bash tests/test-bootstrap-routing-contract.sh` define static golden prompt routing and unsupported-host behavior | Runtime auto-routing proof is explicitly out of scope for this phase |
| Release preflight | PASS | `bash scripts/release-preflight.sh` includes adapter gates when adapter paths changed, release claims adapter support, or `--check-adapters` is used | CI run evidence still requires pushing the branch before a release tag |
| Positioning | PASS | README / README_ja use conservative extraction wording | Keep this wording until the other gates pass |

## Last Verification Snapshot

Historical local verification retained as context. It covers the Claude Code
path only, which is the only host Harness claims.

| Command | Result |
|---|---|
| `./tests/validate-plugin.sh` | PASS |
| `bash scripts/sync-skill-mirrors.sh --check` | PASS |
| `bash tests/test-tool-capability-matrix.sh` | PASS |
| `bash tests/test-bootstrap-routing-contract.sh` | PASS |
| `bash scripts/release-preflight.sh` | PASS locally with non-blocking warnings for env/health/CI availability and existing residual-scan candidates |

## Candidate And Unsupported Host Reasons

| Host | Status | Reason |
|---|---|---|

## Next Adapter Candidates

None. The two candidates tracked before v1.0.0 (GitHub Copilot CLI, Antigravity
CLI) were dropped together with the research documents that justified them.
Adding a host means producing, for that host: local CLI availability, Harness
bootstrap and skill smoke, and release-preflight integration — the same
evidence bar the Claude path had to clear.

## Allowed Public Wording

Use:

```text
Claude Code Harness is Claude-first, with Hokage Core extraction underway.
```

Do not use:

```text
Describe Hokage as a public cross-host product before these gates pass.
```

## Exit Criteria

The `No public spin-off yet` conclusion can change only when all of the
following are true:

- Claude Code remains supported and every public non-Claude support claim has
  host-specific install/update, bootstrap, workflow smoke, and release gate
  evidence.
- Capability differences are documented and test-backed.
- Bootstrap routing has golden prompt coverage or explicit unsupported results.
- Release preflight blocks only adapters claimed by that release.
- README / README_ja can state support without implying safety parity that the
  host cannot provide.
