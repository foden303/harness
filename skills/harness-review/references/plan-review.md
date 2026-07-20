# Plan Review

## In one line

Plan Review checks whether `Plans.md` is at an implementable granularity and in an implementable order.

## Checkpoints

- Each task is a single completion unit
- The DoD is verifiable
- Depends is not circular
- Status matches reality
- Tasks that need a spec contract have a `spec_path` or a creation task
- The implementation order does not defer the high-risk parts
- The review / release / mirror / docs closeout is not missing

## Verdict

| State | Judgment |
|---|---|
| DoD is measurable, Depends is sound, scope is clear | APPROVE |
| DoD is vague, dependencies are broken, or a spec contract is needed but missing | REQUEST_CHANGES |
| Scope needs to change without a user decision | decision_needed |

## Output

In Plan Review, prefer file:line.
Base your reasoning on the relevant lines of `Plans.md`, docs, and the spec contract.
