# Hygiene checks (step 3)

Eleven cheap checks, each computed from fields already fetched. They are
**signals**, not verdicts: a flagged ticket may be fine, and a clean ticket may
still fail `ba-story-verify`. Never score the 13 gates here.

## Finding shape

Every finding in `findings.json` carries:

```json
{
  "key": "DPD-117",
  "title": "Export filtered list",
  "check": "missing-ac",
  "severity": "blocker",
  "evidence": "Description is 2 lines, no AC field, no Given/When/Then",
  "action": "Ask the reporter to add acceptance criteria",
  "route": "ba-story-verify",
  "in_next_sprint": true,
  "age_days": 41
}
```

`severity` is fixed per check (below) and drives the Top 10 ranking. `route` is
one of `ba-story-verify`, `ba-ticket` (rewrite), `ba-epic-verify`, or `none`.

## The checks

| id | Severity | Detects | How | Suggested action | Route |
|----|----------|---------|-----|------------------|-------|
| `missing-ac` | blocker | No acceptance criteria | AC custom field empty (if the site has one) **and** the description has no AC-like section: no heading matching `acceptance`, `AC`, `done when`, `criteria`; no `Given ... When ... Then`; no checklist under such a heading | Ask the reporter to add AC | `ba-story-verify` |
| `thin-description` | blocker | Title-only or near-empty ticket | Description empty, or under 200 characters after stripping markup, or only restates the title. Bugs: also flag when there are no steps / expected / actual | Ask the reporter to describe the why and scope | `ba-ticket` (rewrite) |
| `possible-duplicate` | advisory | Two tickets that look like the same work | See "Duplicate matching" below | Link as `Duplicate` and ask the BA to confirm and close one | `none` |
| `stale` | advisory | Ticket nobody has touched | `updated` older than `--stale-days` (default 30) **and** status category To Do or In Progress | Ask the reporter whether it is still wanted | `none` |
| `stuck-in-progress` | blocker | In Progress for too long with no sign of work | Status category In Progress, `statuscategorychangedate` older than `--stale-days`, **and** no comment in that window **and** no commit/PR in the development summary (if the site exposes it; otherwise say "commit data not visible") | Ask the assignee for status or move it back | `none` |
| `no-epic` | advisory | Orphan story | Story with no `parent` (and no Epic Link). Tasks and Bugs are not flagged unless the project's Tasks mostly have parents (>= 70%) | Ask the reporter which Epic it belongs to | `ba-epic-verify` (on the likely Epic, if one is named) |
| `broken-link` | blocker | Links that no longer mean anything | An `is blocked by` link whose target is in status category Done; a link whose target cannot be read (deleted or no permission: say which is unknown) | Remove the stale blocker or confirm it | `none` |
| `unestimated` | blocker | Not sized but planned | In the next sprint (or the `--sprint` scope) with an empty points field. Only when the project uses points (see conventions); otherwise `n-a: project does not use story points` | Ask the team to estimate in refinement | `none` |
| `no-assignee-in-sprint` | advisory | Planned work with no owner | In an active or future sprint with no assignee | Ask the lead to assign | `none` |
| `oversized` | blocker | Likely more than one sprint of work | Any two of: description over 6,000 characters; more than 12 AC rows/bullets; 3+ separate AC groups or "Part 1/Part 2" headings; 3+ distinct deliverables in Scope; points above the project's 90th percentile | Split it | `ba-story-verify` (its `invest-sizing` gate) |
| `label-hygiene` | advisory | An outlier against the project's own convention | For each issue type, if at least 80% of scanned issues carry a label (or component), flag the ones that carry none. Below 80% the check is `n-a: no consistent convention`. Name the most common values as the suggestion | Add the expected label / component | `none` |

### Severity

- **blocker**: blocks refinement or planning as-is (cannot test, cannot plan,
  misleading dependency, nobody working on it).
- **advisory**: housekeeping; worth fixing, never a hold.

## Duplicate matching

Compare every pair within scope (and only within scope) by:

1. **Title similarity**: normalize (lowercase, strip `[Area]`/`[Team]` prefixes,
   punctuation, stop words), then token Jaccard >= 0.7, or one title contained in
   the other with at least 4 shared tokens.
2. **Description confirmation**: for title matches, check whether the first 500
   characters of the descriptions share the same key nouns (screens, entities,
   actions). A title match with clearly different descriptions is dropped.

Report each pair once with the match reason and **both quotes**:

```
DPD-140 "Export transactions to CSV"  <->  DPD-188 "CSV export for transaction list"
reason: title tokens {export, transaction, csv} overlap 0.75; both descriptions
name the transaction list filters.
```

Never decide which one survives, and never mark a pair whose tickets are already
linked to each other (any link type) as a new finding.

## Checks that do not apply

A check that cannot run (no AC field and the project writes AC elsewhere, no
points, no labels convention, no future sprint) is reported once in the header
as `n-a` with the reason. It produces no findings and is never shown as zero
problems.

## Routing, not re-checking

The scan stops at "this looks thin / has no AC / looks too big". The deep
question ("which AC are missing, how to split it") belongs to:

| Finding set | Hand to |
|-------------|---------|
| `missing-ac`, `oversized` | `/ba-story-verify <keys>` |
| `thin-description` | `/ba-ticket <KEY>` (rewrite into the short format, on approval) |
| Many `no-epic` stories that name the same Epic, or an Epic whose children are mostly flagged | `/ba-epic-verify <EPIC>` |
