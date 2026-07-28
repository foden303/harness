# harness-ocsf-map

Turn raw log samples into a reviewed OCSF field mapping document.

You give it log input — pasted lines, a file, or a directory to scan — and it
profiles the shape, picks an OCSF event class, maps every field against a
**pinned** OCSF schema, scores the result against a 12-gate rubric, asks you only
the questions the samples cannot answer, and publishes the mapping to Confluence
or writes it to a folder.

## Quick start

```bash
# Publish to Confluence as a child of the given page
/harness-ocsf-map azure-signin --confluence https://secuw.atlassian.net/wiki/spaces/platform/pages/123456/

# No target link -> .md + .mapping.json into a folder
/harness-ocsf-map azure-signin --out ./ocsf-mappings/

# Skip the prompt and ingest a directory directly
/harness-ocsf-map macos-unified --input ./samples/macos/ --class 3002
```

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

## What it will not do

- **Invent a mapping.** Every mapped attribute carries the raw path and a sample
  value observed in your input. The record helper rejects an entry without one,
  so an invented mapping cannot be saved — only asked about.
- **Fetch the schema during a run.** `WebFetch` is absent from the skill's
  allowed-tools. Same samples in, same mapping out.
- **Publish without asking.** Everything up to Step 9 is local. The Confluence
  page or the folder write happens once, on your explicit approval.
- **Hide what it could not map.** Unmapped raw fields, uncovered required
  attributes and unmapped enum values each get their own section, including when
  they are empty.

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
