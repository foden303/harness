# Hokage Core Cross-Harness Architecture

Last updated: 2026-05-22

## Purpose

Hokage Core is the shared workflow contract behind Claude Code Harness.

The product stays Claude-first until adapter parity is proven. The internal
near-term positioning is:

```text
Claude Code Harness, powered by Hokage Core
```

This is an implementation direction, not a public marketing claim. The
repository already uses "Hokage" for the v4 Go-native runtime line, so public
README wording must stay conservative until the spin-off gate passes.

## Why This Exists

Superpowers shows the useful pattern: the reusable part is not a single CLI.
It is a common skills library plus thin harness-specific entrypoints. Its
repository exposes separate per-host surfaces while pointing host adapters at
one common skills library. Harness ships a single host today; the value of the
split is that adding a second one later does not mean forking the skills.

Claude Code Harness already has part of that shape:

- `skills/` is the current primary skill surface.

The missing piece is a stable boundary that says what is core, what is adapter,
and what must be proven before public cross-harness claims.

## Core Contract

Core is allowed to define:

- workflow intent
- user-facing triggers
- inputs and outputs
- required evidence
- acceptance criteria
- review and completion rules
- tool capability requirements

Core must not depend directly on:

- Claude Code hook names such as `PreToolUse`, `PostToolUse`, or `SessionStart`
- Claude-only tools such as `Task` or `AskUserQuestion`
- plugin marketplace packaging details

If a core workflow needs a capability, it names the capability in generic terms.
Examples:

| Capability | Meaning |
|---|---|
| `skill_loading` | Host can discover and load workflow skills |
| `bootstrap_notice` | Host can inject startup guidance or prove it was loaded |
| `prompt_routing` | Host can route natural language prompts to workflows |
| `pre_use_guard` | Host can block dangerous actions before execution |
| `post_use_gate` | Host can inspect output after execution |
| `review_artifact` | Host can emit structured review evidence |
| `memory_bridge` | Host can read or write session memory through a safe adapter |

## Adapter Contract

Adapters translate the core contract into host-specific mechanics.

| Adapter | Phase 73 tier | Owns | Must not claim |
|---|---|---|---|
| Claude Code | `supported` | plugin manifest, hooks, settings, output styles, runtime guardrails | That non-Claude hosts have identical pre-use hooks |

Each adapter must declare:

- support tier
- supported core skills
- unsupported core skills with reasons
- capability mapping
- bootstrap route
- install/update path
- verification commands
- known asymmetries

## Implementation Flow

The no-regression flow is intentionally staged:

1. **Plan**
   Define Hokage Core and adapter contracts in docs before changing runtime
   behavior.
2. **Pre-implementation validation**
   Add failing tests for the capability matrix and bootstrap routing. Treat
   adapter manifests as a follow-up only after a consumer exists in setup,
   docs generation, or release preflight.
3. **Implementation**
   Add adapter manifests and generator checks only when they are consumed by
   setup, docs generation, or release preflight in the same phase.
4. **Post-implementation validation**
   Run targeted contract tests, mirror checks, release preflight, and the
   full plugin validator. Non-shipping adapter
   checks should be path-triggered or opt-in unless the release claims that
   adapter support.
5. **Positioning closeout**
   Update README only to the level proven by tests. Public `Hokage Harness`
   spin-off remains blocked until the gate below passes.

## Public Spin-Off Gate

`Hokage Harness` can become a public generic distribution only when all of the
following are true:

| Gate | Required proof |
|---|---|
| Claude adapter | `./tests/validate-plugin.sh` passes with Hokage Core contract checks |
| Future adapters | A host stays unclaimed until host-specific smoke proves bootstrap and workflow behavior |
| Capability matrix | Host tiers are documented and tested |
| Bootstrap routing | Golden prompts route to the expected workflows or produce an explicit unsupported result |
| Release preflight | `bash scripts/release-preflight.sh` includes adapter drift gates |
| Positioning | README avoids claiming support for unproven hosts |

Until then, use the wording:

```text
Claude Code Harness is Claude-first, with Hokage Core extraction underway.
```

## Explicit Rejects

- Do not rename the main product to `Hokage Harness` before adapter parity.
- Do not copy Superpowers skill names or trigger phrases as a shortcut.
- Do not call `skills/` tool-neutral while it still contains host-specific
  assumptions.
- Do not promise the same safety model across hosts with different hook models.
- Do not describe any host other than Claude Code as supported. There is no
  second tier to promote from: the pre-1.0 `candidate` /
  `future/unsupported` entries were removed with their evidence.
- Do not add adapter manifest files unless setup, docs generation, or release
  preflight consumes them in the same phase.
- Do not make Claude plugin releases hard-block on non-shipping adapter checks
  unless that release claims adapter support.

## Source Links

- Superpowers repository: https://github.com/obra/superpowers
- Superpowers OpenCode plugin: https://github.com/obra/superpowers/blob/main/.opencode/plugins/superpowers.js
- Local distribution scope: `docs/distribution-scope.md`
- Local skill orchestration contract: `docs/skill-orchestration-design-contract.md`
