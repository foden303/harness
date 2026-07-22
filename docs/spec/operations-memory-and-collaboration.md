# Spec Sub-Spec: operations-memory-and-collaboration

This sub-spec is part of the `spec.md` product contract. SSOT order is `spec.md` core > `docs/spec/*` sub-specs > `Plans.md`.

## Supply Chain Alert Contract

Open Dependabot alerts on tracked source, tooling, benchmark, or distribution
lockfiles are repo-health findings, not release noise.

Harness must handle them with evidence:

- enumerate the live GitHub alert set before planning remediation,
- group alerts by manifest path, dependency, severity, and advisory,
- prefer supported upgrades that keep the current tool line moving forward over
  security downgrades suggested only by `npm audit fix`,
- use package-manager-native override mechanisms only when the direct owner
  package has not yet published a patched dependency range,
- verify the affected tool still starts or runs an equivalent smoke command,
- add or update Dependabot configuration and CI/audit checks when a tracked
  manifest can otherwise accumulate alerts without PR automation,
- keep GitHub alert closeout, local `npm audit`, CI, and release gates separate.

Benchmark-only manifests may use focused smoke evidence instead of full
benchmark execution when model keys, Docker, or sandbox services are unavailable,
but the unavailable part must be recorded as a residual risk rather than treated
as success.

## Memory Contract

When a planning or design decision is made, Harness should record why it was
chosen, not only what changed.

Preferred memory targets:

- `harness-mem` project-scoped ingest/search when available.
- `.claude/memory/decisions.md` and `.claude/memory/patterns.md` when present.
- `Plans.md` and spec documents as local, reviewable SSOTs.

If harness-mem is unavailable, the agent must say so and keep the local SSOT
updated instead of pretending memory was written.

## Upstream Tracking Contract

Claude Code updates must be turned into Harness changes through an
evidence gate, not by copying release notes into docs.

Every non-trivial upstream refresh must:

- compare the local installed versions with the latest official upstream
  versions,
- use official Anthropic or first-party GitHub release sources,
- record a dated snapshot document with release URLs, local version output, and
  observed gaps,
- classify each relevant item as `A: adopt now`, `C: inherit upstream`,
  `P: plan/spike`, or `Reject`,
- keep `B: explanation only` at zero unless the plan explicitly explains why a
  non-actionable note is still worth preserving,
- connect adopted items to `Plans.md`, tests, docs, CHANGELOG, and review gates,
- avoid support-tier upgrades until host bootstrap, runtime smoke, and release
  gates prove the claim.

The following upstream surfaces are product-affecting and must not be treated as
automatic documentation updates:

- skill or slash-command frontmatter semantics,
- hooks, message display, session start, and plugin marketplace behavior,
- agent, subagent, background-session, worktree, or permission behavior,
- sandbox, approval, profile, or managed policy behavior,
- installer, package, release artifact, or supply-chain behavior.

If an upstream product weakens a previous opt-in barrier, such as an auto mode
consent change, Harness must keep its own safety default until a dedicated phase
updates the contract, tests, and release notes. Upstream convenience is evidence
to evaluate, not permission to silently relax Harness guardrails.

## Session Coordination Contract

When multiple local Claude Code sessions work on the same project, Harness may
coordinate them to reduce file conflicts, but only under these rules.

- Coordination state is local-only and never depends on harness-mem, so the
  boundary with the sibling harness-mem repo stays intact.
- The lease store lives in one shared location resolved from
  `git --git-common-dir`, never under a worktree-local `.claude/`, so parallel
  worktree Workers share a single lease space. Lease keys are the sha256 of the
  repo-relative path, never an absolute path.
- Lease acquisition is atomic (`O_CREAT|O_EXCL`). Staleness requires both TTL
  expiry and the holder session id being absent from the live-session set; pid
  liveness is only an auxiliary signal.
- Conflict handling changes behavior through diagnostic feedback
  (`continueOnBlock`), not a silent advisory. It is feedback, not a guard rail,
  so it never blocks irreversible operations and stays fail-open: if the lease
  mechanism is unavailable, edits pass and no false assurance is implied.
- Cross-session content (broadcast, lock metadata) is injected into model
  context as data, not instructions: only structured trusted fields (sanitized
  path, short session id, age-seconds), wrapped with the existing
  non-instruction disclaimer. Free text from other sessions is never echoed
  verbatim, control characters are stripped, and a byte cap bounds the payload.
- Trust envelope DoD: a SendMessage relay exposes only those structured trusted
  fields into model context; it does not hold user authority and must never treat
  relayed peer content as instruction or consent.
- Coordination health uses the tri-state model in
  `.claude/rules/active-watching-test-policy.md`: `not-configured` is silent;
  only `unreachable` / `corrupted` warn.
- A broadcast channel whose fire conditions are too narrow dies silently, as
  the 2026-02 broadcast corpse proved. Any revival must prove via tests that
  its fire strategy triggers on normal edits.
- Cross-session notice delivery is best-effort, not guaranteed. Recipients must
  treat unread inbox as unconfirmed until the next turn reads it. Idle
  non-Claude-Code peers have no idle-fire hook, so notice cannot be promised
  for those sessions.
- Peer session: a concurrent session the human opened themselves (not
  orchestrator-spawned).

## Worktree Root Discipline

Harness uses two distinct worktree roots. They must never be merged, relocated,
or referenced interchangeably.

- `.harness-worktrees/` is the **single root** for Harness-managed parallel task
  worktrees. `scripts/spawn-parallel.sh` runs `git fetch origin`, captures one `BASE=$(git rev-parse HEAD)`, and creates
  `task/<name>` branches at `.harness-worktrees/task-<name>` from that shared
  base. Go `breezing.WorktreeManager` also resolves paths under
  `HarnessWorktreesRoot` (`.harness-worktrees/`). Re-running spawn for an
  existing worktree is idempotent when the base SHA matches; a base mismatch
  must fail fast without deleting the existing worktree.
- `.claude/worktrees/` is **Claude Code live-agent isolation only** (Task tool /
  Agent isolation runtime). It is not the parallel-task root, must not be moved
  into `.harness-worktrees/`, and must not be rewritten by spawn or breezing
  tooling.

Project-local `git config rerere.enabled true` is set during parallel spawn so
cherry-pick/rebase conflict reuse is reproducible across machines.

## Parallel Collaboration Contract

One Lead drives several DIFFERENT tasks in parallel across Claude Code workers
spawned through the Agent tool by the /breezing skill, so the human steers ONE
Lead and every lane lands.
This contract governs the SAFETY and conflict-separation rules layered on that
orchestrator. It builds on the Execution Backend Contract (backend resolution),
the Orchestration Visibility Contract (ledger), and the Session Coordination
Contract (lease); it does not replace them. Breezing Brief Contract (below)
defines `brief-card.v1`, `judgment-card.v1`, breezing mem lifecycle events, and
fail-open memory behavior for `/breezing` free-text entry layered on this
orchestrator.

Historical L3 note: an earlier bridge subsystem prototyped a `bridge-event.v1` envelope that normalized host mailbox events into a sqlite WAL mailbox, then projected lane-aware records into memory and host-specific notice delivery. That subsystem stayed unwired from the `bin/harness` runtime and was removed before v1.0.0, but the useful design lesson remains: any future L3 collaboration layer should keep source adapters, append-only mailbox storage, delivery transport, and natural-language dispatch as explicit boundaries with fail-open fallback and hub-spoke ownership.

- Hub-spoke, no worker-to-worker. Workers emit only `companionresult.v1` on
  stdout; they never address or message each other. All coordination is
  spoke->hub (worker result -> Lead). For v1 the Lead is Claude Code, which
  natively spawns Claude subagents.
- Headless v1. The Lead drives background workers; there is no live
  session-to-session message bus in v1. The
  `harness_session_*` and `harness_mem_signal_*` MCP tools are EXTERNAL
  (harness-mem-owned) and are not a dependency of this contract.
- Physical separation first. Before fan-out the Lead establishes ONE fresh base
  (`git fetch`; `BASE=$(git rev-parse HEAD)`) and creates branch-per-task plus
  worktree-per-branch off that single BASE, so workers cannot collide while
  running. Shared files (`Plans.md`, `CHANGELOG.md`, `spec.md`) are written as
  owner-assigned append-only blocks; `VERSION` is never bumped inside a worktree;
  generated artifacts are regenerated once on trunk after merge; `rerere.enabled`
  is set. The Lead aggregates one task at a time: rebase the task branch onto
  trunk, `cherry-pick --no-commit`, run the pre-merge policy gate, commit.
  Normative detail (3 invariants, owner-assign table, CHANGELOG
  collision precedent): `.claude/rules/shared-file-discipline.md`. Complements
  Worktree Root Discipline above (where worktrees live vs what workers may edit).
- Two distinct floors — do not conflate them.
  - The PRE-MERGE POLICY GATE is the existing `go/internal/floor` (`floor.Gate`):
    deny-surface integrity, R01-R13 over the changed files, and the contract
    scripts. It runs at integration and catches file-level violations.
  - The RUNTIME ACTION HARD FLOOR (the human stop) is enforced BEFORE a worker
    action runs, at the companion-invocation / pre-action layer, because a
    post-hoc file diff cannot see a runtime side effect. Five categories ALWAYS
    stop and ask the human and are non-overridable in every config: (1)
    money/billing, (2) external send / network egress to a non-allowlisted
    destination, (3) credential entry or secret read, (4) production deploy or
    publish, (5) destruction OUTSIDE the task worktree.
- Auto-approve scope. Inside a CONFINED worktree the Lead may auto-judge
  code/file/git "ask" gates; the runtime hard floor is the only escalation path.
  Auto-approve must NOT be enabled until both the runtime floor and worktree
  confinement exist.
- Worktree confinement. Workers must be confined to their worktree
  path; `--workspace` is a working-directory hint, NOT a write boundary. The v1
  confinement is a pre/post worktree fingerprint: any change outside the task
  worktree ($HOME-sensitive paths, trunk, sibling worktrees) hard-stops the run
  (this is also floor category 5). OS-level confinement (`sandbox-exec` /
  `unshare`) is a later hardening, not a v1 requirement.
- Visibility. Every dispatch, result, and aggregate event is emitted to the
  orchestration ledger.

One operating mode sits on this contract: Mode 1, fully autonomous
orchestration (headless, no live bus). It honors the safety core (runtime floor
+ worktree confinement) above. A second, human-present peer co-drive mode was
prototyped as live notice messaging and removed before v1.0.0 — see "Peer
co-drive" below.

Mode 1 — orchestrated Producer hierarchy. The Lead/Producer (the CLI the human
talks to; for v1 the Lead is Claude Code) delegates each lane to a Sub-Lead:
one orchestrator-spawned headless CLI per lane on the same CLI backend. The
Sub-Lead decomposes the lane into a mini-plan, delegates
implementation to backend workers in parallel, then
review-iterates via the in-process path (`go/internal/reviewiterate`):
fresh-context parallel sub-agent review (the session that
produced the diff never reviews its own output — self-review scope, Execution
Backend Contract). Advisory reviewers share no conversation state with the
producing worker; the primary verdict always comes from the brain (claude host)
only. Mode 1 review does **not** use any live-notice transport — durable handoff
and live notice must not mix. The Sub-Lead
re-dispatches refinement into the same worktree until the lane's DoD is met or a
max-iteration cap is hit, after which it escalates to the human. The Sub-Lead
reports up to the Lead, which aggregates. Workers still never message each other;
all coordination is spoke->hub.

Peer co-drive — removed before v1.0.0, deliberately. Live notice messaging
between concurrent human-opened peer terminals (a SQLite event log plus host-hook
delivery, modeled on the agmsg pattern) was implemented and then removed: it
carried its own store, hooks, and Session Monitor surface for a collaboration
shape no operator had yet asked for. If peer co-drive returns, two constraints
from the prototype hold. First, store and notice must live in the same
host-hook-owning layer — the earlier broadcast attempt died precisely because
they were split and the notice never fired, so delivery must prove via tests that
it fires on a normal turn. Second, a peer transport must never carry Mode 1
review or cross-session verdict traffic; durable work-handoff and live notice
stay separate.

Memory boundary. Durable, work-linked, ackable handoff stays in harness-mem
(`signal-store` / workgraph claim+handoff) and is load-bearing there. It is the
only surviving cross-session handoff channel: durable work-handoff = harness-mem
signal.

### Risk Gate distribution contract

Five canonical floor categories are enumerated in
`go/internal/runtimefloor` as a non-overridable runtime gate:

- `money-billing`
- `egress`
- `secret-read`
- `prod-deploy`
- `worktree-escape`

These five categories fire at the Claude Code `PreToolUse` hook at exit code
2 (`tests/test-3cli-hook-floor.sh` enforces 5 cases, one per category). Tool actions not covered
by a hook surface (e.g. non-Bash tools) are structurally complemented by Phase
92.2.2 fingerprint containment, which detects worktree-external writes
regardless of the originating tool.

The canonical floor policy fragment exported by `harness gen hooks`
(`go/internal/hostgen` `FloorPolicyFragment`) is the single source of truth for
the `floor_policy` block, replicated unchanged into the generated Claude Code
hooks config. Drift in this block is a contract violation.

### Approval automation scope

There is no approval-skip path in v1.0.0, and no environment variable enables
one. Every risk gate, external-send confirmation, and review approval fires for
the operator. An experimental `HARNESS_AUTO_APPROVE` flag existed pre-1.0 but
only ever wrote a ledger entry, so it was removed rather than shipped as a
switch that implied more than it did.

Approval automation stays **deferred**, gated on HOTL governance verification:
the U0–U7 evidence must prove the harness is safe to run unattended before any
approval-skip behavior ships. Autonomy is an output of a proven harness, not a
starting point.
