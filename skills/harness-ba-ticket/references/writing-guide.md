# Writing guide (steps 2-4)

How to turn a rough idea into a ticket the build teams can read in two minutes.

## Style

| Do | Don't |
|----|-------|
| Plain words, short lines, one idea per bullet | Long paragraphs, repeated context |
| Real values: "max 50,000 rows", "within 5 s" | "large files", "fast", "user-friendly" |
| Business rules: "only Admins can export" | Implementation: "add a `can_export` column" |
| "Refused (400) naming the field" | "`RefundInvoiceRequest.note` empty → `codes.InvalidArgument`" |
| "Recorded in the audit log" | "writes audit key `invoice.refunded`" |
| Status names users see: Banned, Active | Wire values: `status = 4` |
| Say where out-of-scope work goes | "Out: other stuff" |
| Delete a section that has nothing to say | Keep an empty section or `n/a` filler |

Length target: a story fits on one screen (about 50 lines of markdown); an epic
the same. If a story needs more, it is probably two stories.

## Section by section

- **Title** — `[Area] [Team] What the user can do after this ships`.
  - `[Area]` is the product area (`[Admin Portal]`, `[Stream Detection]`).
  - `[Team]` is the one team that builds it: `[FE]`, `[BE]`, `[Data]` or `[AI]`.
    QA is never a title tag; QA work lives in `Notes per team`.
  - **One story or one per team?** If the teams deliver one feature that only
    works when all parts are done (an API plus the screen that is its only
    caller), write **one story**, drop the team tag
    (`[Admin Portal] Invite a user into an organization`), and list every team
    in `**Teams:**`. Split into one story per team (`[Admin Portal] [BE] ...` +
    `[Admin Portal] [FE] ...`, linked through `Depends on`) only when each part
    can ship and be tested on its own, or the teams work in different sprints.
  - An epic title has the area only: `[Admin Portal] Organization onboarding`.
  - Not a task name ("Implement export API").
- **Header line** — `Epic`, `Teams` (every build team plus any team with a
  note, usually QA), `Depends on` (keys or `none`, including a sibling story
  when the work is split per team).
- **Why** — the As a / I want / so that line, plus at most two lines of context.
  The benefit is what the user gains or avoids, not the capability repeated.
- **Scope** — In and Out bullets. Every Out bullet says where it goes.
- **Acceptance criteria** — Given / When / Then rows, each checkable Yes/No.
  Row 1 is the main success path end to end. Name the fields the row uses.
  3-7 rows is normal.
- **Fields** — one row per value the user enters, picks, or gets back:

  | Column | Write |
  |--------|-------|
  | Field | The name the user sees ("Email", "Organization role") |
  | Required | `Yes`, `No`, or the condition: `Yes, when Owner = New owner` |
  | Rules | Format, length, allowed values, uniqueness, who can see it |
  | Default / example | The default when optional, else a realistic example |

  Group rows by form with a bold row (`**Invite user**`) when there are several.
  "Create an account" without this table is a gap: ask which fields are required.
  A rule that is the same as an existing screen may say so ("same as signup"),
  but only when that is true, not as a guess. `None — no new inputs` when the
  story has none.
- **Edge & error cases** — missing required field, invalid format, duplicate
  value, no permission, empty data, outage/timeout, limits. Expected result as
  behaviour the user sees. `None — <why>` if truly none.
- **Notes per team** — only the teams in the header. What that team needs from
  the BA:

  | Team | Write |
  |------|-------|
  | FE | Screens, states (loading / empty / error), exact copy, design link |
  | BE | Business rules, data in / out, permissions, limits |
  | Data | Fields, source of truth, retention, which report/dashboard uses it |
  | AI | Expected behaviour with a good and a bad example, the quality bar to accept it |
  | QA | Test data to prepare, what must not regress |

- **Open questions** — only what the BA could not settle now, each with an owner.

## Ready check

The draft is ready to show when all of these hold. Anything failing becomes a
question in step 3.

1. **Why** names a role and a real benefit.
2. **Scope** has at least one In and one Out bullet.
3. **Acceptance criteria**: at least one row, every row checkable, row 1 covers
   the main path end to end.
4. **Fields** (below the AC): every input and returned value has Required and
   Rules filled, or the section says `None — no new inputs`.
5. **Edge & error cases** has rows (including a missing required field when the
   story has inputs) or an explicit `None — <why>`.
6. **Every team in the header** has a note; no note for a team not in the header.
7. **Title** is `[Area] [Team] ...` for a one-team story, or `[Area] ...` when
   several build teams share it.
8. **No code outside the BE / FE notes**: no API or function names, endpoints,
   table / column / field names, audit keys, enum numbers or file paths in the
   title, Why, Scope, AC, Fields, Edge cases or Open questions. Put them in the
   BE or FE note, or leave them out.
9. **No vague words or placeholders**: no `TBD`, `???`, `etc.`, "fast",
   "user-friendly", or unfilled `{{slot}}`.

For an epic: **Why**, **Done when** (3-6 observable bullets), **Scope**, and a
**Stories** table whose rows together deliver every Done-when bullet. An epic
contains **no code at all** (no Notes per team section); code findings belong in
the stories' BE / FE notes. No story points on the epic; teams size the stories.

## Asking (step 3)

- Use `AskUserQuestion`, **up to 4 questions per round**, grouped so related
  gaps go together.
- Each question is about **this** ticket and offers 2-4 ready-made options the BA
  can pick; they can still type their own via "Other".
- Never ask something the idea already answered.

Bad: "What are the acceptance criteria?"

Good: "Is the phone number required when creating the account?
(a) required, (b) optional, (c) not collected."

Good: "If the filtered list has more than 50,000 rows, what should happen?
(a) block with a message, (b) export the first 50,000, (c) send the file by
email when ready."

If the BA cannot answer and says "leave it", move the gap to **Open questions**
with an owner. Do not fill it with a guess.

## Epic (step 4)

1. Draft the epic, run the ready check, ask the gaps.
2. Propose the **Stories** table: one row per user-visible slice; a slice
   whose BE and FE only work together stays one row (`[Area] ...`), otherwise
   one row per team (`[Area] [Team] ...`). Each fits in a
   sprint. Mark dependencies between rows (FE usually depends on BE).
3. Draft each story with the story template (with `Epic:` set). Ask all
   stories' gaps together in the same rounds rather than one story at a time.
4. Show the table; the operator keeps, edits, or drops rows before step 5.
