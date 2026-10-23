# Lens: BE — the backend question template

Ask the Epic as the engineer who has to store the data, expose the contract, and
keep it running. This lens owns everything behind the interface.

Every question must still cite a **failing gate** from
`references/epic-rubric.md` — the lens decides *how* to ask, never *whether*
there is something to ask. `epic-verify-record.sh` rejects a question whose gate
did not fail.

## What this lens is responsible for

data model and ownership · API/event contracts · idempotency and ordering ·
volume, throughput, retention · migration and backfill · auth/permission
enforcement · failure modes and retries · external service dependencies

## Checklist → gate

Walk this list against the failing gates. A row that the Epic already answers
produces no question.

| Ask about | Typically fails as | Ask when the Epic |
|-----------|--------------------|-------------------|
| Where the data lives and who owns it | `epic-goal-value`, `epic-dependencies-external` | Introduces or moves a dataset without naming the owning service/store |
| The contract: API, event, or schema shape | `epic-dependencies-external`, `epic-team-split` | Splits BE and FE work without naming the contract between them |
| Whether the contract is new, versioned, or breaking | `epic-rollout-backout` | Changes an interface other teams already consume |
| Volume, throughput, and retention | `epic-nonfunctional` | Handles a stream, bulk data, or anything described as "real-time" |
| Idempotency, ordering, duplicates | `epic-dod-observable`, `epic-nonfunctional` | Processes events or messages where replay is possible |
| Migration and backfill of existing data | `epic-rollout-backout` | Replaces a live system or changes a stored shape |
| What "done" means as an observable backend signal | `epic-dod-observable` | Defines done as a state ("migration complete") rather than an observation |
| Failure behaviour: retry, dead-letter, alert | `epic-dod-observable`, `epic-nonfunctional` | Has an obvious failure path that is unmentioned |
| Auth: which service or role may call this | `epic-nonfunctional` | Exposes data with any access distinction |
| Which upstream/downstream teams gate the work | `epic-dependencies-external`, `epic-critical-path` | Needs another team's endpoint, data, or approval |
| Sequencing: what must land first | `epic-critical-path` | Lists work with a real order but presents it flat |
| Which child ticket owns each backend outcome | `epic-children-coverage`, `epic-team-split` | Leaves a DoD outcome with no backend child |

## Wording rules

Same bar as the story rubric: answerable in one sentence or a short list,
specific to this Epic, decision-shaped where possible, and paired with a `why`.
The reader is a BA, so:

- **Ask for the decision, not the design.** "Which system is the source of truth
  for a rule after the cutover — the UI store or the stream config?" Not "should
  we use CDC or dual-write?"
- **Offer the plausible options** so the BA can pick instead of composing prose.
- **Never ask the BA to size or architect.** No "what throughput can the cluster
  take" — ask what throughput the business needs it to take.

Bad: "What's the schema?"
Good: "The Epic says alerts move to OCSF — do downstream consumers (SIEM export,
the alerts API) switch at the same time, or must both formats be served during
the transition? That decides whether this is one migration or two."

## Question shape

```json
{"lens": "be",
 "gate": "epic-dependencies-external",
 "text": "…",
 "why": "One line on what cannot be built, sized, or tested until this is answered."}
```
