# Case rules (steps 1-4)

How to read a ticket, decide what is testable, generate cases, and prove
coverage.

## Parsing (step 1)

Read each ticket with `getJiraIssue` (summary, description, acceptance-criteria
custom field if the site has one, issue type, status, labels, parent, roles
named anywhere). Find the three inputs by section heading, in this order:

| Input | ba-ticket short format | ba-ticket `--full` format | Free text / other template |
|-------|-----------------------|---------------------------|----------------------------|
| AC rows | `## Acceptance criteria` table (`# / Given / When / Then`) | `## Acceptance Criteria Table` (`Scenario / Given / When / Then`) + `## Positive Scenarios` | Any Given/When/Then lines, "AC:" bullets, numbered "should" statements |
| Field rules | `## Fields` table (`Field / Required / Rules / Default`) | `## Contract & Schema Requirements` rows whose Type is Field or Constraint | Sentences stating a limit, format, required/optional |
| Edge & error | `## Edge & error cases` table (`# / Case / Expected`) | `## Negative Scenarios` (runtime rows only; skip "Wrong —" / "Defect —" planning rows) | "If ... then ..." error sentences |
| Roles | `## Notes per team`, Fields "who can see it", AC Given rows | AC / Contract rows naming a role | Any named role (Admin, Viewer, Finance) |

Number what you parsed so it can be traced:

- AC rows keep the ticket's own number (`AC-1`, `AC-2`); a `--full` row uses its
  Scenario name as the label (`AC-"Export happy path"`), numbered in order.
- Field rows are `F-<field name>`; Edge rows keep their number (`E-1`, `E-2`).
- A spec or pasted text with no keys: each story-sized item is `SPEC-<n>`, and
  its rows are numbered in reading order.

Skip: tickets in a Done status are **kept** (UAT usually runs on Done work);
sub-tasks of a ticket already in the list are folded into the parent; Epics in a
list are expanded once (never twice when a child is also listed). Bugs are
tested only against their own "Expected" line, as one positive case plus one
regression case.

## Testable (step 2)

An AC row is **testable** when a tester can set up the Given, do the When, and
decide Yes/No on the Then without asking anyone. It is **not testable** when:

| Problem | Example | Reason written under "Cannot test yet" |
|---------|---------|----------------------------------------|
| No observable outcome | "Then the export works" | No observable result to check |
| Vague word | "loads fast", "user-friendly" | "fast" has no number |
| Missing number or rule | "Then large files are refused" | Size limit not stated |
| Contradiction | AC-2 says Viewers can export, Notes say Admin only | AC-2 contradicts the BE note |
| Outcome depends on an open question | "per the policy in Open question #2" | Waits on Open question #2 |

Rules:

- Never fill the gap with a plausible value. The row goes under **Cannot test
  yet** with the reason, and the report says `Run /ba-story-verify <KEY>`.
- When only a **boundary** is missing (the AC is testable, but the field has no
  max length), ask the operator a decision-shaped question, e.g.
  "DPD-901 Note field has no max length. (a) 500 characters (b) 2,000
  characters (c) no limit — skip the max boundary case (d) leave it — list
  under Cannot test yet". Up to 4 questions per round. Fold the answer in as a
  stated assumption on the case (`Assumes max 500, confirmed by operator`).
- A ticket where every AC row is untestable produces no cases at all.

## Generating cases (step 3)

### Minimums per ticket

| Source | Cases required | Type |
|--------|----------------|------|
| Each testable AC row | ≥ 1 that walks the row exactly | positive |
| Each Fields row with rules | min, max, just below min, just above max, empty (when required), wrong format (when a format is stated) | edge (in-range) / negative (out of range, empty, wrong format) |
| Each Edge & error row | 1 that triggers it and checks the stated expected result | negative |
| Each role the ticket names | 1 allowed role succeeds, 1 disallowed role is refused or does not see it | permission |

Only generate a boundary the rule implies: a field with "max 50 characters" and
no minimum gets max (50), just above (51), empty (if required), and nothing for
"min". Optional fields get an "empty → accepted, default applied" positive case
instead of the "empty → refused" negative one. Uniqueness rules get a duplicate
case. Allowed-values lists get one case per value only when there are 5 or
fewer; otherwise first, last and one outside the list.

### Writing a case

- **Title**: what is checked, short: "Export 50,000 rows (max)".
- **Traces to**: `AC-1`, `F-Email (max)`, `E-2`, or `Role: Viewer`.
- **Preconditions**: the state before step 1 (logged in as whom, which data
  exists). Concrete: "120 transactions dated 2026-09 exist for Org Alpha".
- **Steps**: numbered, one action each, in the ticket's words for screens and
  buttons. API-only stories may name the call in steps (QA artifact only).
- **Test data**: concrete values, and for boundaries the exact length or count
  (`a` × 50 = 50 characters, `a` × 51 = 51 characters).
- **Expected result**: copied from the ticket's Then / Expected / Rules, never
  embellished. If the ticket names the message text, quote it.
- **Type**: `positive`, `negative`, `edge` or `permission`.

Numbering: `TC-<KEY>-<n>`, n starting at 1 per ticket, in this order: AC
positives, field boundaries, edge/error negatives, permissions. Once a set is
saved, IDs are **never renumbered** (see `publish.md`, Refresh).

### UAT checklist items

From the same rows, but only what a business user can see and judge:

- One item per AC row (positive), plus the edge cases a user would hit
  (empty list, over-limit message, no permission). Skip pure field-format
  boundaries unless the user types the value themselves and sees a message.
- Group items by **user flow**, not by ticket: the order a real user goes
  through the work ("Invite a colleague", "Accept the invite", "Remove a
  member"). A flow may span several tickets; each item notes its ticket key in
  the last column for traceability.
- Write "what to do" and "what you should see" in plain words: "Click Export",
  "A file named transactions-<today>.csv downloads". No status codes, no dev
  tools, no database checks.

## Coverage (step 4)

One table per run, one row per ticket:

| Ticket | AC rows covered | Fields covered | Edge cases covered | Roles covered | Cannot test yet |
|--------|-----------------|----------------|--------------------|---------------|-----------------|
| DPD-901 | 3 / 3 | 2 / 2 | 3 / 3 | 2 / 2 | 0 |

- "Covered" means at least the minimum cases above exist for that row.
- Untestable rows count in the denominator and appear under Cannot test yet,
  so `2 / 3` + `1` in the last column is honest; never drop the row to make
  the ratio look complete.
- Any shortfall that is **not** a Cannot-test row is a generation miss: fix it
  in step 3 before showing.
