# Epic rubric (Step 2)

Score the Epic against **12 gates**: 8 blockers and 4 advisories. A blocker
failure means the Epic cannot be broken into stories without guessing. An
advisory failure is worth telling the BA about but does not, on its own, hold the
Epic.

This is the epic-level counterpart of the user-story rubric in
`skills/harness-story-verify/references/us-rubric.md`. Do not score story gates
here — an Epic legitimately has no acceptance criteria of its own; it has a
Definition of Done and a breakdown.

The verdict is **derived from the gates by `scripts/epic-verify-record.sh`** —
do not hand-write it:

- `needs-clarification` — any blocker `fail`, **or** `questions[]` non-empty
- `blocked` — the Epic could not be read at all (permission / MCP)
- `clear` — everything else

## The gates

The section names in parentheses are the default Epic template
(`templates/ticket-authoring/epic.md`) written by `harness-story-author`. A
project using its own format still gets scored — match on meaning, not heading
text.

| id | Severity | Pass when | Fail when |
|----|----------|-----------|-----------|
| `epic-goal-value` | blocker | States the move FROM a current painful state TO a desired state, and why now (section: Epic) | Only a title, or a restatement of the title; "improve X" with no stated pain |
| `epic-dod-observable` | blocker | The Definition of Done is an outcome a person can watch happen and call done/not-done (section: Definition of Done) | Absent, or "works well" / "is stable" / "migration complete" with no observable |
| `epic-scope-boundaries` | blocker | In-scope and out-of-scope are distinguishable; what is deliberately NOT in this Epic is named (section: Out of scope) | Open-ended scope, or a title that implies more than the body covers |
| `epic-team-split` | blocker | The work is split by the role that owns it (BE / FE / data / infra), or the split is explicitly "one team" | No breakdown at all, so no team can tell what is theirs |
| `epic-children-coverage` | blocker | Every outcome in the DoD is traceable to at least one child ticket or a named planned story | Children exist but leave a DoD outcome unowned, or zero children with no breakdown in the body |
| `epic-critical-path` | blocker | The ordered dependency chain is stated: what gates what, what can start now (section: Critical path) | No ordering given for work that clearly has one, or a flat list of parallel-looking items that are not parallel |
| `epic-dependencies-external` | blocker | Upstream/downstream teams, APIs, services, migrations, and feature flags are named — or "none" is stated | The Epic clearly needs another team's endpoint/data/approval and it is unmentioned |
| `epic-no-ambiguous-wording` | blocker | No blocking placeholders or undefined terms | `TBD`, `???`, "etc.", "as discussed", an undefined internal term, or a body that contradicts the DoD |
| `epic-design-reference` | advisory | Links a design doc / mockup, or explicitly says there is none (section: Design doc) | A user-facing Epic with no design reference and no wording for the visible surface |
| `epic-nonfunctional` | advisory | Epic-wide performance, security/permission, data-retention, i18n, and accessibility expectations are stated where relevant | The Epic obviously carries one (money, PII, auth, bulk data, real-time) and it is unmentioned |
| `epic-rollout-backout` | advisory | Rollout shape is stated: flagged, phased, or big-bang, plus what happens to existing data and how to back out | A migration or a replacement of a live system with no rollout or backout stated |
| `epic-success-metrics` | advisory | States how anyone will know it worked after ship (a metric, a report, a check) | No signal at all for an Epic whose value claim is measurable |

## Scoring rules

- **Evidence, not impression.** Each check carries `evidence`: the quoted Epic
  text the judgment rests on. If the section is absent, `evidence` is `""` and
  the note says which section was missing.
- **`n-a` needs a reason.** A gate that genuinely does not apply (e.g.
  `epic-design-reference` on a pure data-pipeline Epic) is `n-a` **with a note**.
  The record helper rejects an `n-a` with no note, so a gate is never silently
  skipped.
- **Judge the Epic as written.** Do not resolve a gap from repository knowledge,
  a sibling Epic, or a Confluence page the Epic does not link to.
- **Read the comments too.** An answer already given in a comment counts as
  present — quote it as `evidence` and pass the gate. This prevents re-asking.
- **Children are evidence, not a rubric target.** Use the child inventory to
  score `epic-team-split` and `epic-children-coverage`. Do not score a child's
  own quality here — that is `harness-story-verify`.

## Record shape

```json
{
  "issue_key": "PROJ-100",
  "issue_url": "https://<site>/browse/PROJ-100",
  "title": "[Stream Detection] Rule Flow & OCSF Transition",
  "issue_type": "Epic",
  "status": "To Do",
  "reporter_account_id": "<ba-account-id>",
  "reporter_display_name": "Jamie Tran",
  "child_keys": ["PROJ-101", "PROJ-102"],
  "child_count": 2,
  "checks": [
    {"id": "epic-goal-value", "severity": "blocker", "result": "pass",
     "note": "", "evidence": "Detectors run per-index today; we move to a single stream."},
    {"id": "epic-dod-observable", "severity": "blocker", "result": "fail",
     "note": "DoD says 'migration complete' with nothing observable", "evidence": "DoD: migration complete"},
    {"id": "epic-design-reference", "severity": "advisory", "result": "n-a",
     "note": "no user-facing surface in this epic", "evidence": ""}
  ],
  "questions": [
    {"lens": "be", "gate": "epic-dod-observable",
     "text": "\"Migration complete\" — is done measured as (a) zero events still routed through the old detector for 24h, (b) parity between old and new alert counts within a stated tolerance, or (c) something else?",
     "why": "Without the finishing condition there is no way to tell a partial cutover from a finished one."}
  ]
}
```

Persist through the helper (it stamps `verified_at`, derives `verdict`,
schema-validates, and rejects a question citing a gate that did not fail):

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/epic-verify-record.sh" \
  --in "$TMP/PROJ-100.draft.json" \
  --out ".claude/state/epic-verify/proj-100/epic.json"
```

## Routing note

`needs-clarification` is a **request for information, not a rejection of the
Epic**. Never phrase the report or a comment as the Epic being bad work — it is
a list of what three teams will otherwise each guess differently.
