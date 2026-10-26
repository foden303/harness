# Save, next step, publish (steps 5-6)

## Save

```
.claude/state/ba-discovery/<slug>/sources.md     # the source list from step 1
.claude/state/ba-discovery/<slug>/answers.md     # every question asked + the answer, with date
.claude/state/ba-discovery/<slug>/brief.md       # the rendered brief
.claude/state/ba-discovery/<slug>/published.md   # page URL + version, only after a publish
```

- `--dry-run`: write nothing; print the brief in the reply instead.
- `--draft-only`: write the files, never call Confluence.
- **Re-run** with the same slug: read `answers.md` first and never ask a
  question it already answers; read `sources.md` and note new or changed
  sources ("2 new files since the last run"); re-render `brief.md` and keep
  the R-n / C-n / Q-n numbers of existing rows stable (new rows get the next
  number). If `published.md` exists, never create a second page.

## Choosing the next skill

| Signal in the brief | Recommend |
|---------------------|-----------|
| More than about 8 functional requirements, or several user roles with different flows | `ba-spec` |
| Business rules or data that several teams must agree on before tickets | `ba-spec` |
| Integrations, migration, or rollout risk among the constraints | `ba-spec` |
| A single user-visible change, 1-3 stories | `ba-ticket` (story) |
| A feature with a few clear slices and no shared rules to settle | `ba-ticket --epic` |

Give the exact command with the saved path and the project:

```
/ba-spec .claude/state/ba-discovery/dpd-self-serve-reporting/brief.md --confluence https://<site>/wiki/spaces/DPD
/ba-ticket .claude/state/ba-discovery/dpd-export-csv/brief.md --project DPD
/ba-ticket .claude/state/ba-discovery/dpd-self-serve-reporting/brief.md --epic --project DPD
```

If open questions block the next step (a `Blocks` cell names it), say so and
recommend waiting for those owners first, still giving the command.

## Publish to Confluence (optional)

Only when `--confluence <parent page url>` is given and neither `--draft-only`
nor `--dry-run` is set, and the probe was `healthy`.

1. Resolve `cloudId` with `getAccessibleAtlassianResources`; read the parent
   page with `getConfluencePage` to get its space and id.
2. Show the final page title (`Discovery brief: <topic>`) and body, then ask
   once with `AskUserQuestion`:
   - Publish under <parent title>
   - Edit first (revise, show again)
   - Skip (keep the local brief only)

   If `AskUserQuestion` is unavailable, print the question and stop.
3. On approval: `createConfluencePage` (cloudId, spaceId, parentId, title,
   body as markdown). Write the returned URL and version to `published.md`
   immediately.
4. Re-run with `published.md` present: offer **Update the existing page** /
   **Skip**. Before updating, re-read the page; if its version changed since
   `published.md` was written, stop, show what changed, and re-draft. Never
   overwrite edits you have not seen. Update with `updateConfluencePage` only
   after approval.

A title clash under the parent → offer to append the date to the title; never
overwrite the other page.

MCP not-configured / unreachable at this step: keep the saved brief, give its
path, and say the publish was skipped and why.
