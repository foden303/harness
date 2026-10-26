# Save, approve, publish (step 6)

## Save

```
.claude/state/ba-release-notes/<slug>/notes.md          # the rendered notes
.claude/state/ba-release-notes/<slug>/items.md          # every issue: key, bucket, line, or why internal / dropped
.claude/state/ba-release-notes/<slug>/published.md      # Confluence page id, URL, version (after publish)
```

`<slug>`: `--version 2.4` → `<project>-v2-4`; `--sprint "DPD Sprint 42"` →
`dpd-sprint-42`; dates → `<project>-<from>-to-<to>`; `--jql` →
`jql-<n>` (n = issue count). Lowercase, kebab-case.

`items.md` is the audit trail: one table row per collected issue
(`Key | Type | Bucket | Note line or reason`), plus the questions asked and the
answers. A re-run reloads it and does not re-ask questions already answered;
new issues found by the query are classified and asked about fresh.

Each audience is a separate file when more than one is rendered:
`notes.md` (client), `notes-support.md`, `notes-internal.md`.

`--dry-run` shows the notes and writes nothing. `--draft-only` saves, prints
the paths, and stops.

## Approve

Show the final notes, then ask once with `AskUserQuestion`:

- **Publish to Confluence** (needs `--confluence <parent url>`, else ask for it)
- **Edit first** (revise, show again)
- **Cancel** (keep the saved file, nothing is sent)

If `AskUserQuestion` is unavailable, print the question and stop. Never publish
without an answer. MCP not-configured / unreachable → skip the question, keep
the file, say where it is.

## Publish

1. `getConfluencePage` on `--confluence` to get its space and id (the parent).
2. First publish: `createConfluencePage` (spaceId, parentId, title
   `<Product> <version or sprint> — Release notes` (+ ` (Support)` /
   ` (Internal)` for those variants), body = notes markdown, contentFormat
   markdown).
3. Re-run with a page in `published.md`: `getConfluencePage`; if its version is
   newer than recorded, show what changed and ask before overwriting; then
   `updateConfluencePage`. Never create a second page for the same slug and
   audience.
4. Write page id, URL and version to `published.md` right after the call.

## Never

- Email, Slack, Teams or any chat post. The report ends with: "Saved, not
  sent — paste it into email or chat yourself if needed."
- Change JIRA: no comments, labels, transitions or fixVersion edits.
- Release, tag or bump versions (that is `harness-release`).
