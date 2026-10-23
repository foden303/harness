# User-story rubric (Step 2)

Score every ticket against **12 gates**: 8 blockers and 4 advisories. A blocker
failure means the team cannot start without guessing. An advisory failure is
worth telling the BA about but does not, on its own, hold the ticket.

The verdict is **derived from the gates by
`scripts/story-verify-record.sh`** — do not hand-write it:

- `needs-clarification` — any blocker `fail`, **or** `questions[]` non-empty
- `blocked` — the ticket could not be read at all (permission / MCP)
- `clear` — everything else

## The gates

| id | Severity | Pass when | Fail when |
|----|----------|-----------|-----------|
| `goal-value-clear` | blocker | The ticket says what outcome is wanted and why it matters | Only a title, or a restatement of the title as the description |
| `ac-present-testable` | blocker | ≥1 acceptance criterion, each decidable Yes/No by a person or a test | Zero criteria, or criteria like "works fine", "is fast", "user-friendly", "as expected" |
| `ac-covers-happy-path` | blocker | The main success path is fully specified end to end: trigger → action → observable result | Criteria only mention a screen or a field with no stated outcome |
| `edge-error-states` | blocker | Failure, empty, loading, and permission-denied behaviour is stated (or explicitly out of scope) | Only the happy path is described and the ticket clearly has failure modes |
| `data-validation-rules` | blocker | Fields, types, required/optional, limits, formats, and default values are stated for every input the story introduces | A new input exists with no rule stated ("enter an amount" with no bounds/currency/precision) |
| `scope-boundaries` | blocker | In-scope and out-of-scope are distinguishable; non-goals stated where the story could sprawl | Scope is open-ended, or the title implies more than the description covers |
| `dependencies-identified` | blocker | Upstream/downstream tickets, APIs, services, teams, migrations, and feature flags are named — or "none" is stated | The story clearly needs another team's endpoint/data and it is unmentioned |
| `no-ambiguous-wording` | blocker | No blocking placeholders or undefined terms | `TBD`, `???`, "etc.", "and so on", "similar to the old one", "as discussed", contradictions between description and AC |
| `story-format` | advisory | States the role, the capability, and the benefit (the `As a … I want … so that …` shape or an equivalent) | Purely technical phrasing with no user or benefit named |
| `design-reference` | advisory | UI-facing story links a mockup/design, or explicitly says there is no UI change | A UI story with no design reference and no wording for the visible copy |
| `nonfunctional-stated` | advisory | Relevant performance, security/permission, accessibility, i18n, and analytics expectations are stated | The story obviously carries one (money, PII, auth, bulk data) and it is unmentioned |
| `invest-sizing` | advisory | A vertical slice deliverable in one sprint, independently valuable | Multiple unrelated deliverables in one ticket, or an obvious multi-sprint lump |

## Scoring rules

- **Evidence, not impression.** Each check carries `evidence`: the quoted ticket
  text the judgment rests on. If the field is absent, `evidence` is `""` and the
  note says which field was missing.
- **`n-a` needs a reason.** A gate that genuinely does not apply (e.g.
  `design-reference` on a backend job) is `n-a` **with a note**. The record
  helper rejects an `n-a` with no note, so a gate can never be silently skipped.
- **Judge the ticket as written, not as understood.** Do not resolve a gap using
  repository knowledge, a sibling ticket, or the Epic description unless the
  ticket explicitly links to it. The team building this ticket reads this ticket.
- **Read the comments too.** An answer already given in a ticket comment counts
  as present — quote it as `evidence` and pass the gate. This prevents asking
  the BA a question they already answered.
- **One failing gate can yield more than one question**, but every question must
  name its gate.

## Question quality bar

Questions go to a BA, not an engineer. Each one must be:

1. **Answerable in one sentence or a short list** — no "please clarify the
   requirements" catch-alls.
2. **Specific to this ticket**, quoting the phrase that is unclear.
3. **Decision-shaped where possible** — offer the plausible options so the BA can
   pick instead of composing prose:
   > "When the upload exceeds 10 MB, should we (a) reject with an error,
   > (b) compress it, or (c) accept it and queue it? The AC does not say."
4. **Paired with `why`** — one line on what cannot be built or tested until it
   is answered. This is what makes a BA prioritise replying.

Bad: "The acceptance criteria are unclear."
Good: "AC-2 says the export 'should be quick' — what is the acceptable wait for a
10k-row export (e.g. under 5s), and what does the user see while it runs?"

## Record shape

Write per-ticket JSON, then persist through the helper (it stamps
`verified_at`, derives `verdict`, and schema-validates):

```json
{
  "issue_key": "PROJ-123",
  "issue_url": "https://<site>/browse/PROJ-123",
  "title": "Export the transaction list to CSV",
  "issue_type": "Story",
  "status": "To Do",
  "parent_key": "PROJ-100",
  "reporter_account_id": "<ba-account-id>",
  "checks": [
    {"id": "goal-value-clear", "severity": "blocker", "result": "pass",
     "note": "", "evidence": "So that finance can reconcile monthly."},
    {"id": "ac-present-testable", "severity": "blocker", "result": "fail",
     "note": "AC-2 'should be quick' is not decidable", "evidence": "AC-2: export should be quick"},
    {"id": "design-reference", "severity": "advisory", "result": "n-a",
     "note": "backend-only story, no UI change", "evidence": ""}
  ],
  "questions": [
    {"gate": "ac-present-testable",
     "text": "AC-2 says the export 'should be quick' — what is the acceptable wait for a 10k-row export, and what does the user see while it runs?",
     "why": "Without a number there is no way to write a passing test or size the work."}
  ]
}
```

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/story-verify-record.sh" \
  --in "$TMP/PROJ-123.draft.json" \
  --out ".claude/state/story-verify/<batch-id>/PROJ-123.json"
```

Then mirror the state onto the batch cursor:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/story-verify-batch.sh" \
  set-state ".claude/state/story-verify/<batch-id>/batch.json" PROJ-123 needs-clarification
```

## Routing note

`needs-clarification` is a **request for information, not a rejection of the
ticket**. Never phrase the report or the comment as the ticket being bad work —
it is a list of what the implementer will otherwise have to guess.
