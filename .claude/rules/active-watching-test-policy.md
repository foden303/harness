# Active Watching Test Policy

The testing convention to follow when adding a new **feature that actively watches an external process / file / daemon**, such as the Session Monitor.
It codifies D40 (tri-state health) and P29 (dual hooks sync) into operational rules, serving as the SSOT for stamping out regressions like the v4.3.3
"false warning to users who haven't installed" case in the early phase.

## Why this rule is needed

Right after v4.3.1 added `harness-mem` active watching to the Session Monitor,
a v4.3.3 hotfix had to fix a regression where `⚠️ harness-mem unhealthy: not-initialized`
was shown every session to "users for whom `~/.claude-mem/` is absent = users who have not opted in to harness-mem".

The root cause was doing only inclusion-based testing and not writing tests for the state where **the dependency does not exist**.
Active watching often depends on opt-in external resources, so **covering all three states — not installed / not running / corrupted — from the start**
is the only way to prevent recurrence.

## Scope

Follow this convention when newly adding code that falls under any of the following.

- Adding a new health check to `go/internal/session/monitor.go`
- Probing an external daemon / HTTP endpoint from `scripts/hook-handlers/` etc.
- Reading an optional directory under `~/.claude-*/` or `$HOME/`
- Monitoring the startup state of an MCP server
- Checking the availability of an external daemon / CLI on each session
- Putting the availability of an external resource into additionalContext in a `UserPromptSubmit` or `SessionStart` hook

Conversely, the following are out of scope:

- Sanity checks of required dependencies (the Go standard library, `bin/harness` itself)
- Tests that run only in CI (in CI the dependency is always present, which is fine)

## Definition of the three states

The states an active-watching target dependency can take, and the required behavior for each:

| State | Identifier (reason) | `healthy` | Exit | Monitor warning | Typical example |
|------|----------------|-----------|------|------------|--------|
| Not installed / opt-in not used | `not-configured` | **true** | 0 | **Do not show** | `~/.claude-mem/` absent |
| Not started / unreachable | `daemon-unreachable`, `timeout`, `unreachable` | false | 1 | Show | TCP connect failure |
| Config corrupted / file missing | `corrupted`, `invalid-config` | false | 1 | Show | settings.json absent |
| Normal | `""` | true | 0 | Do not show | All components OK |

Key principles:

- **"Not being used" is not "broken".** Do not show a warning in a state where an opt-in feature is merely unused
- Concentrate the decision logic **in the health check subcommand** so that Monitor and other callers behave consistently (D40)
- The Monitor implementation must always treat `healthy=true + reason="not-configured"` as a warning-suppression contract

## Test naming convention

Write at least one test for each of the three states. Fix the naming as follows.

| State | Test function name pattern | What it verifies |
|------|-------------------|---------|
| `not-configured` | `TestXxx_NotConfigured` | `exit=0`, `healthy=true`, `reason="not-configured"`, Monitor does not show a warning |
| `unreachable` | `TestXxx_DaemonUnreachable` or `TestXxx_Unreachable` | `exit=1`, `healthy=false`, a specific reason string, Monitor shows a warning |
| `corrupted` | `TestXxx_Corrupted` | `exit=1`, `healthy=false`, `reason="corrupted"`, Monitor shows a warning |
| Normal | `TestXxx_Healthy` | `exit=0`, `healthy=true`, `reason=""`, Monitor passes silently |

Prepare Monitor-side integration tests with the same naming convention (e.g. `TestMonitorHandler_XxxNotConfigured`).

## Checklist

Verify when including an active-watching feature in a PR:

- [ ] Wrote 4 tests on the health check side (normal + 3 abnormal)
- [ ] Wrote a Monitor-side integration test asserting that no warning is shown for `not-configured`
- [ ] Enumerated the `reason` strings as an enum (not free-text; make it explicit in a table in the documentation)
- [ ] The Monitor side references the `healthy=true + reason="not-configured"` contract
- [ ] The naming convention does not collide with existing dependencies (`harness-mem`, etc.)
- [ ] Documented the three states in the docs (`go/SPEC.md`, etc.)

## Case appendix: v4.3.3 harness-mem hotfix

The direct trigger case that led to this convention. Reference it to mimic the test structure.

- **Background commit**: [`23589344`](https://github.com/foden303/harness/commit/23589344) (PR #98 / v4.3.3 hotfix)
- **Health check implementation**: `runMemHealthCheck()` in `go/cmd/harness/mem.go` — returns `not-configured` via two early returns (`UserHomeDir` failure / `~/.claude-mem/` absent)
- **Health check tests**: `go/cmd/harness/mem_test.go`
  - `TestRunMemHealth_Healthy`
  - `TestRunMemHealth_DaemonUnreachable`
  - `TestRunMemHealth_NotConfigured` ← the core of the 3-state coverage
  - `TestRunMemHealth_Corrupted`
- **Monitor integration tests**: `go/internal/session/monitor_test.go`
  - `TestMonitorHandler_HarnessMemHealthy`
  - `TestMonitorHandler_HarnessMemUnhealthy` (fixture reason = `daemon-unreachable`)
  - `TestMonitorHandler_HarnessMemNotConfigured` ← explicitly asserts no warning output

What this case confirmed is that **if even one of the three states is missing, a regression appears**.
Had the `not-configured` test been written from the start, the problem could have been caught at v4.3.1.

## Related rules

- [D40](../memory/decisions.md) — the design decision for tri-state health (the theoretical basis of this convention)
- [P29](../memory/patterns.md) — dual hooks.json sync + CI gate (recurrence prevention on the wiring side)
- [migration-policy.md](./migration-policy.md) — the sibling convention for exclusion-based verification (deletion residue vs. dependency absence)
- [test-quality.md](./test-quality.md) — test quality in general (prohibiting hollow tests)
- [implementation-quality.md](./implementation-quality.md) — implementation quality in general
