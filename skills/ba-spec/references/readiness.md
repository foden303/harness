# Spec readiness checklist (step 3)

Run every check on the draft. A failing check becomes a gap: either a question
in step 4, or (if the BA says "leave it") an Open question with an owner and the
section it blocks. The spec is ready to show when every check passes or every
failure is an owned Open question.

| # | Check | Passes when |
|---|-------|-------------|
| 1 | Problem and goal | Overview names who has the problem and the outcome after shipping |
| 2 | Success metrics | At least one metric with today's value (or "not measured today"), a target, and how it is measured |
| 3 | Scope | At least one In and one Out item; every Out and Later item says why or where it goes |
| 4 | Personas | Every actor named in a flow or rule appears in Users & personas with permissions |
| 5 | Flows end | Every flow F-n has numbered steps and an **end state** |
| 6 | Flows fail | Every flow F-n has at least one **error path** tied to a step |
| 7 | Rules testable | Every BR-n has a condition and an outcome checkable Yes/No; limits have numbers, permissions name roles |
| 8 | Rules cited | Every BR-n has a source (R-n, BA answer with date, or page section) |
| 9 | Data complete | Every data field has **Required** and **Rules** filled (and Default when optional) |
| 10 | Screens | Screens/UI links a design, names the screens without a design yet as a gap, or says "No UI" with the reason |
| 11 | Non-functional | Only applicable rows; each has a number or a named role |
| 12 | Dependencies | Every integration names what is needed and its status |
| 13 | Rollout | Release approach and migration stated (migration may be "none" with the reason) |
| 14 | Traceability | Every R-n from the brief is mapped to a BR / F / section, or explicitly **Dropped** with a reason |
| 15 | No ambiguous words | No `fast`, `easy`, `simple`, `intuitive`, `user-friendly`, `secure`, `robust`, `scalable`, `real-time`, `soon`, `large`, `many`, `etc.`, `and so on`, `as needed`, `if possible`, `appropriate` without a measurable meaning |
| 16 | No placeholders | No `TBD`, `???`, unfilled `{{slot}}`, empty heading or `n/a` filler |
| 17 | Open questions owned | Every Q-n has an owner and names what it blocks |
| 18 | No code | No API, endpoint, table, column or function names; field names are the names users see |

## Scoring

Report the result in one line: `Readiness: 16/18 passed — 6 (F-2 has no error
path), 14 (R-7 not traced)`. Never narrate passing checks.

A brief with `R-n` rows makes check 14 strict: an untraced R-n is always a
question ("R-7 'bulk export for auditors' is not in the spec. (a) add as F-3,
(b) move to Later, (c) drop — who agreed?"). With idea input, check 14 applies
to the `I-n` needs instead.
