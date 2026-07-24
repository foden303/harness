# Authoring rubric (Steps 2-3)

Score the draft against the **same 12 gates** `harness-story-verify` uses, so a
ticket this skill authors would pass the verify it later faces. The difference is
what a failure *does*: in verify a failing blocker becomes a comment on the
ticket; here it becomes a **question to the BA in-session**, and the draft cannot
reach `ready` until it is answered.

The readiness is **derived by `scripts/story-author-record.sh`** — do not
hand-write it:

- `needs-input` — any blocker `fail`, **or** any `open_questions[]` entry whose
  `answer` is empty
- `created` — set only after `createJiraIssue` (via `--set-created`)
- `ready` — everything else

## The gates

Same ids as `story-verification.v1`. For a Story, all apply. For an **Epic**, the
gates read at epic altitude — the mapping column says how.

| id | Severity | Pass (Story) when | At Epic altitude |
|----|----------|-------------------|------------------|
| `goal-value-clear` | blocker | Says the outcome wanted and why it matters | The `## Epic` context paragraph names the from→to and why now |
| `ac-present-testable` | blocker | ≥1 criterion, each decidable Yes/No | `## Definition of Done` is one observable, decidable outcome |
| `ac-covers-happy-path` | blocker | Main success path is trigger→action→result | DoD covers the end-to-end path, not just one component |
| `edge-error-states` | blocker | Failure/empty/loading/permission stated or out-of-scope | n-a at epic level unless the epic hinges on a failure mode |
| `data-validation-rules` | blocker | Every new input has type/limits/format/default | n-a at epic level (belongs to the children) |
| `scope-boundaries` | blocker | In-scope vs out-of-scope distinguishable | `### Out of scope for this epic` is present and concrete |
| `dependencies-identified` | blocker | Upstream/downstream/APIs/flags named, or "none" | `## Critical path` names what gates what |
| `no-ambiguous-wording` | blocker | No `TBD`/`???`/"etc."/undefined terms | Same — placeholders in the draft are gaps to ask about |
| `story-format` | advisory | Role + capability + benefit shape | n-a (epics are not `As a…`) |
| `design-reference` | advisory | UI story links a design, or "no UI change" | `**Design doc:**` slot is a link or "none" |
| `nonfunctional-stated` | advisory | Perf/security/a11y/i18n stated when relevant | Relevant when the epic carries money/PII/auth/bulk data |
| `invest-sizing` | advisory | One-sprint vertical slice | The child breakdown is INVEST-sized (see epic-breakdown.md) |

## Scoring rules

- **Fill first, then score.** Populate every slot you can from the intent/brief
  before scoring. A gate fails only when its slot is genuinely un-fillable from
  what the BA gave you — not because you chose not to fill it.
- **Never invent to pass.** If a blocker slot is empty, mark the gate `fail` and
  raise a question. Do not write a plausible acceptance criterion to make the
  gate green — a guessed AC that looks answered is the exact failure this skill
  exists to prevent.
- **`n-a` needs a note.** A gate that truly does not apply (e.g.
  `data-validation-rules` on an epic) is `n-a` **with a note**; the record helper
  rejects a noteless `n-a`.
- **One gate → one or more questions**, but every question names its gate.

## Question quality bar (Step 3)

Questions go to a BA, mid-authoring. Ask via `AskUserQuestion` so the BA picks
rather than composes. Each question must be:

1. **Answerable in one sentence or a pick** — no "please clarify the requirements".
2. **Specific to this draft**, quoting the slot that is empty or vague.
3. **Decision-shaped** — offer the plausible options as the `AskUserQuestion`
   choices so the BA selects:
   > "For a 10k-row CSV export, what is the acceptable wait? (a) under 2s,
   > (b) under 5s, (c) background job + email when ready."
4. **Paired with a `why`** — one line on what the ticket cannot promise or test
   until it is answered.

Bad: "What are the acceptance criteria?"
Good: "When the export exceeds 10 MB, should we (a) reject with an error,
(b) stream it, or (c) queue it and notify? The draft doesn't say, so QA can't
write the failure test."

Ask in **batches by gate**, fold every answer back into the draft, then re-score.
Stop asking when readiness is `ready`, or when the operator explicitly says
"author it as-is" — in which case move any still-empty blocker item into the
`## Open questions` section (Epic) or a `> Open question:` note (Story) rather
than inventing an answer, and record it as an unanswered `open_questions[]` entry
so it is visible on the created ticket.

## Record shape

Write the draft JSON, then persist through the helper (it stamps `authored_at`,
derives `readiness`, and schema-validates):

```json
{
  "mode": "story",
  "project_key": "DPD",
  "cloud_id": "43b0e557-af04-4074-b717-1199c57bc0a3",
  "issue_type": "Story",
  "title": "Export the transaction list to CSV",
  "template_ref": "default",
  "body_markdown": "## Story\nAs a finance analyst, I want …\n\n## Acceptance criteria\n1. …",
  "fields": { "labels": ["export"], "priority": "Medium" },
  "checks": [
    {"id": "goal-value-clear", "severity": "blocker", "result": "pass"},
    {"id": "ac-present-testable", "severity": "blocker", "result": "fail", "note": "no wait-time bound yet"},
    {"id": "story-format", "severity": "advisory", "result": "pass"}
  ],
  "open_questions": [
    {"gate": "ac-present-testable",
     "text": "Acceptable wait for a 10k-row export — under 2s / under 5s / background+email?",
     "why": "QA cannot write the perf test without a number.",
     "answer": ""}
  ]
}
```

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/story-author-record.sh" \
  --in "$TMP/draft.json" \
  --out ".claude/state/story-author/<draft-id>/draft.json"
```

`readiness` comes back `needs-input` while any question's `answer` is empty; once
the BA answers, set `answer`, re-write, and it flips to `ready`.
