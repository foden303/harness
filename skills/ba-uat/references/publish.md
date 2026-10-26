# Save, refresh, CSV, publish (steps 5-6)

## Save (step 5)

```
.claude/state/ba-uat/<slug>/test-cases.md       # QA cases + coverage + cannot-test
.claude/state/ba-uat/<slug>/uat-checklist.md    # business checklist + sign-off
.claude/state/ba-uat/<slug>/test-cases.csv      # only with --csv
.claude/state/ba-uat/<slug>/published.md        # what was sent externally (step 6)
.claude/state/ba-uat/<slug>/history/<date>-test-cases.md   # previous set, kept on --refresh
```

`<slug>`: a single key → the key lowercased (`dpd-901`); an Epic → the Epic key
(`dpd-832`); a list → the first key + count (`dpd-901-3`); `--jql` → `jql-<n>`
(n = ticket count); a spec → its title in kebab-case.

HTML comments from the templates are stripped. `--only qa` writes only
`test-cases.md`; `--only uat` only `uat-checklist.md`. `--dry-run` shows the
artifacts and writes nothing. `--draft-only` saves and prints the paths, then
stops before step 6.

**Re-run without `--refresh`:** the saved files exist → reload and show them;
do not regenerate. Offer step 6 for whatever `published.md` says is not sent.

## Refresh (`--refresh`)

Used after a requirement change (`ba-change`) or when tickets were edited.

1. Re-read every ticket in the saved set (plus any new child of a saved Epic).
2. Regenerate cases, then match each new case to a saved one by **Traces to +
   Type + Title intent**. A match keeps its saved ID.
3. Show the diff before saving:

   | Change | ID | Traces to | What changed |
   | --- | --- | --- | --- |
   | Added | TC-DPD-901-12 | F-Note (max) | New rule: Note max 500 characters |
   | Changed | TC-DPD-901-3 | AC-3 | Expected: "Export button hidden" → "Export button disabled with tooltip" |
   | Removed | TC-DPD-901-7 | E-2 | Edge case E-2 deleted from the ticket |

4. IDs are **never renumbered or reused**. Added cases take the next free `n`
   for that ticket; removed cases are dropped from the table and listed under
   a `## Removed in refresh <date>` section so QA can retire them.
5. Move the old file to `history/` and save the new one. The UAT checklist is
   regenerated in full (it has no stable IDs) and its diff is summarized in one
   line per flow.
6. If cases were already published, step 6 offers **update the page** and a
   short **"cases updated"** comment per changed ticket — never a full re-post.

## CSV (`--csv`)

One row per case, UTF-8 with a header, RFC 4180 quoting (fields with commas,
quotes or newlines are double-quoted; inner quotes doubled). Steps are joined
with a newline inside the quoted field.

```
ID,Ticket,Title,Traces to,Type,Preconditions,Steps,Test data,Expected result
TC-DPD-901-1,DPD-901,Export 120 filtered rows,AC-1,positive,"Logged in as Finance; 120 Sept transactions exist","1. Open Transactions
2. Filter Month = September 2026
3. Click Export",Month = September 2026,"A CSV with 120 rows and the list's columns downloads"
```

No columns beyond these; a test tool that needs others maps them on import.

## Approve (step 6)

Show the coverage table, the Cannot-test list, and both artifacts (or their
paths if long), then ask once with `AskUserQuestion`:

- **Publish to Confluence** (needs `--confluence <parent url>`, else ask for it)
- **Comment on each ticket** (one comment per ticket with its case IDs)
- **Both**
- **Edit first** (revise, re-check coverage, show again)
- **Cancel** (nothing leaves this machine)

If `AskUserQuestion` is unavailable, print the question and stop. Never publish
without an answer. MCP not-configured / unreachable → skip the question, keep
the files, say where they are.

## Publish

### Confluence page

1. `getConfluencePage` on the `--confluence` URL to get its space and id (it is
   the **parent**).
2. First publish: `createConfluencePage` (spaceId, parentId, title
   `Test cases & UAT — <run title>`, body = `test-cases.md` then
   `uat-checklist.md`, contentFormat markdown). With `--only`, only that part.
3. Already published (`published.md` has a page id): `getConfluencePage`; if its
   version is newer than the one recorded, show what changed and ask before
   overwriting. Then `updateConfluencePage` with the new body.
4. Record page id, URL and version in `published.md` immediately.

### Ticket comments

One comment per ticket, only for tickets with at least one case:

```
QA test cases for this story are ready (<n> cases: <p> positive, <g> negative,
<e> edge, <r> permission).
Page: <confluence url, if published>
Cases: TC-DPD-901-1 Export 120 filtered rows · TC-DPD-901-2 ...
Cannot test yet: AC-4 (size limit not stated) — see /ba-story-verify.
```

Post with `addCommentToJiraIssue`. Write the comment id into `published.md`
after each post. A ticket already commented gets no second full comment; on
`--refresh` it may get a short "cases updated: added X, changed Y, removed Z".

### published.md

```markdown
| Target | Id | URL | Version / date |
| --- | --- | --- | --- |
| Confluence page | 884213 | https://<site>/wiki/.../884213 | v3 · 2026-10-26 |
| Comment DPD-901 | 10452 | https://<site>/browse/DPD-901 | 2026-10-26 |
```

## If something fails

Stop at the first failure. Everything already sent is in `published.md`; the
report lists what is left, so a re-run sends only the missing parts.
The skill never transitions, assigns, or labels tickets.
