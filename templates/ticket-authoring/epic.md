<!--
harness-story-author :: default EPIC template
================================================
This is the DEFAULT format harness-story-author fills in when authoring an Epic.
It is modelled on a real, well-shaped epic (secuw.atlassian.net/browse/DPD-832).

How the skill uses this file:
  - Every `## Heading` below is a REQUIRED section of the epic description.
  - Text in {{double-braces}} is a slot the skill fills from the BA's answers.
  - A `<!-- gate: <id> -->` comment ties a section to an authoring-rubric gate
    (skills/harness-story-author/references/authoring-rubric.md). If the BA has
    not supplied enough to fill a gated slot, the skill ASKS instead of guessing.
  - Lines beginning with `<!--` are guidance only and are stripped before the
    description is written to JIRA.

To use YOUR OWN format instead of this one, copy this file, edit the sections,
and run: /harness-story-author "<intent>" --template <path-to-your-copy.md>
The skill treats whatever `## Headings` your copy contains as the required
sections — this file is only the default, never a hard-coded schema.
-->

# {{epic_title}}
<!-- summary/title. Keep it a capability, not a task. e.g. "[Stream Detection] Rule Flow & OCSF Transition" -->

## Epic
<!-- gate: goal-value-clear -->
{{context_paragraph}}
<!--
One or two paragraphs: move FROM the current painful state TO the desired state,
and name what is NEW versus what stays the same. State the source of truth if
one exists. This is the "why now / why this" — not a restatement of the title.
-->

**Design doc:** {{design_doc_link_or_none}}
<!-- gate: design-reference. A link, or the literal "none — no prior design". -->

## Definition of Done
<!-- gate: ac-present-testable -->
{{definition_of_done}}
<!--
One paragraph of OBSERVABLE outcome — something a person can watch happen and
call done/not-done. e.g. "A rule assigned in the UI produces alerts within
seconds, alert content matches the old detector, and OpenSearch detectors are off."
Avoid "works well" / "is fast" — those are not decidable.
-->

## Team split
<!-- gate: invest-sizing / scope-boundaries -->
<!--
The breakdown into child stories, grouped by the role that owns them. The skill
proposes this table from the epic (see references/epic-breakdown.md); the BA
approves/edits before any child is created. Points are a rough size, not a
commitment. After creation the Key column is backfilled with the real JIRA keys.
-->

### {{role_group_1}}

| Key | Title | Points |
| --- | --- | --- |
| {{key}} | {{child_title}} | {{points}} |

### Out of scope for this epic
<!-- gate: scope-boundaries -->
{{out_of_scope_bullets}}
<!-- Bullets naming what is deliberately NOT in this epic and who owns it instead. -->

## Critical path
<!-- gate: dependencies-identified -->
{{critical_path_chain}}
<!--
The ordered dependency chain (A -> B -> C ...) plus a short narrative: what
gates what, what can start immediately, what is the schedule risk. If the epic
starts with a decision rather than code, say so.
-->

## Scope findings
<!--
OPTIONAL but high-value: where reality differs from what the design/assumptions
imply, and how that changes an estimate. Drop this section only if there are no
such surprises. Table shape:
-->

| The plan assumes | What is actually true today | Consequence |
| --- | --- | --- |
| {{assumption}} | {{reality}} | {{consequence}} |

## Open questions
<!-- gate: no-ambiguous-wording -->
<!--
Unresolved decisions that must be settled, with a current lean so they are not
blocking by default, plus what each one blocks and who owns it. These are the
questions the skill could NOT resolve with the BA during authoring and that are
genuinely for the wider team. Anything the skill can resolve by asking the BA,
it asks BEFORE the draft is finalised — it does not dump those here.
-->

| # | Question | Current lean | Blocks | Owner |
| --- | --- | --- | --- | --- |
| {{n}} | {{question}} | {{lean}} | {{blocks}} | {{owner}} |
