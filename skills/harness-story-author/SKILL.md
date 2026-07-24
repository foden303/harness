---
name: harness-story-author
description: "Author a JIRA ticket or Epic FROM a template the BA supplies. Takes a rough intent, fills the default (or an overridden) ticket template, scores the draft against the authoring rubric, asks the BA only the questions needed to fill the gaps, then — for an Epic — proposes a child-story breakdown. Nothing is created in JIRA until the operator approves; only then does it call createJiraIssue and link children to the epic. The reverse of harness-story-verify: it writes stories rather than checking them. Trigger: author a ticket, create an epic, draft a story, write a user story, gen a ticket, define a ticket, turn this into a JIRA epic, break this into stories. Do NOT load for: verifying an EXISTING ticket's clarity (use harness-story-verify), implementing a ticket (use harness-flow), or bug triage (use harness-bugfix)."
description-en: "Author a JIRA ticket or Epic from a BA-supplied template: fill the template, score against the authoring rubric, ask only the gap questions, propose an Epic's child breakdown, and create in JIRA only after operator approval. The inverse of harness-story-verify. Trigger: author a ticket, create an epic, draft a story, gen a ticket, define a ticket, break this into stories. Do NOT load for: verifying an existing ticket (harness-story-verify), implementing (harness-flow), bug triage (harness-bugfix)."
kind: workflow
purpose: "Fill a ticket/epic template from a rough intent -> score the authoring rubric -> ask only the gap questions -> (epic) propose child stories -> operator approves -> createJiraIssue + link"
trigger: "author a ticket, create an epic, draft a story, gen a ticket, define a ticket, break this into stories"
shape: delegate
role: orchestrator
base: harness-flow
pair: harness-story-verify
owner: harness-core
since: "2026-07-23"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<intent text>|<brief-file>] [--epic|--story] [--project KEY] [--template <path>|--template-confluence <url>] [--report-only] [--dry-run]"
user-invocable: true
effort: high
---

# harness-story-author

The requirements-*authoring* half, the mirror of `harness-story-verify`:

> **Rough intent → fill the template → score the authoring rubric →
> ask the BA only the gap questions → (Epic) propose child stories →
> operator approves → create in JIRA → link children to the epic.**

`harness-story-verify` reads an existing ticket and asks the BA what is missing.
This skill goes the other way: it **writes** the ticket to the BA's own template,
using the same rubric so a story it authors would pass the verify it later faces.

| | harness-story-verify | harness-story-author |
|---|---|---|
| Direction | reads an existing ticket | **writes a new one** |
| Rubric use | scores → questions on the ticket | scores the draft → questions to the BA in-session |
| Epic | expands to children | **proposes children** to create |
| Ends at | verdict + comment | **created issue(s) in JIRA** |
| JIRA write | one clarification comment | `createJiraIssue` (+ links) |

## Core contract (read first)

- **Read-only until you approve.** Filling the template, scoring, and asking the
  BA questions write nothing to JIRA. The only external write is
  `createJiraIssue` (and the epic→child link), drafted, shown to you, and sent
  **only** on an explicit approval — `.claude/rules/autonomous-confirmation-scope.md`
  case 1. Nothing auto-creates.
- **The template is the BA's, not mine.** The default lives at
  `templates/ticket-authoring/{epic,story}.md` (modelled on a real epic,
  DPD-832). `--template <path>` / `--template-confluence <url>` overrides it. The
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
  still draft locally (`--report-only`) but pauses before any create.

## Quick Reference

| Input | Behavior |
|------|------|
| `/harness-story-author "let users export the txn list to CSV"` | Draft one Story, ask the gaps, create on approval |
| `/harness-story-author brief.md --epic --project DPD` | Read the brief, draft an Epic + propose child stories |
| `/harness-story-author "..." --template ./my-ticket.md` | Use your own template instead of the default |
| `/harness-story-author "..." --template-confluence https://<site>/wiki/.../id` | Use a Confluence page as the template |
| `/harness-story-author "..." --report-only` | Draft + render, never offer to create (no JIRA writes at all) |
| `/harness-story-author "..." --dry-run` | Walk the flow, write no state and never call createJiraIssue |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<intent>` / `<brief-file>` | The raw idea to turn into a ticket | required |
| `--epic` / `--story` | Author an Epic (with children) or a single Story | inferred from the intent |
| `--project KEY` | Target JIRA project | asked if not resolvable |
| `--template <path>` | Override the default template with a local file | default `templates/ticket-authoring/` |
| `--template-confluence <url>` | Use a Confluence page as the template | - |
| `--report-only` | Draft + report only; never offer to create | off |
| `--dry-run` | No state writes, no JIRA create | off |

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
[Step 1] Load template     Reference: references/template-loading.md
  Default templates/ticket-authoring/{epic,story}.md, or --template / --template-confluence.
  Parse the ## sections + <!-- gate: --> tags. Decide epic vs story (flag or inferred).
  Resolve --project (getJiraProjectIssueTypesMetadata to confirm the issue type exists).
  |
  v
[Step 2] Draft            Reference: references/authoring-rubric.md
  Fill every template slot you can from the intent/brief. Leave un-fillable slots
  marked. Score the draft against the rubric (same 12 gate ids as verify).
  Persist via story-author-record.sh (it derives readiness=needs-input while gaps remain).
  |
  v
[Step 3] Ask the gaps      Reference: references/authoring-rubric.md (question bar)
  For each failing blocker gate, ask ONE decision-shaped question via AskUserQuestion
  (offer the plausible options). Fold answers back into the draft, re-score, repeat
  until readiness=ready or the operator says "author it as-is / leave the rest as
  Open questions". Never ask about a slot the intent already answered.
  |
  v
[Step 4] (Epic) Breakdown  Reference: references/epic-breakdown.md
  epic mode only: propose the child-story table (role group | title | points),
  draft each child to the story template, score each. Show the set; the operator
  keeps / edits / drops children before anything is created.
  |
  v
[Step 5] Approve + create  Reference: references/create-jira.md
  --report-only / --dry-run STOP here (render the draft, no create).
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
| MCP not-configured/unreachable at Step 5 | `decision_needed.v1` — offer `--report-only` (draft saved) or retry once connected |
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

## Related skills

- `harness-story-verify` — the inverse: verify a ticket someone already wrote
- `harness-flow` — build a ticket once it is authored and verified clear
- `harness-plan` — turn an authored epic into Plans.md tasks
- `harness-bugfix` — author/triage a bug rather than a story
