# Ingestion reference (Step 1)

Fetch the requirement(s) from JIRA or Confluence via the Atlassian Rovo MCP
tools, normalize in-context, and persist as `requirement.v1`.

## One link vs many links

- **One ref** → one ticket → one requirement (the common case).
- **Multiple refs** (`PROJ-123 PROJ-124 PROJ-125`) → they are the **same feature**.
  Ingest each, then **merge into a single `requirement.v1`** (see "Merging"
  below). Everything downstream (verify, plan, work, review, confirm, commit)
  treats them as one unit.

## Decide the source (per ref)

| Argument shape | source | source_ref |
|----------------|--------|------------|
| Matches `^[A-Z][A-Z0-9]+-[0-9]+$` (e.g. `PROJ-123`) | `jira` | the issue key |
| A URL / bare page id | `confluence` | the page URL (or id) |

Derive `<session-id>` from the **primary (first)** ref: lowercase the key
(`PROJ-123` → `proj-123`), or `conf-<pageId>` for Confluence. This makes re-runs
of the same feature resume the same session.

## MCP health first

Do one lightweight call to decide the tri-state:

- `getAccessibleAtlassianResources` (or `atlassianUserInfo`).
  - returns resources → `healthy`
  - raises/times out → `unreachable`
  - tool not present in the environment → `not-configured`

Record it:
```
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <state>
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" set <session.json> mcp_health <state>
```
If `unreachable` or `not-configured`, do not fabricate a requirement — emit
`decision_needed.v1` ("Atlassian MCP unavailable; provide the requirement
manually or reconnect the MCP") and stop.

Also call `atlassianUserInfo` once and store the bot accountId for later BA-reply
matching:
```
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" \
  set-json <session.json> clarification '{"bot_account_id":"<accountId>","rounds":0}'
```

## JIRA path

1. `getJiraIssue` for the key. Extract:
   - `title` ← `fields.summary`
   - `description` ← `fields.description` (ADF/text → plain text)
   - `acceptance_criteria` ← the acceptance-criteria custom field if present,
     else parse a "## Acceptance Criteria" / checklist section out of the
     description. One criterion per line.
   - `labels` ← `fields.labels`
   - `issue_type` ← `fields.issuetype.name`
   - `status` ← `fields.status.name`
   - `reporter_account_id` ← `fields.reporter.accountId`
2. Optionally `getTransitionsForJiraIssue` now so Step 9 `--close-jira` has the
   transition ids ready.

## Confluence path

1. Parse the page id from the URL. `getConfluencePage` for the body + version.
2. Extract `title` ← page title; `description` ← page body (storage/HTML → text).
3. `acceptance_criteria` ← a criteria/checklist section if the page has one.
   A free-form page often has none — that is expected and the verify rubric
   (gate 2) will route it to the BA loop to elicit them (do not invent criteria).
4. `getConfluencePageFooterComments` to seed the comment baseline for the BA loop.

## Merging multiple links into one feature

When more than one ref is passed:

1. Fetch every ref (mixed JIRA + Confluence is allowed).
2. Synthesize a single merged requirement in-context:
   - **title** ← a feature-level title covering all tickets (e.g.
     "Checkout revamp (PROJ-123, PROJ-124, PROJ-125)").
   - **description** ← concatenate each ticket's description under a header
     `## <REF>: <ticket title>` so provenance stays clear.
   - **acceptance_criteria** ← the **union** of all tickets' criteria; de-dupe
     obvious repeats. Keep each criterion decidable Yes/No.
   - **labels** ← union of labels.
3. Build the `sources` array (one entry per ref) and write it to a temp file:
   ```
   printf '%s' '[{"source":"jira","source_ref":"PROJ-123","title":"..."},
                 {"source":"jira","source_ref":"PROJ-124","title":"..."}]' \
     > "$TMP/sources.json"
   ```
4. Pass `--sources-file "$TMP/sources.json"` to the ingest helper; keep
   `--source`/`--source-ref` as the **primary** (first) ref.
5. Record all refs on the session for traceability:
   ```
   bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" \
     set-json <session.json> source_refs '["PROJ-123","PROJ-124","PROJ-125"]'
   ```

Verification (Step 2) then runs **once** over the merged requirement — one set of
gates, one BA loop if anything is unclear (a clarifying question targets the
specific ticket it came from; see ba-loop.md).

## Normalize + persist

Write the long fields to temp files in the scratchpad (never argv), then:

```
printf '%s' "<description text>"      > "$TMP/desc.txt"
printf '%s\n' "<criterion 1>" "<criterion 2>" > "$TMP/ac.txt"

bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-ingest-requirement.sh" \
  --source jira --source-ref PROJ-123 \
  --title "<summary>" \
  --description-file "$TMP/desc.txt" \
  --acceptance-criteria-file "$TMP/ac.txt" \
  --labels backend,api --issue-type Story --status "To Do" \
  --reporter-account-id "<accountId>" --mcp-available true \
  --out ".claude/state/flow/<session-id>/requirement.json"

bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" \
  set <session.json> requirement_path ".claude/state/flow/<session-id>/requirement.json"
bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-session.sh" status <session.json> ingested
```

The helper validates against `templates/schemas/requirement.v1.json`; a non-zero
exit means the extraction was malformed — fix the field mapping, do not weaken
the schema.

## Unknown data contract

Missing information is `unknown`, never asserted `absent`. If the JIRA
description is empty or the acceptance-criteria field is not present, record an
empty `acceptance_criteria` array and let the verify rubric decide — do not
guess criteria from the title.
