# harness-story-author

Author a JIRA **ticket** or **Epic** from a rough idea, using your own template.
The skill fills the template, scores the draft against a 12-gate quality rubric,
asks you **only** the questions needed to fill the gaps (never inventing an
acceptance criterion), proposes an Epic's child-story breakdown, and creates the
issue in JIRA **only after you approve**.

It is the authoring mirror of `harness-story-verify`: a story it writes is built
to pass the verification it will later face.

---

## Quick start

```bash
# A single user story from one line of intent
/harness-story-author "let users export the transaction list to CSV"

# An Epic that auto-proposes its child stories
/harness-story-author "move detection from OpenSearch to a Flink stream job" --epic --project DPD

# Draft only — never touch JIRA (safe to try first)
/harness-story-author "..." --report-only
```

You do **not** need a complete spec. Give the core idea; for every template slot
you did not cover, the skill stops and asks you one decision-shaped question.

---

## How to pass your idea

There are two ways to feed the intent.

### 1. Inline text

Put the idea in quotes right after the command. Write naturally — long is fine:

```bash
/harness-story-author "Customers can't self-serve their transaction report and
have to ask support. Add an Export button on the Transactions screen that emits a
CSV of the currently filtered rows, used for monthly reconciliation" --story --project DPD
```

### 2. A brief file

For a longer idea or an existing document, write it to a `.md` file and point at it:

```bash
/harness-story-author brief.md --epic --project DPD
```

Anything in `brief.md` — background, goal, the parts to build, who is involved —
becomes raw material for the draft.

---

## Options

| Option | What it does | Default |
|--------|--------------|---------|
| `<intent>` / `<brief-file>` | The raw idea to turn into a ticket | required |
| `--story` / `--epic` | Author a single Story, or an Epic + child stories | inferred from the intent |
| `--project KEY` | Target JIRA project (e.g. `DPD`) | asked if not resolvable |
| `--template <path>` | Use your own template file instead of the default | `templates/ticket-authoring/` |
| `--template-confluence <url>` | Use a Confluence page as the template | – |
| `--report-only` | Draft and render only; never offer to create | off |
| `--dry-run` | Walk the flow, write no state, never call JIRA | off |

---

## What happens, step by step

1. **Load the template.** Default templates ship with the skill; override with
   `--template` or `--template-confluence`. The template's `## Headings` become
   the required sections.
2. **Draft.** Every slot the skill can fill from your idea is filled; the rest
   are marked. The draft is scored against the rubric.
3. **Ask the gaps.** For each unfilled *blocker* section, the skill asks one
   question with the plausible options for you to pick — e.g.
   *"For a 10k-row export, acceptable wait: (a) under 2s, (b) under 5s,
   (c) background job + email?"*. Your answers are folded back in and re-scored.
4. **(Epic only) Propose children.** The skill proposes a child-story table
   (role group / title / points) and drafts each child to the story template.
   You keep, edit, or drop children.
5. **Approve, then create.** You see the full rendered issue(s). Only on your
   explicit approval does the skill call `createJiraIssue`, link children to the
   epic, and backfill the epic's table with the real keys. Nothing auto-creates.

The issue is **created, not transitioned** — it lands in the project's default
status, and you move it when ready.

---

## Using your own ticket format

The default template is only a default. To make the skill follow **your** format:

1. Copy a default template:
   `templates/ticket-authoring/epic.md` or `story.md`.
2. Edit the `## Headings` and the `{{slots}}` to match your team's ticket shape.
   A `<!-- gate: <id> -->` comment ties a section to a quality gate the skill will
   ask about; a section without one is filled best-effort and never blocks.
3. Point the skill at it:

```bash
/harness-story-author "..." --template ./my-team-ticket.md
```

Or keep the format on Confluence and use it directly:

```bash
/harness-story-author "..." --template-confluence https://<site>/wiki/.../pageId
```

---

## Safety

- **Read-only until you approve.** Filling the template, scoring, and asking
  questions write nothing to JIRA. The only external write is `createJiraIssue`
  (plus the epic→child link), and it is sent only on an explicit approval.
- **It asks, it never invents.** A missing acceptance criterion becomes a
  question, never a plausible-looking guess.
- **Re-entrant.** The draft is saved under
  `.claude/state/story-author/<draft-id>/`; re-running reloads it and never
  re-creates an issue that already has a key.
- **Needs the Atlassian MCP** for the create step. Without it you can still draft
  locally with `--report-only`.

**Tip:** on your first run, add `--report-only` to inspect the output before
anything reaches JIRA.

---

## Related skills

- `harness-story-verify` — verify a ticket someone already wrote (the inverse)
- `harness-flow` — build a ticket once it is authored and verified
- `harness-plan` — turn an authored epic into a Plans.md work breakdown
