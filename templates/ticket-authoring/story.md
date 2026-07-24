<!--
harness-story-author :: default STORY (child ticket) template
==============================================================
The DEFAULT format harness-story-author fills in when authoring a single Story,
or each child story proposed under an Epic. Same conventions as epic.md:
  - `## Heading` = a required section of the description.
  - {{double-braces}} = a slot filled from the BA's answers.
  - `<!-- gate: <id> -->` ties a section to an authoring-rubric gate; a slot the
    BA has not answered is ASKED, never guessed.
  - `<!-- ... -->` lines are guidance, stripped before writing to JIRA.

Override with: /harness-story-author "<intent>" --template <your-copy.md>
-->

# {{story_title}}
<!-- summary/title. A capability the user gains. e.g. "Accept `stream` as a conversion backend". -->

## Story
<!-- gate: story-format / goal-value-clear -->
As a **{{role}}**, I want **{{capability}}** so that **{{benefit}}**.
<!-- If a user-story shape does not fit (pure infra), state the outcome and why it matters instead. -->

## Acceptance criteria
<!-- gate: ac-present-testable / ac-covers-happy-path -->
{{acceptance_criteria}}
<!--
A numbered list. Each item decidable Yes/No by a person or a test:
  1. Given <state>, when <action>, then <observable result>.
Cover the main success path end to end (trigger -> action -> result).
-->

## Edge & error cases
<!-- gate: edge-error-states -->
{{edge_cases_or_out_of_scope}}
<!-- Failure / empty / loading / permission-denied behaviour — or "out of scope: <why>". -->

## Data & validation
<!-- gate: data-validation-rules -->
{{data_rules_or_na}}
<!-- For every new input: field, type, required/optional, limits, format, default. "n/a — no new inputs" if none. -->

## Scope
<!-- gate: scope-boundaries -->
{{in_and_out_of_scope}}
<!-- What is in, what is explicitly out. Keep the story a one-sprint vertical slice. -->

## Dependencies
<!-- gate: dependencies-identified -->
{{dependencies_or_none}}
<!-- Upstream/downstream tickets, APIs, services, teams, flags, migrations — or "none". -->

## Notes
<!--
OPTIONAL: non-functional expectations (perf, security/permissions, a11y, i18n,
analytics) when the story carries them (money, PII, auth, bulk data), design
link for UI work, and a rough size in points.
-->
- **Points:** {{points}}
- **Design:** {{design_link_or_none}}
- **Non-functional:** {{nonfunctional_or_none}}
