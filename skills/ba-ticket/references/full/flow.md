# ba-ticket --full: the 12-gate authoring flow

Loaded when `ba-ticket` runs with `--full`. The long template
(`templates/ticket-authoring/{epic,story}.md`) is scored against the **same 12
gates** `ba-story-verify` uses, so a story written here passes the verify it
later faces. The draft is kept as a `story-draft.v1` record, so a run can resume.

> **Rough intent → fill the template → score the 12 gates → ask the BA only the
> gap questions → (Epic) propose child stories → operator approves → create in
> JIRA → link children to the epic.**

| | short (default) | `--full` |
|---|---|---|
| Template | `templates/ba-ticket/` — one screen | `templates/ticket-authoring/` — AC table, scenarios, contract tables |
| Quality check | 9-point ready check | 12-gate rubric, readiness derived by `story-author-record.sh` |
| State | markdown under `.claude/state/ba-ticket/<slug>/` | `draft.json` under `.claude/state/story-author/<draft-id>/` |
| Epic sizing | Stories table with teams + dependencies | Child table with role group + story points |
| Template override | `--template <path>` | `--template <path>` or `--template-confluence <url>` |
| Rewrite an existing key | yes | no — use the short mode |

## Core contract (read first)

- **Read-only until you approve.** Filling the template, scoring, and asking the
  BA questions write nothing to JIRA. The only external write is
  `createJiraIssue` (and the epic→child link), drafted, shown to you, and sent
  **only** on an explicit approval — `.claude/rules/autonomous-confirmation-scope.md`
  case 1. Nothing auto-creates.
- **The template is the BA's, not mine.** The default lives at
  `templates/ticket-authoring/{epic,story}.md` (modelled on a real epic and its
  child story, DPD-832 / DPD-838). `--template <path>` /
  `--template-confluence <url>` overrides it. The
  skill treats whatever `## Headings` the chosen template carries as the required
  sections — it does not impose its own format.
- **Ask, never invent.** When a gate's slot is unfilled, ask the BA — never fill
  in a plausible acceptance criterion and proceed. A guessed AC that looks
  answered is worse than a visibly missing one. Every question traces to a
  failing gate; no gate failure, no question.
- **Draft ready ≠ created.** A draft reaches `ready` when every blocker gate
  passes and every question is answered. `ready` still requires your approval to
  become `created`. Readiness is derived by the record helper, never hand-written.
- **Re-entrant.** The draft lives under `.claude/state/story-author/<draft-id>/`
  and is written only through `scripts/story-author-record.sh`. A re-run reloads
  it; an already-`created` draft is never re-created.
- **MCP dependency.** JIRA access uses the Atlassian Rovo MCP tools. Absent
  (headless/cron) → tri-state health reports `not-configured` and the skill can
  still draft locally (`--draft-only`) but pauses before any create.



## Resolving the plugin bundle root

Same as `harness-flow`: resolve `HARNESS_PLUGIN_ROOT` from `CLAUDE_PLUGIN_ROOT`
(if it contains `scripts/`), else from `CLAUDE_SKILL_DIR`
(`${CLAUDE_SKILL_DIR}/../..`, or `../../..` for a mirror). Call only
`${HARNESS_PLUGIN_ROOT}/scripts/...`; keep the draft state under the host
project's `.claude/state/story-author/`.

## State machine

Draft record: `.claude/state/story-author/<draft-id>/draft.json`
(`story-draft.v1`), written only through
`${HARNESS_PLUGIN_ROOT}/scripts/story-author-record.sh` (it derives `readiness`
and schema-validates). `<draft-id>` is a slug of the title
(`export-txn-csv`); an epic's children live in the same record under `children[]`.

```
[Step 0] Resolve + probe
  Resolve HARNESS_PLUGIN_ROOT.
  Probe MCP once (getAccessibleAtlassianResources): success -> healthy,
    error -> unreachable, tools absent -> not-configured.
    bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
  not-configured/unreachable is OK for drafting; it only blocks Step 5 (create).
  |
  v
[Step 1] Load template     Reference: references/full/template-loading.md
  Default templates/ticket-authoring/{epic,story}.md, or --template / --template-confluence.
  Parse the ## sections + <!-- gate: --> tags. Decide epic vs story (flag or inferred).
  Resolve --project (getJiraProjectIssueTypesMetadata to confirm the issue type exists).
  |
  v
[Step 2] Draft            Reference: references/full/authoring-rubric.md
  Fill every template slot you can from the intent/brief. Leave un-fillable slots
  marked. Score the draft against the rubric (same 12 gate ids as verify).
  Persist via story-author-record.sh (it derives readiness=needs-input while gaps remain).
  |
  v
[Step 3] Ask the gaps      Reference: references/full/authoring-rubric.md (question bar)
  For each failing blocker gate, ask ONE decision-shaped question via AskUserQuestion
  (offer the plausible options). Fold answers back into the draft, re-score, repeat
  until readiness=ready or the operator says "author it as-is / leave the rest as
  Open questions". Never ask about a slot the intent already answered.
  |
  v
[Step 4] (Epic) Breakdown  Reference: references/full/epic-breakdown.md
  epic mode only: propose the child-story table (role group | title | points),
  draft each child to the story template, score each. Show the set; the operator
  keeps / edits / drops children before anything is created.
  |
  v
[Step 5] Approve + create  Reference: references/full/create-jira.md
  --draft-only / --dry-run STOP here (render the draft, no create).
  Otherwise show the FULL rendered epic/story (+ children) and ask via
  AskUserQuestion (create all / pick / edit / cancel). On approval only:
    createJiraIssue (epic first) -> for each kept child: createJiraIssue with
    parent=<epic key> -> backfill the Team-split Key column via editJiraIssue.
  Stamp created_key/created_url with story-author-record.sh --set-created.
  Report the created keys + URLs; the ticket is now in JIRA (not transitioned).
```

## Stop / pause conditions

| Condition | Response |
|-----------|----------|
| MCP not-configured/unreachable at Step 5 | `decision_needed.v1` — offer `--draft-only` (draft saved) or retry once connected |
| Project/issue-type cannot be resolved | Ask for `--project` (and the type) via AskUserQuestion; do not guess a project |
| Operator declines to create | Keep the draft at `ready`; report where it is saved so they can create manually |
| A blocker gate stays unfilled and the BA can't answer now | Author with that item moved to `## Open questions` **only on explicit operator OK**; otherwise stay `needs-input` |
| A child create fails mid-batch | Stop; report which children were created and which were not, so a retry does not double-create |

## Silence policy

Report on: which template was used, the draft readiness + failing gates, each
gap question and the folded answer, the proposed child set before creation, what
was created (keys + URLs). Stay silent on: per-gate scoring narration, slot-by-slot
fill mechanics. Always end a created run by naming the epic/story keys + URLs and
noting the issue is created but **not transitioned** (the BA moves it when ready).
