# Lens: FE — the frontend question template

Ask the Epic as the engineer who has to put it on a screen. This lens owns
everything the user sees, touches, and misreads.

Every question must still cite a **failing gate** from
`references/epic-rubric.md` — the lens decides *how* to ask, never *whether*
there is something to ask. `epic-verify-record.sh` rejects a question whose gate
did not fail.

## What this lens is responsible for

entry points and navigation · screen states (loading, empty, error, partial,
permission-denied) · the exact copy shown to users · form rules and inline
validation · responsive and device scope · accessibility and i18n · what the
user sees while a slow backend runs · which surface changes and which does not

## Checklist → gate

| Ask about | Typically fails as | Ask when the Epic |
|-----------|--------------------|-------------------|
| Which screens change, and which explicitly do not | `epic-scope-boundaries`, `epic-team-split` | Describes a capability without naming the surfaces it lands on |
| Where the user enters the flow | `epic-goal-value` | Adds a capability with no stated entry point |
| Whether this is a new screen or a change to an existing one | `epic-scope-boundaries` | Leaves it ambiguous whether existing UI is replaced |
| Empty, loading, partial, and error states | `epic-dod-observable` | Only describes the happy path |
| What the user sees when the backend is slow or down | `epic-dod-observable`, `epic-nonfunctional` | Depends on a stream, a job, or a long-running call |
| Permission-denied behaviour (hidden vs. disabled vs. explained) | `epic-nonfunctional` | Has any role or access distinction |
| The actual copy: labels, empty-state text, error messages | `epic-design-reference` | Names messages generically ("show an error") |
| Design reference for the new surface | `epic-design-reference` | Is user-facing with no mockup and no stated "no design needed" |
| Device and viewport scope (desktop only? mobile? which browsers) | `epic-scope-boundaries`, `epic-nonfunctional` | Says nothing about where it must work |
| Accessibility and i18n expectations | `epic-nonfunctional` | Ships user-facing text with no stated language/a11y bar |
| What "done" looks like on screen | `epic-dod-observable` | Defines done in backend terms only |
| Which child ticket owns each user-visible outcome | `epic-children-coverage`, `epic-team-split` | Leaves a DoD outcome with no frontend child |
| Whether FE can start before the contract lands | `epic-critical-path` | Puts FE and BE work in parallel without saying what unblocks FE |

## Wording rules

- **Ask about behaviour the user can see**, not components or libraries.
- **Offer the plausible options.** State choices in user terms: "hidden entirely,
  visible but disabled with a tooltip, or visible with an explanation on click?"
- **Ask for the copy, not the tone.** A BA can write the sentence; they cannot
  approve "we'll word it appropriately."
- **Never ask the BA to design.** No layout, spacing, or component questions —
  ask what the user must be able to do and see.

Bad: "What does the UI look like?"
Good: "When a rule is assigned but no alerts have arrived yet, does the list show
an empty state ('No alerts yet — rules take up to a minute'), a spinner, or the
previous detector's alerts until the first new one lands?"

## Question shape

```json
{"lens": "fe",
 "gate": "epic-dod-observable",
 "text": "…",
 "why": "One line on what cannot be built, sized, or tested until this is answered."}
```
