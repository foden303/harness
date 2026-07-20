# Spec Sub-Spec: execution-backends-and-distribution

This sub-spec is part of the `spec.md` product contract. SSOT order is `spec.md` core > `docs/spec/*` sub-specs > `Plans.md`.

## Execution Backend Contract

Harness adopts the **Kernel + Prompt Pack** model. `harness work` assembles the
embedded prompt pack plus the resolved task and emits it for the host to
execute; the binary does not call an LLM and is not a self-built agent loop or a
direct-API driver. A self-driving agent loop was evaluated and rejected: native
hooks already give per-action gating, so the kernel adjudicates while the host
runs the model. ACP is not adopted — the host's native pre-action hook
provides per-action enforcement, so no cross-host protocol is required.

The execution backend is Claude, the native host. Its native pre-action hook
converges on the `harness hook pre-tool` entrypoint:

| Backend | Native pre-action event | Deny mechanism |
|---------|-------------------------|----------------|
| Claude | `PreToolUse` | exit code 2 |

Deny is exit code 2; that is the enforcement contract. The kernel does not
embed a rule engine in the host — the generated hook routes to one
`bin/harness hook pre-tool`, which runs the R01-R13 `go/internal/policy`
engine. `go/internal/hookcodec` normalizes the host's stdin shape (`session_id`,
`tool_input`) into the rule-engine input, and emits the host's deny shape
(`permissionDecision`) so the rule table never changes.

Changes that arrive from a path a native hook cannot see are untrusted until
they pass the **FLOOR** (`go/internal/floor`): a universal pre-merge gate that
re-evaluates the candidate diff with `harness policy check` (the same R01-R13
surface the hook calls) plus the contract greps, before any take-in. The FLOOR
is the backstop for paths a native hook cannot see (nested subagents, in-process
shells), so it runs before every take-in regardless of which native hook already
fired.

Roles resolve their own model tier. The primary review and advisor roles stay on
the brain (the `claude` host); per-role models resolve via
`scripts/model-routing.sh`, and the `HARNESS_BRAIN_MODEL` opt-in described below
affects only the `deep`/`advisor` tiers — the primary `review` tier is not
changed by it. The self-review prohibition is scoped to the producing context,
not the model family: the session that produced a diff must never review its own
output, but a fresh-context reviewer session may run an advisory pre-review pass
before the brain's primary review. A pre-review session qualifies as
fresh-context only when it shares no conversation state with the producing worker
session and starts from the diff plus the task brief. Pre-review findings are
advisory input to the brain; the primary verdict always remains with the brain
reviewer.

The concrete model for any role is resolved by
`scripts/model-routing.sh --role <role>`. This contract does not reimplement
model selection. The claude-host brain tiers (`deep`, `advisor`) default to
`claude-opus-4-8`; setting `HARNESS_BRAIN_MODEL=fable` opts those two tiers into
`claude-fable-5`. Unset, empty, or `opus` keeps the default; any other value
fails with exit 2 instead of falling back silently. The opt-in never changes the
worker or review tiers.

## Orchestration Visibility Contract

Worker delegation is invisible at runtime: a user cannot tell whether work was
delegated to a spawned sub-agent worker or kept inline in the main session. The
harness must make the session's actual delegation observable, so a user can
answer "am I really orchestrating, or did everything run inline?" and can show
the result to others.

The contract separates recording from display. Recording is always on; display
is on demand. The harness keeps two scopes: a per-session ledger of the current
session's delegations, and a lifetime accumulator that persists cumulative
totals across sessions in `.claude/state/orchestration-totals.json`
(project-scoped). Session delegations roll up into the accumulator when the session's tasks are
all complete, and again at session end as a safety net; the rollup always runs
and is never gated behind display. The rollup must
be idempotent per `session_id` so a session counted once is never
double-counted. A user-scope total across all projects is an optional extension,
not required here.

Per-task completion never triggers display; that would spam a multi-task
session. The one allowed automatic surface is a single compact terminal summary,
emitted once when the session's tasks are all complete (the rollup runs first,
so the summary reflects the updated lifetime totals). The HTML scorecard is
never emitted automatically. Surfaces report both the current session count and
the lifetime totals; the lifetime totals are the primary shareable figure.

The scorecard derives delegation counts from the existing worker spawn trace
(`.claude/state/agent-trace.jsonl`, role `worker`). The result is an
`orchestration-scorecard.v1` snapshot reporting the delegated worker count and a
tri-state status — `used` (count > 0), `available` (the worker path resolves but
was unused this session), or `not-configured` (spawn tracing unavailable).
`not-configured` is a neutral state, never a failure or warning.

Two surfaces consume the snapshot: a standalone HTML scorecard rendered through
`scripts/render-html.sh` (redaction layers applied as defense-in-depth, so it is
shareable), produced only on demand; and a compact terminal summary, produced on
demand and additionally emitted once at full-session completion. Neither is
emitted on every task completion. Both report session count plus lifetime totals.

If the trace is missing or unreadable, the scorecard degrades to
"no delegations observed" rather than erroring; absent observation is not the
same as absence of work.

## Onboarding Contract

Onboarding is not complete when files are copied. It is complete when the first
useful session can be verified.

New-user onboarding must provide:

- a tool-first front door: "which agent are you using now?",
- an install or setup route for that host,
- the first command or first prompt to try,
- what successful bootstrap looks like,
- a verification command or smoke transcript,
- the support tier and known asymmetries.

Existing-user migration must provide:

- a before-state inventory,
- backup locations outside skill scan paths,
- stale plugin/cache/residue detection,
- duplicate local skill detection,
- harness-mem state handling that never deletes memory by default,
- rollback instructions that avoid destructive cleanup unless explicitly
  confirmed.

Superpowers is the reference pattern for multi-host onboarding: common skills,
thin host adapters, bootstrap guidance, skill-trigger tests, and explicit host
tool mapping. Harness may cherry-pick that pattern, but every copied idea must
be translated into Harness lanes, Plans.md tasks, TDD/review gates, and support
tier evidence.

## Host Distribution Contract

Distribution is a single `harness` CLI binary plus the manifests and mirrors that
Claude Code reads directly. The generated shims — the hooks.json config, the
skill/agent mirrors, the manifest, and the catalog docs — are generated from one
source (`hosts.toml`, `skills/`, and the embedded prompt pack), never
hand-maintained, and are committed-and-drift-checked rather than gitignored. The
reason they stay committed: the Claude plugin marketplace clones the repo and
reads `.claude-plugin/*` directly — there is no install-time generation
step, so the generated artifacts must be present in the distributed tree. Drift is
prevented by CI gates (`harness gen --check`, `sync-skill-mirrors.sh --check`),
not by regenerating on the target. There is one version: a single git tag.
Manifests and mirrors do not carry independently bumped versions.

Rules:

- The release unit is the `harness` binary plus `hosts.toml` and the embedded
  prompt pack. The generated shims are regenerated from those by `harness gen`;
  they are never the source of truth.
- `harness gen` writes the native hook config to its `hook_path` from
  `hosts.toml` (`.claude-plugin/hooks.json`), routing to
  `bin/harness hook pre-tool`. `harness gen --check` diffs the generated output
  against golden fixtures in CI so the generator cannot drift. The Claude
  `.claude-plugin/hooks.json` is hand-maintained across its full event set and is
  not overwritten, but `harness gen --check` verifies its PreToolUse guardrail
  group still matches `hosts.toml`, so the pre-action route cannot drift even
  though the rest of that file is not generated.
- Generated component paths must stay inside the install package and must not use
  `..` relative paths. The generator normalizes to in-package locations
  (`./skills/`, `./agents/`, or equivalent).

Two layers, not one. The `hook_path` config above (`.claude-plugin/hooks.json`)
is the enforcement-wiring layer `harness gen` emits to route the native
pre-action hook to `bin/harness hook pre-tool`. The install-delivery layer is
separate: `scripts/build-host-plugin-dist.sh` packages the native plugin bundle
(`.claude-plugin/`) carrying the generated skills/agents, which setup installs
into the host (the Claude marketplace clone). Using the host's native plugin as
the install envelope does not contradict "single `harness` CLI, not a host
plugin": the binary plus `hosts.toml` and the embedded prompt pack stay the sole
source of truth and the release unit; the plugin is only the generated,
committed-and-drift-checked envelope that carries the shims to the host.

Cutover status (landed as generated-and-committed): the manifests
and mirrors are generated from one source and kept committed under CI drift gates,
not untracked. Investigation of the real distribution path settled this: it
consumes committed files with no install-time generation — the Claude
marketplace clones the repo and reads `.claude-plugin/*` — so untracking and
gitignoring them (the originally sketched "generated-on-install" model) would
break installation at the distribution target. Instead the SSOT is `skills/` +
`hosts.toml` + the prompt pack: `sync-skill-mirrors.sh --check` pins the mirrors
to `skills/`, `harness gen --check` pins the hooks.json to `hosts.toml` and
verifies the committed Claude PreToolUse guardrail group matches the descriptor,
and `harness gen docs --check` pins the catalog. The artifacts stay committed so
distribution keeps working, and the gates make them as drift-proof as gitignored
build output would be. A future pure-CLI install that regenerates on the target
could revisit untracking; it is out of scope while marketplace distribution is
the supported path.

## Clean Mode And Compatibility Mode

Harness defines two user-facing environment profiles. These are Harness
diagnostic and guidance profiles, not host-native global toggles. A host may
still load another host's skill directories when the user enables host
compatibility import.

| Profile | Meaning | Expected UX |
|---------|---------|-------------|
| `clean` (default) | One host, one Harness route. Users should see their own host's package skills only after cleanup. | Fewer duplicate skills/plugins; explicit host-specific invocation. |
| `compatibility` | Cross-host skill import remains enabled. Harness warns about duplicates but does not force-disable host import settings. | More skills visible; Harness recommends namespaced or explicit invocation. |

Harness must not delete user home configuration by default. Environment cleanup
uses dry-run inventory first, then user-confirmed archive or disable actions.
Compatibility import can reintroduce duplicate skills even
after clean distribution packages are installed; Harness documents that limit
and detects duplicate origins before suggesting fixes.

