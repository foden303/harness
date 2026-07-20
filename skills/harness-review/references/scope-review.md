# Scope Review

## In one line

Scope Review checks that nothing required has been left out, and conversely that nothing unnecessary has been done.

## Checkpoints

- The diff matches the user request
- The task's DoD is satisfied
- No unrelated refactor is mixed in
- The needed scope of docs / tests / mirror / changelog is complete
- Checks whether any new public surface has been added
- Migration / release / permission boundaries were not changed arbitrarily

## Scope creep

Scope creep is "the work expanding beyond what is necessary."
For example, starting to change a release script during a docs-fix task is dangerous.

When you find scope creep, split it into one of the following.

- Needed for this DoD: state it explicitly in the plan and proceed
- Not needed for this DoD: carve it out into a separate task

## Verdict

| State | Judgment |
|---|---|
| Request and diff match | APPROVE |
| DoD unmet or unnecessary changes mixed in | REQUEST_CHANGES |
| Business decision on scope change is needed | decision_needed |
