# Save, approve, publish (step 5)

## Save

```
.claude/state/ba-spec/<slug>/spec.md        # the rendered spec
.claude/state/ba-spec/<slug>/answers.md     # every question asked + the answer, with date
.claude/state/ba-spec/<slug>/original.md    # revise mode: page body + version before any change
.claude/state/ba-spec/<slug>/published.md   # page URL, page id, version after the last write
```

- `--dry-run`: write nothing; print the spec in the reply instead and stop.
- `--draft-only`: write the files, print the paths, never call Confluence;
  continue to step 6 with the local path.

## Target

| Given | Action |
|-------|--------|
| `--page <url>` | Revise that page (update) |
| `published.md` exists (re-run) | Revise the page it names (update); never create a second page |
| `--confluence <space url>` | New page at the space root |
| `--confluence <parent page url>` | New page under that parent |
| Nothing | Ask for a space or parent (offer `getConfluenceSpaces` results), or offer `--draft-only` |

## Approve

Show the final title (`<Feature name>: feature spec`) and the full body, plus
the readiness line. Then ask once with `AskUserQuestion`:

- Publish (create under <target>) / Update <page title>
- Edit first (revise, re-check, show again)
- Cancel (nothing is written to Confluence)

If `AskUserQuestion` is unavailable, print the question and stop. Never write
without an answer.

## Create

1. `getAccessibleAtlassianResources` → `cloudId`; resolve the space id (and the
   parent id) with `getConfluencePage` / `getConfluenceSpaces`.
2. `createConfluencePage` (cloudId, spaceId, parentId if any, title, body as
   markdown).
3. Write the returned URL, id and version to `published.md` immediately.

A title clash in the space → offer to append the project key or date; never
overwrite the other page.

## Update (revise mode)

1. `original.md` was written in step 1 (body + version). If it is missing,
   write it now from a fresh read before going on.
2. Right before writing, re-read the page with `getConfluencePage`. If its
   version is higher than the one in `original.md` / `published.md`, **stop**:
   show who changed it and a short summary of the difference, fold the new
   content into the draft, re-run the readiness check, and show again. Never
   overwrite edits you have not seen.
3. On approval: `updateConfluencePage` (cloudId, pageId, title, body as
   markdown, version = read version + 1).
4. Write the new version to `published.md`.

The page's comments, labels, parent and permissions are left as they are.

## If something fails

Stop at the first failure. Keep `spec.md`, report the error and the path, and
do not write `published.md`. A re-run reads the state and retries only the
write that failed.
