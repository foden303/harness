# Output targets (Steps 2, 8-9)

One document, two destinations. The destination is chosen by whether
`--confluence <url>` was passed — never asked twice, never inferred mid-run.

| `--confluence` | `target` | Where the document goes |
|---|---|---|
| given | `confluence` | A child page under the given page |
| absent | `folder` | `.md` + `.mapping.json` under `--out` (default `./ocsf-mappings/`) |

## Resolving a Confluence target (Step 2)

Resolve the link **before** any mapping work:

```
mcp__claude_ai_Atlassian_Rovo__getConfluencePage
```

A bad link, a page in a space the operator cannot write to, or a typo'd id should
cost the operator ten seconds at the start — not a full mapping run followed by a
failed publish. Record `space_key`, `page_id` and `title` in the draft.

Reading the target page is a **read** — it needs no approval. Only
`createConfluencePage` in Step 9 does.

## Document structure

Identical in both destinations, so a folder-written mapping can be pasted into
Confluence later without reshaping.

```markdown
# OCSF Mapping — <source_name> → <class caption> (OCSF <version>)

**Source:** <source_name> · **OCSF class:** <caption> (<uid>) · **Schema pin:** <version> · **Samples:** <n> records across <n> source(s) · **Coverage:** <mapped>/<inventory> fields

## Summary
## Input profile
## Mapping
## Required attributes not covered
## Unmapped raw fields
## Enum & value mappings
## Open questions
## Reproducing this mapping
```

### Summary

Two or three sentences: what this source is, why this OCSF class, and the one
thing an implementer would otherwise get wrong (a timestamp unit, an enum gap, a
field whose name lies about its content). Not a restatement of the title.

### Input profile

| Source | Format | Lines | Parsed | Rate |
|---|---|---|---|---|

Followed by one line stating whether the file was read whole or sampled, and the
sample-size limitation when `samples-sufficient` is thin.

### Mapping

The core table. One row per mapped field:

| Raw field | Sample value | OCSF attribute | OCSF type | Transform | Confidence | Seen |
|---|---|---|---|---|---|---|

`Sample value` is not decoration — it is what lets a reviewer catch a
same-name-different-meaning mapping in one pass. Redact the value of a
PII-flagged field to its shape (`a***@example.com`, `10.x.x.x`) rather than
dropping the column: a redacted shape still shows what kind of thing it is, and a
published Confluence page is wider-read than the log file was.

### Required attributes not covered

| OCSF attribute | Why no raw field supplies it | Fallback |
|---|---|---|

An empty table here is a strong result — say "none" explicitly rather than
omitting the section, so a reader can tell it was checked.

### Unmapped raw fields

| Raw field | Sample value | Disposition | Why |
|---|---|---|---|

`unmapped` (no home found yet) / `extension` (carried in `unmapped`/enrichments) /
`dropped` (deliberately discarded). A `dropped` row without a reason is data loss
with no audit trail.

### Enum & value mappings

Per enum attribute: the value map, then the leftovers.

| Raw value | OCSF value | |
|---|---|---|

Followed by **Unmapped values:** the explicit list. This list is the most useful
part of the document for whoever writes the alerting rules — it is the set of
events that will not classify.

### Open questions

The unanswered `open_questions[]`, with gate and why. Present even when empty
("none — every gate answered"), so a reader knows the absence is a result.

### Reproducing this mapping

The pin version, the pin's `fetched_at`, the source refs with their `sha256`, and
the exact command. A mapping that cannot be re-derived cannot be reviewed a month
later.

## Publishing to Confluence (Step 9)

On approval only:

1. `createConfluencePage` with `parentId` = the resolved target page.
2. Title: `OCSF Mapping — <source_name> → <class caption>`. A stable title so a
   re-run is recognisable as an update to the same mapping rather than a new one.
3. Re-run the record helper with `--set-published` carrying the returned
   `page_id` and the page URL.

If a page with that title already exists under the target, say so and ask whether
to update it or create a sibling — silently creating a second page with the same
title is how two contradictory mappings end up in a space.

## Writing to a folder

On approval only, into `<out_dir>/`:

| File | Contents |
|---|---|
| `<source_name>.md` | The rendered document above |
| `<source_name>.mapping.json` | The `ocsf-mapping.v1` record itself |

Both together, always. The `.md` is for humans; the `.json` is what a normalizer
generator or a drift check reads. Shipping only the `.md` means the machine-usable
form has to be re-derived by hand, and it will drift.

Create `<out_dir>` if absent. Do not overwrite an existing `<source_name>.md`
without saying so — report that it exists, show what changed, and let the operator
decide.
