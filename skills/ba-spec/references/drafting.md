# Drafting guide (steps 1, 2, 4, 6)

## Input (step 1)

| Input | Read | Carry into the spec |
|-------|------|---------------------|
| Discovery brief (`ba-discovery` output) | `Read` the file | Requirements R-n → Traceability; Business rules → BR-n; Decisions → rules or scope; Assumptions → Open questions unless confirmed; Conflicts still open → Open questions; Out of scope → Scope Out / Later; Stakeholders → personas and question owners |
| Idea text | The argument | Needs I-n quoted from the idea; expect most sections to be gaps |
| Existing page (`--page`) | `getConfluencePage` (body as markdown + version) | The current content is the draft; revise it into the template without losing content |

- `<slug>`: the brief's slug when the input is a brief, else the feature name
  in kebab-case (or the page title for `--page`). Say the slug.
- Revise mode: before anything else, write the current body and its version
  number to `.claude/state/ba-spec/<slug>/original.md`.
- Re-run: read `answers.md` and never ask what it already answers; reuse
  `spec.md` as the draft; if `published.md` exists, treat the run as revise
  mode on that page.

## Draft (step 2)

- Fill a section only from the input or a BA answer. Anything else is a gap.
- Rewrite brief requirements into testable rules: "only Finance can export"
  → `BR-1 When a user without the Finance or Support role opens the list, the
  Export action is not shown.`
- Each flow: start trigger, numbered steps, end state, error paths. A flow
  with no known error path is a gap ("What happens if the export times out?").
- Data: one row per field. Unknown Required / Rules is a gap, never a guess.
- Non-functional: include a row only when the input mentions it or a flow
  obviously needs it (an export with a row limit needs a performance row);
  when you include it without a number, it is a gap.
- Write the Traceability table last, from the brief's full R-n list.

## Asking (step 4)

- `AskUserQuestion`, **up to 4 questions per round**, grouped by section.
- Each question names the BR / F / field it fills and offers 2-4 ready-made
  options; the BA can type their own.
- Order: blocking rules and permissions first, then flows' error paths, then
  data rules, then non-functional numbers, then rollout.
- Never ask what the input already answers. If `AskUserQuestion` is
  unavailable, print the questions and stop.

Bad: "What are the business rules for export?"

Good: "BR-2: what is the most rows one export may contain? (a) 10,000,
(b) 50,000, (c) no limit, emailed when ready."

Good: "F-1 step 4: the export takes longer than 30 s. What does the user see?
(a) error with Retry, (b) the file is emailed when ready, (c) a progress bar
with no time limit."

Record every question and answer with the date in `answers.md`. Answers cite as
`BA answer, <date>` in the Source column. "Leave it" → Open question with an
owner (from the brief's stakeholders when known, else ask who owns it).

## Epics (step 6)

After publishing (or saving with `--draft-only`), propose the breakdown:

| # | Epic | Covers | Depends on |
| --- | --- | --- | --- |
| 1 | [Transactions] CSV export | F-1, BR-1, BR-2, §6 Export file | none |
| 2 | [Transactions] Export audit trail | BR-3, §6 Export record, §8 Audit | 1 |

- One epic per user-visible slice that can ship on its own; each BR and F is
  covered by exactly one epic (shared rules go to the first epic that needs
  them and the others depend on it).
- Epic titles follow `ba-ticket`: `[Area] ...`, no team tag.
- Open questions that block an epic are named on its row; recommend settling
  them before running `ba-ticket` for that epic.

Hand-off, one command per epic, pointing at the published page (or the saved
file with `--draft-only`) and naming the slice:

```
/ba-ticket https://<site>/wiki/spaces/DPD/pages/789 --epic --project DPD   # epic 1: CSV export (F-1, BR-1, BR-2)
/ba-ticket .claude/state/ba-spec/dpd-self-serve-reporting/spec.md --epic --project DPD   # draft-only
```

The skill proposes the breakdown only; it never creates JIRA issues itself.
