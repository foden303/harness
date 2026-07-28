---
name: harness-ocsf-map
description: "Map a raw log source onto the pinned OCSF schema and publish the mapping as a document. Takes an optional Confluence target link, then ingests log input one source at a time — pasted raw lines, a single file, or a directory scanned automatically — profiles the raw shape, chooses an OCSF event class, maps every field with the sample value that justifies it, and renders a mapping document. With a Confluence target link it publishes there; without one it writes .md into an output folder. Never invents a mapping and never fetches the schema live. Trigger: ocsf mapping, map logs to ocsf, raw log to ocsf, normalize a log source, field mapping document, ocsf schema mapping, log onboarding. Do NOT load for: authoring JIRA tickets (use harness-story-author), implementing a mapping in code (use harness-work), code review, or release."
description-en: "Map a raw log source onto the pinned OCSF schema and publish the mapping doc: ingest pasted lines / a file / a scanned directory, profile the raw shape, pick an OCSF class, map each field with its observed sample value, score the mapping rubric, then publish to Confluence when a target link is given or write .md to a folder when it is not. Trigger: ocsf mapping, map logs to ocsf, normalize a log source, field mapping document. Do NOT load for: JIRA ticket authoring (harness-story-author), implementation (harness-work), review, release."
kind: workflow
purpose: "Raw log samples -> profile the shape -> pick an OCSF class -> map every field against the pinned schema -> score the mapping rubric -> ask only the gap questions -> operator approves -> publish to Confluence or write .md"
trigger: "ocsf mapping, map logs to ocsf, raw log to ocsf, normalize a log source, field mapping document, log onboarding"
shape: delegate
role: orchestrator
owner: harness-core
since: "2026-07-28"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<source name>] [--confluence <url>] [--out <dir>] [--input <path>] [--class <name|uid>] [--ocsf-version 1.8.0] [--dry-run]"
user-invocable: true
effort: high
---

# harness-ocsf-map

Turn a pile of raw log samples into a reviewed OCSF field mapping, and put that
mapping somewhere a human can read it.

The output is a **document**, not code. It is what a data engineer implements the
normalizer from, and what a reviewer checks the normalizer against.

## Step 0 — Auto-start

```
if $ARGUMENTS == "":
  → ask ONLY for the first log input (Step 3), then run the whole flow
  → "task is unclear" / "waiting for further instructions" / "please provide
     more detail first" are prohibited actions
```

Emit the marker on the first response so a human or a monitor can see the flow
started:

```
OCSF_MAP_AUTOSTART: version={ocsf_version}, target={confluence|folder}, pin={in-sync|not-configured|corrupted}
```

## Core contract (read first)

- **Never invents a mapping.** Every mapped attribute cites the raw field path
  *and* a sample value observed in the input. A plausible OCSF attribute with no
  evidence behind it is the exact failure this skill exists to prevent — the
  record helper rejects a field entry with an empty `sample_value`, so inventing
  one cannot be persisted, only asked about.
- **The schema is pinned, never live.** Mapping runs read
  `templates/ocsf/<version>/` and nothing else. Two runs over the same samples
  produce the same mapping, and a published document stays reproducible after the
  upstream schema moves on. `WebFetch` is deliberately absent from
  `allowed-tools`.
- **Read-only until you approve.** Profiling, mapping and scoring write only to
  the local draft. Publishing — a Confluence page, or files in an output folder —
  is the single external write, shown to you and sent only on explicit approval
  (`.claude/rules/autonomous-confirmation-scope.md` case 1).
- **Unmapped is a result, not a failure.** A raw field with no OCSF home is
  recorded with a disposition (`unmapped` / `extension` / `dropped`) and a reason.
  Silently omitting it would present data loss as a complete mapping.
- **Re-entrant.** The draft lives at
  `.claude/state/ocsf-map/<source-name>/draft.json` and is written **only**
  through `scripts/ocsf-map-record.sh`. A re-run reloads it and continues.

## Arguments

| Argument | Meaning | Default |
|---|---|---|
| `<source name>` | Slug for the log source, e.g. `azure-signin` | Asked if absent |
| `--confluence <url>` | Publish under this Confluence page as a child | Absent → folder output |
| `--out <dir>` | Folder for `.md` output when no Confluence target | `./ocsf-mappings/` |
| `--input <path>` | A file or directory to ingest without prompting | Asked interactively |
| `--class <name\|uid>` | Force the OCSF class instead of proposing one | Proposed from evidence |
| `--ocsf-version <v>` | Which pinned schema to map against | `1.8.0` |
| `--dry-run` | Render the document, never publish | off |

## Flow

### Step 1 — Schema pin gate

```bash
./scripts/ocsf-schema-pin.sh status --version "$OCSF_VERSION" --json
```

Read `reason` and branch — do not fetch, and do not fall back to memory of the
schema:

| `reason` | Do |
|---|---|
| `in-sync` | Continue. Record `pin_reason: "in-sync"`. |
| `not-configured` | **Stop the mapping.** Tell the operator to run `./scripts/ocsf-schema-pin.sh fetch --version <v>` — it needs network egress, so it is theirs to run, not yours. Offer the `--from-file` route for an air-gapped machine. |
| `corrupted` | **Stop.** Report the failing files from `verify` and tell the operator to re-fetch. A hand-edited pin silently changes what every mapping is scored against. |

A record whose `pin_reason` is not `in-sync` can never reach `ready` — the record
helper enforces it, so there is no path where a mapping against a missing schema
looks finished.

### Step 2 — Resolve the output target

One decision, made once, recorded in the draft:

- `--confluence <url>` given → `target: "confluence"`. Resolve the page with
  `mcp__claude_ai_Atlassian_Rovo__getConfluencePage` **now**, so a bad link fails
  before any mapping work rather than after it.
- No link → `target: "folder"`, `out_dir` from `--out` or `./ocsf-mappings/`.

State the resolved target in one line and continue. This is not a confirmation —
the operator chose it by passing (or not passing) the flag.

Details, page shape and the folder layout:
[output-targets.md](${CLAUDE_SKILL_DIR}/references/output-targets.md)

### Step 3 — Ingest input, one source at a time

Three modes, all supported in the same run — the operator adds sources until they
say they are done:

1. **raw** — pasted log lines, straight into the conversation
2. **file** — one named file
3. **scan** — a directory walked automatically, grouped by detected format

After each source, report what was ingested (lines seen, lines parsed, format
detected) and ask whether to add another. Never silently stop at the first.

Format detection, parse-rate accounting and the field inventory:
[input-ingestion.md](${CLAUDE_SKILL_DIR}/references/input-ingestion.md)

### Step 4 — Profile the raw shape

Build the field inventory across **all** ingested sources: field path, observed
types, occurrence count, distinct-value sample, and a flag for anything that
looks like PII.

The occurrence count matters downstream: a field present in 3 of 500 records is
thin evidence, and mapping it with `confidence: high` is wrong even when the
mapping itself is obviously right.

### Step 5 — Choose the OCSF class

Propose one class from the pinned `classes/` directory, justified by evidence in
the samples — not by the source's name. `why` must quote what in the records
makes this class the right one.

`--class` overrides the proposal. If the samples clearly contain **two** kinds of
event, say so and map them as two separate runs rather than forcing one class.

### Step 6 — Map the fields

For each inventory entry, find its OCSF home in the pinned class, and in
`objects/` for nested types.

The pin holds the **authored** schema, not a resolved bundle: a class file
declares `extends` and does not repeat what it inherits. Walk that chain to
`base_event.json` before deciding an attribute does not exist — a class file
alone will not show you `time`, `severity_id` or `metadata`, and treating its
attribute list as complete is how a required attribute gets reported as absent
when it was inherited all along. `manifest.json` records
`inheritance_resolved: false` as the standing reminder.

Every entry records `raw_path`, `sample_value`, `ocsf_attribute`, `transform`
and `confidence`. Anything with no home goes to `unmapped_raw` with a
disposition. Every `required` attribute of the class that nothing supplies goes to
`missing_required` with a reason.

Enum attributes (`activity_id`, `status_id`, `severity_id`, …) get an `enums`
entry with the explicit value map, and any raw value that has no OCSF equivalent
is listed in `unmapped_values` rather than folded into `Other`.

### Step 7 — Score the rubric, ask only the gaps

Score the 12 gates in
[mapping-rubric.md](${CLAUDE_SKILL_DIR}/references/mapping-rubric.md). Every
blocker failure becomes **one decision-shaped question** to the operator via
`AskUserQuestion` — offering the plausible options so they pick rather than
compose. Fold answers back in, re-score, repeat.

Persist after every scoring pass:

```bash
bash scripts/ocsf-map-record.sh --in "$TMP/draft.json" \
  --out ".claude/state/ocsf-map/<source-name>/draft.json"
```

Readiness comes back from the helper. Do not write it by hand.

### Step 8 — Render the document

Render from the record, not from memory of the conversation. Section order and
the exact table shapes are in
[output-targets.md](${CLAUDE_SKILL_DIR}/references/output-targets.md).

### Step 9 — Publish (the only external write)

Show the rendered document and the coverage summary, then ask for approval once.
On approval:

- **Confluence** — `createConfluencePage` as a child of the target, then re-run
  the record helper with `--set-published` carrying the returned `page_id`.
- **Folder** — write `<out_dir>/<source-name>.md` plus
  `<out_dir>/<source-name>.mapping.json` (the record itself, so the document and
  its machine-readable source stay together), then `--set-published` with the
  file list.

`--dry-run` stops before this step with the document printed and nothing written.

## Related skills

- `harness-story-author` — turn the open questions this produces into JIRA tickets
- `harness-work` — implement the normalizer from a published mapping
- `harness-review` — review a normalizer against its mapping document
