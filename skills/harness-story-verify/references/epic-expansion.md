# Expansion (Step 1)

Turn whatever the operator passed into an explicit, deduped list of ticket keys,
then freeze it into the batch cursor. Everything downstream works from that
list — expansion happens **once** per batch.

## Input forms

| Input | Detection | Expansion |
|-------|-----------|-----------|
| `PROJ-100` where issue type is Epic | `getJiraIssue` → `issuetype.name == "Epic"` (or the project's epic-level type) | Children (below) |
| `PROJ-123` any other type | `getJiraIssue` | Just that key |
| `https://<site>/browse/PROJ-123` | Regex `/browse/([A-Z][A-Z0-9_]+-\d+)` | Whatever the key resolves to |
| `PROJ-1 PROJ-2 PROJ-3` | Multiple refs | Exactly those three, **independent** |
| `--jql "<query>"` | Explicit | `searchJiraIssuesUsingJql` result set |

**Always fetch the ref before deciding.** Do not infer "this is an Epic" from
the key shape or the word "epic" in the title.

## Epic → children

Modern JIRA (team-managed and company-managed on the new hierarchy) links
children by `parent`. Older company-managed projects use the `Epic Link` custom
field. Try in order and stop at the first query that returns rows:

```
1. parent = PROJ-100 ORDER BY created ASC
2. "Epic Link" = PROJ-100 ORDER BY created ASC
```

via `mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql`. If both return
zero rows, **do not broaden the query** (no `text ~`, no project-wide sweep) —
report "Epic PROJ-100 has no linked children" and stop. A silent fallback to a
wider query is how the wrong tickets get commented on.

Request the fields you need in one pass so Step 2 does not re-fetch:
`summary, description, issuetype, status, parent, labels, reporter, assignee,
created, updated`, plus the project's acceptance-criteria custom field if it has
one (find it once via `getJiraIssueTypeMetaWithFields` and cache the field id in
the batch run).

## Filtering

Applied in this order, and every exclusion is reported with its reason:

1. **Deduplicate** by key, preserving first-seen order.
2. **Drop sub-tasks** of a child that is already in the list (the parent story is
   the unit of verification). A sub-task passed *directly* by the operator is
   kept.
3. **Drop done/closed** tickets (`statusCategory == Done`) unless
   `--include-done`. Verifying a shipped story produces questions nobody will
   answer.
4. **Keep everything else**, including Bugs and Tasks in an Epic — but note the
   type in the report, since several rubric gates come back `n-a` for a Bug.

If the filtered list is empty, report the counts (found / dropped, per reason)
and stop.

## Freezing the batch

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/story-verify-batch.sh" init \
  --batch-id proj-100 \
  --mode epic \
  --root PROJ-100 \
  --keys "PROJ-101,PROJ-102,PROJ-103" \
  --out .claude/state/story-verify/proj-100/batch.json
```

`init` is idempotent: re-running it on an existing batch **preserves each
ticket's current state** and only adds newly-found keys as `pending`. So
re-running `/harness-story-verify PROJ-100` after the BA has added two more
child stories verifies just the two new ones.

`--batch-id` derivation: root key lowercased (`PROJ-100` → `proj-100`); for a
bare ticket list, the first key; for `--jql`, `jql-<count>`.

## Reporting the expansion

Before any verification, tell the operator what is in scope — this is the last
cheap moment to correct the target:

```
Epic PROJ-100 "Q3 payments" → 7 child tickets
  in scope: PROJ-101..PROJ-107 (5 Story, 1 Task, 1 Bug)
  skipped:  PROJ-099 (status Done), PROJ-104-1 (sub-task of PROJ-104)
```

## Scale

| Tickets | Approach |
|---------|----------|
| 1-5 | Verify in-context, sequentially |
| 6+ | Fan out with `Task`: one read-only sub-agent per ticket, each returning a `story-verification.v1` draft. The orchestrator persists them through `story-verify-record.sh` — sub-agents do not write state and never post comments |
| 40+ | Verify the first 40 in key order, report explicitly that the batch was capped and how many remain, and offer `--jql` narrowing. Never silently truncate |
