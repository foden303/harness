# Target list (Step 1)

Turn whatever the operator passed into an explicit, deduped list of **story-level
ticket keys**, then freeze it into the batch cursor. Everything downstream works
from that list — resolution happens **once** per batch.

## Input forms

| Input | Detection | Result |
|-------|-----------|--------|
| `PROJ-123` | `getJiraIssue` | Just that key |
| `https://<site>/browse/PROJ-123` | Regex `/browse/([A-Z][A-Z0-9_]+-\d+)` | Whatever the key resolves to |
| `PROJ-1 PROJ-2 PROJ-3` | Multiple refs | Exactly those three, **independent** |
| `--jql "<query>"` | Explicit | `searchJiraIssuesUsingJql` result set |
| `PROJ-100` where issue type is Epic | `getJiraIssue` → `issuetype.name == "Epic"` | **Route out** (below) |

**Always fetch the ref before deciding.** Do not infer the type from the key
shape or the word "epic" in the title.

## An Epic is not a target here

This skill scores **stories** against the user-story rubric. An Epic has no
acceptance criteria of its own, so those gates would fail for the wrong reasons.
When a passed ref resolves to an Epic, do not expand it and do not score it:

> PROJ-100 is an Epic. Run `/ba-epic-verify PROJ-100` — it scores the Epic
> itself (goal, definition of done, team split, critical path) and asks from the
> BE / FE / BA angles. It can then hand the children back here with
> `--with-children`.

Offer to run it, but do not silently switch skills. Two exceptions:

- **`--jql`** results are taken as given. If the query returns an Epic, verify
  what the operator asked for and note the type in the report — several rubric
  gates will come back `n-a`.
- **Explicit child list.** `ba-epic-verify --with-children` calls this skill
  with the already-expanded child keys, which is the supported way to verify an
  Epic's stories.

## Fetching

Request the fields you need in one pass so Step 2 does not re-fetch:
`summary, description, issuetype, status, parent, labels, reporter, assignee,
created, updated, comment`, plus the project's acceptance-criteria custom field
if it has one (find it once via `getJiraIssueTypeMetaWithFields` and cache the
field id in the batch run).

`reporter` matters beyond scoring: it is who gets @mentioned, and who the ticket
is assigned to by the handoff in Step 4. Capture `reporter_account_id`, or record
that the ticket has no reporter.

## Filtering

Applied in this order, and every exclusion is reported with its reason:

1. **Deduplicate** by key, preserving first-seen order.
2. **Drop sub-tasks** of a ticket already in the list (the parent story is the
   unit of verification). A sub-task passed *directly* by the operator is kept.
3. **Drop done/closed** tickets (`statusCategory == Done`) unless
   `--include-done`. Verifying a shipped story produces questions nobody will
   answer.
4. **Keep everything else**, including Bugs and Tasks — but note the type in the
   report, since several rubric gates come back `n-a` for a Bug.

If the filtered list is empty, report the counts (found / dropped, per reason)
and stop.

## Freezing the batch

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/story-verify-batch.sh" init \
  --batch-id proj-101 \
  --mode tickets \
  --root PROJ-101 \
  --keys "PROJ-101,PROJ-102,PROJ-103" \
  --out .claude/state/story-verify/proj-101/batch.json
```

`init` is idempotent: re-running it on an existing batch **preserves each
ticket's current state** and only adds newly-found keys as `pending`. So
re-running after the BA adds two more stories verifies just the two new ones.

`--batch-id` derivation: for a ticket list, the first key lowercased
(`PROJ-101` → `proj-101`); for `--jql`, `jql-<count>`. When called from
`ba-epic-verify --with-children`, the Epic key is passed as `--root` and the
mode stays `tickets`, so the batch is traceable back to its Epic.

## Reporting the target list

Before any verification, tell the operator what is in scope — this is the last
cheap moment to correct the target:

```
3 tickets in scope: PROJ-101, PROJ-102, PROJ-103 (2 Story, 1 Task)
  skipped: PROJ-099 (status Done), PROJ-104-1 (sub-task of PROJ-104)
```

## Scale

| Tickets | Approach |
|---------|----------|
| 1-5 | Verify in-context, sequentially |
| 6+ | Fan out with `Task`: one read-only sub-agent per ticket, each returning a `story-verification.v1` draft. The orchestrator persists them through `story-verify-record.sh` — sub-agents do not write state and never post comments |
| 40+ | Verify the first 40 in key order, report explicitly that the batch was capped and how many remain, and offer `--jql` narrowing. Never silently truncate |
