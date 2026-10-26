# Scope and fetch (steps 1-2)

## Resolving the scope

Exactly one scope wins, in this order. Flags combine only where noted.

| Flag | JQL built | Notes |
|------|-----------|-------|
| `--jql "<q>"` | `<q>` + ` AND statusCategory != Done` unless `<q>` already names `status` / `statusCategory` / `resolution` | Used as given otherwise. `--project` is ignored |
| `--epic KEY` | `parent = KEY AND statusCategory != Done` | Older company-managed projects may use `"Epic Link" = KEY`; if `parent` returns 0 and the Epic has children, retry with it and say so |
| `--sprint next` | `project = P AND sprint in futureSprints() AND statusCategory != Done` | Needs `--project` (or ask). If several future sprints exist, take the one with the earliest start date and name it |
| `--sprint active` | `project = P AND sprint in openSprints() AND statusCategory != Done` | Several active sprints (parallel boards) -> ask which |
| `--sprint "<name>"` | `project = P AND sprint = "<name>"` | No match or several matches -> ask |
| `--project P` (alone) | `project = P AND statusCategory != Done AND issuetype in (Story, Task, Bug) ORDER BY Rank ASC` | The backlog default |
| none | ask for the project | Offer `getVisibleJiraProjects` results; never guess |

A board's backlog URL (`.../boards/<id>/backlog`) maps to `--project` of the
board's project; if that is ambiguous, ask.

Default issue types are Story, Task, Bug. Sub-tasks and Epics are excluded from
scanning (Epics are still read as parents for `no-epic`). If the project renames
"Story", check `getJiraProjectIssueTypesMetadata` and use the level-0 types.

Always append `ORDER BY Rank ASC` when the JQL has no `ORDER BY`, so the cap
keeps the top of the backlog, not a random slice.

## Counting and the cap

1. Run the JQL with `maxResults: 1` and read the total.
2. `scanned = min(total, cap)` (default cap 200, `--cap N` to change).
3. Print before scanning: `project = DPD AND ...: 342 matching, scanning 200 (cap 200)`.
4. When capped, the report header repeats it and the Top 10 notes that tickets
   below rank 200 were not scanned.

## Fields to request

Request only these (names vary per site; resolve custom field ids once from
`getJiraIssueTypeMetaWithFields` or the first issue with `view: full`):

```
summary, description, issuetype, status, statuscategorychangedate, created,
updated, assignee, reporter, priority, labels, components, parent,
issuelinks, sprint (customfield), story points (customfield),
acceptance criteria (customfield, if the site has one), comment (last only)
```

Do not request attachments, worklogs, or the full changelog. For
`stuck-in-progress` only, fetch the last comment date and, if the site exposes
it, the development summary on that one issue.

## Detecting conventions (once per run)

| Convention | How | Used by |
|------------|-----|---------|
| Story points | A points field exists on the Story screen **and** at least 50% of issues resolved in the last 90 days have a value (one extra JQL: `project = P AND resolved >= -90d`, fields: points only, cap 100) | `unestimated` |
| AC field | A custom field named like "Acceptance Criteria" exists on the issue type | `missing-ac` |
| Labels / components | Share of scanned issues that carry at least one label / component; per issue type | `label-hygiene` |
| Next sprint | `futureSprints()` returns at least one sprint for the project | `unestimated`, ranking |
| Done-like statuses | `statusCategory = Done` (never a hard-coded name list) | `broken-link` |

Write the detected conventions into `findings.json` under `conventions` and
print them in the report header so the operator can disagree.

## Paging and fan-out

- `searchJiraIssuesUsingJql` pages of 50 (or the site maximum).
- **<= 100 issues:** fetch in context.
- **> 100 issues:** fan out with `Task`, one read-only sub-agent per page range
  (e.g. 4 x 50). Each returns the raw issue fields plus the per-issue checks
  (everything except `possible-duplicate` and `label-hygiene`). The lead merges
  them and runs the two cross-issue checks itself, because they need the whole
  set. Sub-agents never write to JIRA or to state.

## State layout

```
.claude/state/ba-backlog/<slug>/findings.json    # scope, counts, conventions, findings[]
.claude/state/ba-backlog/<slug>/report.md        # the terminal report
.claude/state/ba-backlog/<slug>/report.html      # --html only
.claude/state/ba-backlog/<slug>/applied.json     # writes made in step 5
```

`<slug>` = the scope lowercased: `dpd`, `dpd-sprint-next`, `dpd-832`,
`jql-<first 8 chars of sha1 of the JQL>`. A re-run with the same scope reuses
the folder (overwrites findings and report, keeps applied.json). `--dry-run`
writes none of these.
