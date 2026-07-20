# Spec Sub-Spec: breezing

This sub-spec is part of the `spec.md` product contract. SSOT order is `spec.md` core > `docs/spec/*` sub-specs > `Plans.md`.


Breezing has no approval-skip path: every risk gate and external-send
confirmation reaches the operator. The 5-category runtime floor and `wt
fingerprint` containment adjudicate worktree-external attempts and are
non-overridable. Gate decisions are recorded through the orchestration ledger. See "Approval automation scope" in
`operations-memory-and-collaboration.md`.

## Breezing Brief Contract

`/breezing` may accept free-text input that does not match the existing
argument-hint surface (`all`, task ranges,
`--reviewer-only`, `--parallel N`, `--no-commit`, `--no-discuss`, `--auto-mode`).
This contract productizes the Brief Composer and Decision Card schemas, the
breezing mem read layer, and their precedence against the runtime hard floor. It
builds on the Parallel Collaboration Contract (worktree discipline) and Memory
Contract (harness-mem when available); it does not replace them.

### Input classification and brief-card.v1

- `scripts/breezing-brief.sh classify "<args>"` deterministically classifies
  input as `structured` or `free-text` (regex/token parse; no LLM).
- `structured` input continues on the existing team path unchanged.
- `free-text` input is decomposed by the Lead into a `brief-card.v1` card for
  user confirmation before any worktree dispatch.
- User confirmation is Yes/No. `scripts/breezing-brief.sh confirm no` emits
  `DISPATCH: 0` — zero worker executions (dry contract). Yes dispatches one
  worker per confirmed subtask onto the existing worktree-per-task team path.
- `scripts/breezing-brief.sh validate <card.json>` validates against
  `templates/schemas/brief-card.v1.json`.

Schema `brief-card.v1` required fields:

| Field | Shape | Constraints |
|-------|-------|-------------|
| `goal` | string | non-empty |
| `subtasks` | array | 3–7 items; each item `{id, title, dod}` (all non-empty strings) |
| `scope_files` | string[] | repo-relative paths in scope |
| `risk_notes` | string[] | free-form risk strings |
| `confidence` | enum | `high` \| `medium` \| `low` |

No additional properties are permitted on the card root or subtask objects.

### judgment-card.v1

When a worker or Lead needs human judgment during breezing — and the runtime
hard floor does not apply — Harness may issue one `judgment-card.v1` card.
Schema: `templates/schemas/judgment-card.v1.json`.

Issuance conditions (any one triggers a card):

1. DoD interpretation diverges (multiple valid readings of done-ness).
2. A change outside the user-approved scope is required.
3. A trade-off choice is required (mutually exclusive options).

Required fields:

| Field | Shape | Constraints |
|-------|-------|-------------|
| `question` | string | non-empty |
| `options` | array | 2–3 items; each `{id, label, consequence}` (all non-empty strings) |
| `recommendation` | string | non-empty |
| `confidence` | enum | `high` \| `medium` \| `low` |
| `impact` | string | non-empty |
| `diff_summary` | string | non-empty one-line diff summary |

No additional properties are permitted on the card root or option objects.
User answer and rationale may be recorded via `harness_mem_record_checkpoint`
when harness-mem is available (fail-open; see below).

### Breezing mem read layer

`go/internal/breezingmem` reads past decisions from harness-mem so a judgment
card can cite what was decided before. `harness mem search-similar --project P
--query Q` returns at most 3 `SimilarPastDecision` records as JSON, and exits 0
even when the memory layer is absent.

A write half (posting `breezing_run_started` / `breezing_brief_confirmed` /
`breezing_worker_result` / `breezing_aggregation_completed` lifecycle events and
ingesting the confirmed brief card) existed before v1.0.0. Its only emitter was
the in-process `harness work --team` orchestrator; when that was removed, the
events had no producer, so the write API was removed with it rather than left as
an endpoint nothing called.

This layer does not call workgraph signal APIs (`signal_send`, `signal_read`,
`signal_ack`, or `/v1/signals/*`). Durable cross-session handoff remains in the
harness-mem signal store per the Parallel Collaboration Contract.

### Fail-open memory behavior

Breezing must never stop because harness-mem is absent or unreachable.

| State | Behavior |
|-------|----------|
| `not-configured` | Silent skip — no warning, no POST |
| `unreachable` | One stderr warning line (`breezing-mem: search skipped (unreachable)`), then continue |

Configured means `~/.harness-mem` or legacy `~/.claude-mem` exists (see
`go/internal/breezingmem` `configured()`). HTTP timeout is 1s. Mem state never
blocks brief confirmation, worker dispatch, judgment cards, or aggregation.

### Floor precedence over judgment cards

The five-category **runtime action hard floor** (money/billing,
external send/egress, credential/secret read, production deploy/publish,
destruction outside the task worktree) always takes precedence over
`judgment-card.v1`:

- When any hard-floor category matches, Harness hard-stops for the human and
  does **not** issue a judgment card.
- Judgment cards apply only to non-floor ambiguity (DoD, scope, trade-offs).
- The pre-merge policy gate (`go/internal/floor`) and runtime hard floor remain
  distinct; see the Parallel Collaboration Contract.

## workgraph signal boundary

Breezing mem lifecycle events **must not** call workgraph signal APIs
(`signal_send`, `signal_read`, `signal_ack`, or `/v1/signals/*`). Durable
cross-session handoff remains in the harness-mem signal store; breezing mem
events are run-scoped telemetry only.

A bridge daemon that normalized host mailbox events into a unified append-only
store and delivered peer notices was prototyped and removed before v1.0.0 — it
never became reachable from the `bin/harness` runtime. The design lesson is
recorded in the "Historical L3 note" of
`operations-memory-and-collaboration.md`.

