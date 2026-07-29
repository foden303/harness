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
  → run the Step 1 intake immediately (two questions, then work)
  → "task is unclear" / "waiting for further instructions" / "please provide
     more detail first" are prohibited actions
```

Emit the marker on the first response so a human or a monitor can see the flow
started:

```
OCSF_MAP_AUTOSTART: version={ocsf_version}, target={pending}, pin={in-sync|not-configured|corrupted}
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

Every argument is optional. Each one **pre-answers a Step 1 intake question**;
whatever is not passed gets asked instead of assumed.

| Argument | Meaning | If absent |
|---|---|---|
| `<source name>` | Slug for the log source, e.g. `azure-signin` | Derived from the input path or page title, and the derivation is stated |
| `--confluence <url>` | Publish under this Confluence page as a child | **Asked** (intake Q1) |
| `--out <dir>` | Folder to write `.md` into | **Asked** (intake Q1), suggesting `./ocsf-mappings/` |
| `--input <path>` | File or directory to ingest | **Asked** (intake Q2) |
| `--class <name\|uid>` | Force the OCSF class | Proposed from evidence in the samples |
| `--ocsf-version <v>` | Which pinned schema to map against | `1.8.0` |
| `--dry-run` | Render + self-review, never publish | off |

Passing both `--confluence` and `--out` is ambiguous — the skill asks which one
rather than picking.

## Flow

### Step 1 — Intake (ask both, before any work)

**Never start mapping with either of these unresolved.** A run that guesses the
destination and then produces a document is a run whose output lands somewhere the
operator did not choose. Ask both up front, in one batch, via
`AskUserQuestion` — skipping whichever the flags already answered:

1. **Where does the output go?** — a Confluence page link, or a folder. If they
   pick folder, ask the folder name in the same batch rather than assuming
   `./ocsf-mappings/`.
2. **How is the log provided?** — pasted lines, one file, or a folder to scan.
   Ask for the actual path in the same batch when they pick file or folder.

Then **validate what they gave before working**, and re-ask on failure rather
than proceeding to a destination or an input that does not exist:

| Answer | Validate now | On failure |
|---|---|---|
| Confluence link | `getConfluencePage` resolves it | Re-ask for the link — do not silently fall back to folder output |
| Folder for output | Parent path exists and is writable | Offer to create it, or re-ask |
| File input | File exists and is non-empty | Re-ask |
| Folder input | Folder exists and holds at least one readable file | Re-ask, listing what was found |

Ten seconds of validation here is the difference between a bad link costing the
operator nothing and costing them a full mapping run.

Record `target`, `out_dir` / `confluence_url`, and the input plan in the draft,
then restate the resolved intake in one line before continuing:

```
OCSF_MAP_INTAKE: target=folder out_dir=./ocsf-mappings input=scan:./samples/azure/ source=azure-signin
```

Question wording, the option sets, and how flags pre-answer them:
[intake.md](${CLAUDE_SKILL_DIR}/references/intake.md)

### Step 2 — Schema pin gate

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

### Step 9 — Self-review the rendered document

Review what you just wrote **before** showing it. Rendering is a second chance to
introduce errors the rubric already cleared: a row that exists in the document but
not in the record, a header count that disagrees with its own table, a PII value
printed unredacted into a page that will be read more widely than the log file
was.

Run the 8 render checks in
[self-review.md](${CLAUDE_SKILL_DIR}/references/self-review.md). Fix what you can
fix, and report what you cannot — the review result is shown to the operator at
the publish gate, not quietly discarded.

A self-review that finds nothing says so explicitly. "0 findings across 8 checks"
is information; silence is indistinguishable from not having looked.

### Step 10 — Publish gate (the only external write)

Present all four of these together, then ask **once** with `AskUserQuestion`:

1. **Exactly where it goes** — the full file path, or the Confluence page title
   and its parent. Never "the output folder"; the literal target.
2. **The document content** — the rendered markdown itself, not a description of
   it. The operator is approving the content, so the content is what they see.
3. **The coverage summary** — mapped / unmapped / missing-required counts, and any
   unanswered open questions travelling with the document.
4. **The self-review result** — the findings from Step 9, or "0 findings".

Offer three choices: **publish**, **edit first** (say what to change, re-render,
re-review, ask again), or **cancel** (nothing is written; the draft survives for a
later re-run).

On publish:

- **Confluence** — `createConfluencePage` as a child of the target, then re-run
  the record helper with `--set-published` carrying the returned `page_id`.
- **Folder** — write `<out_dir>/<source-name>.md` plus
  `<out_dir>/<source-name>.mapping.json` (the record itself, so the document and
  its machine-readable source stay together), then `--set-published` with the
  file list.

Report the concrete result afterwards — the page URL, or the paths written with
their byte counts. "Published successfully" without a locator is not a result.

`--dry-run` stops before this step with the document and the self-review printed,
and nothing written.

## Related skills

- `harness-story-author` — turn the open questions this produces into JIRA tickets
- `harness-work` — implement the normalizer from a published mapping
- `harness-review` — review a normalizer against its mapping document
