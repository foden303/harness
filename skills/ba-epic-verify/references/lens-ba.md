# Lens: BA — the business question template

Ask the Epic as the analyst who has to defend it: why this, why now, what is
deliberately not in it, and how anyone will know it worked. This lens owns the
questions that no amount of engineering can answer.

Every question must still cite a **failing gate** from
`references/epic-rubric.md` — the lens decides *how* to ask, never *whether*
there is something to ask. `epic-verify-record.sh` rejects a question whose gate
did not fail.

## What this lens is responsible for

the user and the pain · value and priority · scope boundaries and non-goals ·
business rules and edge decisions · who signs off · rollout and communication ·
success signals · what happens to users mid-migration · regulatory/contractual
constraints

## Checklist → gate

| Ask about | Typically fails as | Ask when the Epic |
|-----------|--------------------|-------------------|
| Who the user is and what they cannot do today | `epic-goal-value` | Describes a system change with no affected user named |
| Why now — what forces the timing | `epic-goal-value` | Reads as a nice-to-have with an implied deadline |
| What the Epic is deliberately NOT doing | `epic-scope-boundaries` | Has no out-of-scope statement and could sprawl |
| Which parts are must-have vs. nice-to-have | `epic-scope-boundaries`, `epic-team-split` | Bundles work that could ship in stages |
| The business rule behind an ambiguous behaviour | `epic-no-ambiguous-wording` | Uses an undefined term or "as discussed" |
| Who decides / who signs off that it is done | `epic-dod-observable` | States a DoD nobody is named as accepting |
| What existing users experience during the change | `epic-rollout-backout` | Replaces or migrates something already in use |
| Rollout shape: flagged, phased, or all at once | `epic-rollout-backout` | Changes live behaviour with no rollout stated |
| Whether anything must be communicated or trained | `epic-rollout-backout` | Changes a workflow people already know |
| How success is measured after ship | `epic-success-metrics` | Claims a benefit with no signal to check it |
| Regulatory, contractual, or retention constraints | `epic-nonfunctional` | Touches PII, money, audit trails, or customer data |
| Which team or person owns the excluded work | `epic-scope-boundaries`, `epic-dependencies-external` | Excludes something without saying who picks it up |
| Whether a missing child covers a promised outcome | `epic-children-coverage` | Promises an outcome in the DoD with no child ticket |
| What blocks the start — a decision, not code | `epic-critical-path` | Starts with an unmade decision and does not say so |

## Wording rules

- **Ask for a decision the business owns**, never an implementation detail.
- **Make the trade-off visible.** "Dropping X would let this ship a sprint
  earlier — is X required for the first release, or can it follow?"
- **One question, one decision.** Do not bundle scope, priority, and rollout into
  a single paragraph.
- **Never imply the Epic is poor work.** Every question is about what three teams
  will otherwise each guess differently.

Bad: "Please clarify the scope."
Good: "The DoD includes 'OpenSearch detectors are off', but no child ticket
covers decommissioning them — is that in this Epic, or does another team own the
teardown after cutover?"

## Question shape

```json
{"lens": "ba",
 "gate": "epic-scope-boundaries",
 "text": "…",
 "why": "One line on what cannot be built, sized, or tested until this is answered."}
```
