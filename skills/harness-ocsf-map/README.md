# harness-ocsf-map

Turn raw log samples into a reviewed OCSF field mapping document.

You give it log input — pasted lines, a file, or a directory to scan — and it
profiles the shape, picks an OCSF event class, maps every field against a
**pinned** OCSF schema, scores the result against a 12-gate rubric, asks you only
the questions the samples cannot answer, and publishes the mapping to Confluence
or writes it to a folder.

## Quick start

Run it with no arguments and it asks you the two things it needs, then works:

```
/harness-ocsf-map

  1. Where does the output go?   → a Confluence page link, or a folder name
  2. How is the log provided?    → paste the lines, one file, or a folder to scan

  ...profiles, maps, scores, self-reviews...

  → shows you the document, then asks: publish / edit first / cancel
```

Arguments just pre-answer those questions:

```bash
# Publish to Confluence as a child of the given page
/harness-ocsf-map azure-signin --confluence https://secuw.atlassian.net/wiki/spaces/platform/pages/123456/

# Write .md + .mapping.json into a folder
/harness-ocsf-map azure-signin --out ./ocsf-mappings/

# Ingest a directory directly, force the class
/harness-ocsf-map macos-unified --input ./samples/macos/ --class 3002
```

Anything you leave out is asked, not assumed — including the output folder name.
Whatever you give is validated before any work starts: a bad Confluence link or a
missing input file costs you ten seconds at the front, not a whole mapping run.

## First-time setup

The schema is a file in the repo, not a live fetch. Pin it once from
[`github.com/ocsf/ocsf-schema`](https://github.com/ocsf/ocsf-schema):

```bash
./scripts/ocsf-schema-pin.sh fetch --version 1.8.0
./scripts/ocsf-schema-pin.sh status --version 1.8.0 --json
```

Until that runs, the skill stops at Step 1 and tells you so. That is deliberate:
mapping against a half-remembered schema produces a document that looks right and
is not verifiable. See [`templates/ocsf/README.md`](../../templates/ocsf/README.md).

On a machine with no egress, fetch the tag elsewhere and install it with
`--from-file ./ocsf-schema-1.8.0.tar.gz` or `--from-dir ./ocsf-schema`.

## Arguments

| Argument | Meaning | Default |
|---|---|---|
| `<source name>` | Slug for the log source | Asked if absent |
| `--confluence <url>` | Publish under this page | Absent → folder output |
| `--out <dir>` | Folder for `.md` output | `./ocsf-mappings/` |
| `--input <path>` | File or directory to ingest without prompting | Asked interactively |
| `--class <name\|uid>` | Force the OCSF class | Proposed from evidence |
| `--ocsf-version <v>` | Which pinned schema to use | `1.8.0` |
| `--dry-run` | Render, never publish | off |

## The publish gate

Nothing is written until you approve, and the approval shows you four things
together:

1. **Exactly where it goes** — the literal file path, or the page title and its
   parent. Not "the output folder".
2. **The document content** — the rendered markdown itself. You are approving the
   content, so you see the content.
3. **The coverage summary** — mapped / unmapped / missing-required counts, plus
   any unanswered questions travelling with the document.
4. **The self-review result** — 8 checks run over the rendered document before you
   see it (row provenance, count agreement, section completeness, PII redaction,
   open questions carried, enum leftovers surfaced, reproducibility block,
   destination agreement), reported as findings or as "0 findings".

Then: **publish**, **edit first**, or **cancel**. Cancelling writes nothing and
keeps the draft for a later re-run.

## What it will not do

- **Invent a mapping.** Every mapped attribute carries the raw path and a sample
  value observed in your input. The record helper rejects an entry without one,
  so an invented mapping cannot be saved — only asked about.
- **Fetch the schema during a run.** `WebFetch` is absent from the skill's
  allowed-tools. Same samples in, same mapping out.
- **Assume where the output goes.** If you did not name a destination, it asks —
  it does not quietly pick a folder.
- **Hide what it could not map.** Unmapped raw fields, uncovered required
  attributes and unmapped enum values each get their own section, including when
  they are empty.
- **Leak PII into a published page.** Sample values for PII-flagged fields render
  as shapes, and the self-review checks it before you approve.

## Output

One document, either destination:

```
# OCSF Mapping — azure-signin → Authentication (OCSF 1.8.0)
## Summary
## Input profile              format, line counts, parse rate
## Mapping                    raw field | sample value | OCSF attribute | transform | confidence
## Required attributes not covered
## Unmapped raw fields
## Enum & value mappings      including the values with no OCSF equivalent
## Open questions
## Reproducing this mapping   pin version, source sha256s, the command
```

Folder mode also writes `<source>.mapping.json` — the `ocsf-mapping.v1` record —
next to the `.md`, so the machine-readable form never has to be re-derived by hand.

## Re-running

State lives at `.claude/state/ocsf-map/<source-name>/draft.json` and is written
only by `scripts/ocsf-map-record.sh`. A re-run reloads the draft and continues
where it stopped, so answering a question later does not mean re-ingesting.

## Related

- `harness-story-author` — turn the open questions into JIRA tickets
- `harness-work` — implement the normalizer from a published mapping
- `harness-review` — review a normalizer against its mapping document
