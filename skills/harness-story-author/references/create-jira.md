# Create in JIRA (Step 5)

Creating the issue is the **only** external write and an **irreversible** one (a
created ticket notifies watchers and takes a key). Under
`.claude/rules/autonomous-confirmation-scope.md` case 1 it requires operator
approval first. This skill never auto-creates.

`--report-only` and `--dry-run` stop before this step: render the draft, save the
state, offer no approval prompt, call no create.

## Approval BEFORE creating (required)

Show the FULL rendered issue(s) — the description exactly as it will appear, with
guidance comments stripped — then ask **once** via `AskUserQuestion`:

```json
{
  "decision_needed": {
    "required": true,
    "ask_tool": "AskUserQuestion",
    "question": "Create this Epic + 4 child stories in DPD?",
    "options": [
      "Create the epic + all 4 children",
      "Create the epic only (I'll add children later)",
      "Let me pick which children",
      "Edit something first",
      "Cancel — don't create anything"
    ],
    "context": { "project": "DPD", "epic": "[Stream Detection] Rule Flow …", "children": 4 }
  }
}
```

Act on the answer:

- **Create all** → create the epic, then each `ready` child.
- **Epic only** → create the epic; leave children in the draft at `ready`.
- **Pick** → a second `AskUserQuestion` (multiSelect) listing the children; create
  only the selected ones.
- **Edit** → revise the draft, re-score, re-render, and re-present. Do not create
  in between.
- **Cancel** → write nothing to JIRA; report where the draft is saved.

If `AskUserQuestion` is unavailable, emit `decision_needed.v1` and halt. Never
fall through to creating.

## Creating (only after approval)

Create the **epic first**, then its children with `parent` set to the new epic
key.

```
mcp__claude_ai_Atlassian_Rovo__createJiraIssue
  cloudId:       <cloud_id>
  projectKey:    <project_key>
  issueTypeName: "Epic"            # or the resolved hierarchy-level-1 type
  summary:       <title>
  description:   <body_markdown>   # contentFormat: "markdown"
  contentFormat: "markdown"
  additional_fields: { "labels": [...], "priority": {"name": "Medium"}, "components": [...] }
```

Then for each kept child:

```
createJiraIssue
  cloudId:       <cloud_id>
  projectKey:    <project_key>
  issueTypeName: "Story"
  summary:       <child.title>
  description:   <child.body_markdown>
  contentFormat: "markdown"
  parent:        <epic key returned above>     # sets the epic → child parent link
  additional_fields: { "labels": [...] }
```

Notes:

- **Parent link.** In most projects, setting the child's `parent` to the epic key
  is what puts it under the epic. If the API rejects `parent` for a
  company-managed project's epic, fall back to
  `mcp__claude_ai_Atlassian_Rovo__createIssueLink` (or the project's Epic Link
  field). Report which mechanism was used.
- **Backfill the Team-split table.** After the children exist, update the epic's
  `## Team split` table so the Key column holds the real keys, via
  `mcp__claude_ai_Atlassian_Rovo__editJiraIssue` on the epic description.
- **Cross-issue dependencies.** If the critical path implies "A blocks B", add
  `createIssueLink` (type `Blocks`) only when the operator asked for it —
  otherwise leave the narrative chain in the description and let the team wire it.

## Record the result

After each successful create, stamp the key onto the draft (do not hand-edit the
record — the helper re-derives `readiness` to `created`):

```bash
printf '%s' '{"created_key":"DPD-900","created_url":"https://<site>/browse/DPD-900","created_at":"<utc>"}' \
  > "$TMP/created.json"

bash "${HARNESS_PLUGIN_ROOT}/scripts/story-author-record.sh" \
  --in ".claude/state/story-author/<draft-id>/draft.json" \
  --out ".claude/state/story-author/<draft-id>/draft.json" \
  --set-created "$TMP/created.json"
```

For children, record each `created_key`/`created_url` onto its `children[]` entry
(readiness `created`).

## Partial-failure handling

If a child create fails after the epic (or earlier children) succeeded, **stop**.
Report exactly which issues were created (with keys) and which were not, so a
retry creates only the missing ones — never re-create an issue that already has a
key. The draft record is the source of truth for what exists.

## After creating

The issue is **created, not transitioned** — it lands in the project's default
status (usually Backlog/To Do). The skill does not move it; the BA transitions it
when ready, or hands the keys to `harness-flow` to build. End the run by naming
every created key + URL.
