# Report (step 4)

Lead with the line that answers "is this backlog ready for refinement?", then
the counts, the Top 10, and one table per check. The operator decides what to
act on while looking at this, before any action is offered.

## Layout

```markdown
# Backlog hygiene: <scope>

<scope> — <M> scanned of <N> matching (cap <C>). <F> findings on <T> tickets;
<B> tickets have at least one blocker finding.

JQL: `<the JQL>`
Conventions: story points <yes (customfield_10016, 84% of resolved) | no>;
labels <yes on Story (91%) | no consistent convention>; components <...>;
next sprint <"Sprint 42" starts 2026-10-29 | none>.
Not run: <check: reason>, ...

## Counts

| Check | Severity | Tickets |
| --- | --- | --- |
| missing-ac | blocker | 9 |
| ... | ... | ... |

## Top 10 to fix before refinement

| # | Key | Title | Why it is here | Fix with |
| --- | --- | --- | --- | --- |
| 1 | DPD-117 | Export filtered list | next sprint; missing-ac, unestimated | /ba-story-verify |

## <check id> (<count>)

| Key | Title | Finding | Suggested action | Skill to run |
| --- | --- | --- | --- | --- |
| DPD-117 | Export filtered list | No AC field, no Given/When/Then | Ask the reporter to add AC | ba-story-verify |
```

Repeat the last section for every check with findings, in the Counts order.
Checks with zero findings are listed in Counts as `0` and get no table.

## Ranking the Top 10

Sort tickets (not findings) by, in order:

1. **In the next sprint** (or in the `--sprint` scope) first.
2. **Number of blocker findings**, most first.
3. **Blocker-ish checks** in this order when tied: `missing-ac`,
   `stuck-in-progress`, `broken-link`, `oversized`, `thin-description`,
   `unestimated`.
4. **Age** (`created`), oldest first.

A ticket with only advisory findings can still enter the Top 10 when there are
fewer than 10 tickets with blockers. When the scan was capped, add one line
under the table: "Only the top <C> tickets by rank were scanned."

## Possible duplicates table

The `possible-duplicate` table has its own columns because it is about pairs:

```markdown
| Ticket A | Ticket B | Why they match | Suggested action |
| --- | --- | --- | --- |
| DPD-140 "Export transactions to CSV" | DPD-188 "CSV export for transaction list" | title overlap 0.75; same list + filters | Link as Duplicate; BA confirms and closes one |
```

## Writing rules

- Quote evidence, do not paraphrase it ("description is 1 line: 'see Figma'").
- One finding = one row; a ticket with three findings appears in three tables
  and once in the Top 10.
- No scores, no percentages per ticket, no gate ids from `ba-story-verify`.
- Ticket titles are truncated to 60 characters in tables.

## HTML (`--html`)

Write `.claude/state/ba-backlog/<slug>/report.html` as **one self-contained
file** (inline CSS, no external scripts or fonts) with the same sections as the
markdown. Use the Write tool directly; do not add a renderer template.

- Keys link to `https://<site>/browse/<KEY>`.
- Light and dark via `prefers-color-scheme`; tables scroll horizontally on
  narrow screens.
- A small summary bar at the top: scanned / matching / findings / blocker
  tickets.

If the host project has `.claude/rules/client-redaction.yaml`, run the HTML
through `${HARNESS_PLUGIN_ROOT}/scripts/redact-by-dictionary.sh` before it is
shared. The terminal report stays unredacted.

Under `--dry-run` the HTML is not written; say so.
