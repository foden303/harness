# Create in JIRA (step 5)

Creating an issue notifies people and takes a key, so it happens **only** after
the operator approves.

## Save first

Write the final markdown (HTML comments stripped) before asking:

```
.claude/state/ba-ticket/<slug>/epic.md          # epic mode
.claude/state/ba-ticket/<slug>/story-<n>.md     # one per story
.claude/state/ba-ticket/<slug>/created.json     # keys created so far
```

`<slug>` is the title in kebab-case. `created.json` maps each file to its key,
e.g. `{"epic.md": "DPD-900", "story-1.md": "DPD-901"}`. A re-run reads it and
never re-creates a file that already has a key.

`--draft-only` stops after saving and prints the paths.

## Approve

Show the final text, then ask once with `AskUserQuestion`:

- Create all (epic + N stories) / Create this story
- Let me pick which stories (then a multi-select of story titles)
- Edit first (revise, re-check, show again)
- Cancel (nothing is written to JIRA)

If `AskUserQuestion` is unavailable, print the question and stop. Never create
without an answer.

## Create

1. Resolve the site: `getAccessibleAtlassianResources` → `cloudId`. Check the
   issue type exists in the project with `getJiraProjectIssueTypesMetadata`
   (some projects rename "Epic"; use the hierarchy-level-1 type and say so).
2. Epic first:

   ```
   createJiraIssue  cloudId, projectKey, issueTypeName: "Epic",
                    summary: <title>, description: <markdown>, contentFormat: "markdown"
   ```

3. Each approved story, with `parent` set to the new epic key (or `--epic-key`):

   ```
   createJiraIssue  cloudId, projectKey, issueTypeName: "Story",
                    summary: <title>, description: <markdown>, contentFormat: "markdown",
                    parent: <epic key>
   ```

   If the project rejects `parent`, link with `createIssueLink` instead and say so.

4. After each create, write the key into `created.json` immediately.
5. Epic mode: update the epic's **Stories** table with the real keys via
   `editJiraIssue`.

## Rewrite mode: update an existing ticket

When the input was an issue key, the ticket already exists: update it instead of
creating a new one.

1. Save the current JIRA description to
   `.claude/state/ba-ticket/<slug>/original-<KEY>.md` before anything else, so
   the old text can be restored.
2. Show the new title + description and ask once: **Update <KEY>** / **Edit
   first** / **Cancel**. If the rewrite suggests splitting the ticket, offer
   **Split** too (update this ticket with the first part, create the rest as new
   stories under the same epic, each only after the same approval).
3. Right before writing, re-read the ticket's `updated` time. If it changed
   since step 1, stop and re-draft; never overwrite edits you have not seen.
4. On approval:

   ```
   editJiraIssue  cloudId, issueIdOrKey: <KEY>,
                  fields: { summary: <new title>, description: <markdown> },
                  contentFormat: "markdown"
   ```

5. Only the summary and description change. Status, assignee, parent, labels
   and links stay as they are.

## JIRA markdown pitfalls

JIRA converts the markdown on write, and two patterns lose text:

| Written | JIRA shows | Write instead |
|---------|-----------|---------------|
| A table cell starting `403. Refused` | `Refused` (the "403." is read as a list number) | `Refused (403).` |
| `**bold with `code` inside**` | Bold ends early | Bold a plain lead-in only: `**The rule:** ... `code`` |

After each write, check the returned description for these before reporting done.

## If something fails

Stop at the first failure. Report which keys were created and which files are
still waiting, so a re-run creates only the missing ones.

## After

Issues land in the project's default status. The skill does not transition,
assign, or estimate them. End by listing every created key + URL.
