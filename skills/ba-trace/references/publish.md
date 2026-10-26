# HTML and Confluence (steps 4-5)

## `--html`

Render `trace.md` into one self-contained file,
`.claude/state/ba-trace/<slug>/trace.html`:

- No external scripts, fonts or stylesheets; all CSS inline in a `<style>` block.
- Sections in the same order as `trace.md`: evidence sources, coverage, matrix,
  gaps, orphans, next actions.
- Coverage as plain numbers with a thin bar per metric; an `n/a` metric shows the
  reason text, never an empty bar.
- Matrix as a table with a sticky header; empty cells show "—", `n/a` cells are
  greyed. Gap rows link (anchor) to their matrix row.
- Ticket keys link to `https://<site>/browse/<KEY>` when the site is known.
- Light and dark via `prefers-color-scheme`. Readable at phone width (the matrix
  scrolls horizontally inside its own container, not the page).

Writing a local file is not an external write and needs no approval.

## `--confluence <url>`

The only external write in this skill. Skipped entirely with `--draft-only`.

1. **Resolve the page.** `getConfluencePage` on the URL's page id. If the URL is
   a space or parent page, the report becomes a new child page titled
   `Traceability: <scope title>`.
2. **Skip if unchanged.** Read `.claude/state/ba-trace/<slug>/published.json`.
   If the last publish to this page has the same content hash as the current
   `trace.md`, say "already published, nothing changed" and stop.
3. **Show and ask.** Show the page title, target (update page X v<n> / create a
   child of Y) and the full body, then `AskUserQuestion`:
   - **Publish** (update page / create page)
   - **Cancel** — keep the local report only

   If `AskUserQuestion` is unavailable, print the question and stop.
4. **Re-check.** Right before writing, re-read the page; if `version.number`
   moved since step 1, stop, re-show the target and ask again. Never overwrite
   edits you have not seen.
5. **Write.** Updating: back up the current body to
   `backup/page-<id>-v<n>.md`, then `updateConfluencePage` with
   `version.number + 1`. Creating: `createConfluencePage` under the parent.
6. **Log.** Append to `published.json`:
   `{"page_id": "...", "version": 19, "content_hash": "<sha256 of trace.md>", "at": "<utc>", "url": "..."}`.

Updating a page replaces its body with the report. If the page has other content
the operator wants kept, they choose **Cancel** and point at a dedicated page.

On failure: keep the local files, report the error and the local paths, stop.
