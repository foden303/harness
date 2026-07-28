<!--
harness-story-author :: default STORY (child ticket) template
==============================================================
The DEFAULT format harness-story-author fills in when authoring a single Story,
or each child story proposed under an Epic. It is modelled on a real,
well-shaped story (secuw.atlassian.net/browse/DPD-838), the sibling of the epic
that epic.md is modelled on (DPD-832).

Same conventions as epic.md:
  - `## Heading` = a required section of the description.
  - {{double-braces}} = a slot filled from the BA's answers.
  - `<!-- gate: <id> -->` ties a section to an authoring-rubric gate
    (skills/harness-story-author/references/authoring-rubric.md); a slot the BA
    has not answered is ASKED, never guessed.
  - `<!-- ... -->` lines are guidance, stripped before writing to JIRA.

The shape is deliberately TABLE-DRIVEN. Prose acceptance criteria drift into
"works well"; a Given/When/Then row forces one decidable outcome per line, and
QA can lift the rows straight into test cases.

Override with: /harness-story-author "<intent>" --template <your-copy.md>
-->

# {{story_title}}
<!--
summary/title. A capability the user gains, prefixed with the epic tag and
suffixed with the owning area when the project uses that convention.
e.g. "[Stream Detection]Rule outbox + relay worker-(KAFKA/BE)".
-->

**Owner:** {{owner_role}} · **Points:** {{points}} · **Depends on:** {{dependencies_or_none}}
<!-- gate: dependencies-identified / invest-sizing -->
<!--
A single metadata line, first thing in the description — it is what a planner
reads before opening anything else. `Depends on:` lists upstream ticket keys, or
the literal "none". Points are a rough size; if the story is not yet sizable,
say so here and explain why in Notes & Risks rather than inventing a number.
-->

> {{blocking_callout_or_omit}}
<!--
OPTIONAL blockquote, only when the story genuinely cannot start. Name WHAT
blocks it and point at the detail.
e.g. "> **BLOCKED ON DECISIONS #4 AND #6.** Settle both before starting — see
Notes & Risks. #6 is a contract decision with DMP, not a style preference."
Omit the whole blockquote when nothing blocks the story. Never leave it empty.
-->

## User Story
<!-- gate: story-format / goal-value-clear -->
**As a** {{role}}, **I want to** {{capability}},
**So that** {{benefit}}.
<!--
Write the benefit as the consequence the user avoids or gains, not a restatement
of the capability. If a user-story shape genuinely does not fit (pure infra),
state the outcome and why it matters instead — and say which it is.
-->

## Summary
<!-- gate: goal-value-clear / scope-boundaries -->
{{summary_paragraph}}
<!--
One or two paragraphs carrying what the tables cannot:
  - the CORE BUSINESS RULE every design choice follows from, stated once, plainly
    (e.g. "a broker outage must degrade into delivery lag, never a lost assignment");
  - what is in this story and what is deliberately left out;
  - a sizing warning when the story looks like a reuse but is new construction.
This is the paragraph an engineer reads to know whether their plan is the right
shape. Do not restate the title here.
-->

## Acceptance Criteria Table
<!-- gate: ac-present-testable / ac-covers-happy-path -->

| Scenario | Given (Context) | When (Action) | Then (Expected Outcome / Requirement) |
| --- | --- | --- | --- |
| {{scenario_name}} | {{given}} | {{when}} | {{then}} |

<!--
One row per criterion, each decidable Yes/No by a person or a test. Together the
rows must cover the main success path end to end (trigger -> action -> result);
`ac-covers-happy-path` fails if they only cover fragments.
Scenario names are short labels, not sentences — they become the test names.
A decision that must be settled before work starts is also a row
("Encoding settled before start | ... | Work is scheduled | Open question #6 is
settled before implementation begins").
-->

## Positive Scenarios
<!-- gate: ac-covers-happy-path -->

| # | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| {{n}} | {{scenario}} | {{steps}} | {{expected_result}} |

<!--
The walkable happy paths — concrete steps someone can execute in order, and the
observable result. Where the AC table states the rule, this states the run.
Reference real field names and values so the row is executable without asking.
-->

## Negative Scenarios
<!-- gate: edge-error-states -->

| # | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| {{n}} | {{scenario}} | {{steps}} | {{expected_result}} |

<!--
Two kinds of row belong here, and both matter:
  1. RUNTIME failure — error / empty / loading / permission-denied / outage
     behaviour, with the expected result stated as behaviour, not a stack trace.
  2. PLANNING failure — a wrong way to build or size the story, marked
     "Defect —" / "Wrong —" / "Blocked —" with the reason.
     e.g. "Sized as a reuse | The story is planned as 'hook into the existing
     outbox' | Wrong — that path shares no machinery with this. New work; size
     accordingly."
Kind 2 is what stops an engineer implementing the story correctly against the
wrong assumption. If a failure mode is genuinely out of scope, say
"out of scope: <why>" rather than dropping the row.
-->

## Contract & Schema Requirements
<!-- gate: data-validation-rules -->

| Item | Type | Required | Rules / Constraints |
| --- | --- | --- | --- |
| {{item}} | {{item_type}} | {{required}} | {{rules}} |

<!--
Every new or changed input, field, record value, endpoint, constraint or
contract decision. `Type` is what the row IS (Field / Constraint / Removal
signal / Contract decision), not only a data type. `Required` is Yes/No, or
"**Yes — blocking**" for a decision that gates the work.
`Rules / Constraints` carries type, limits, format, default, and where the value
comes from (e.g. "From DPD-836 — lets the job order an update").
Write "n/a — no new inputs or contract changes" if the story truly has none.
-->

## Notes & Risks
<!-- gate: no-ambiguous-wording / nonfunctional-stated / design-reference -->
{{notes_and_risks_bullets}}
<!--
Bullets, each standing alone:
  - **Blocking decision #N — <name>.** The options, the current lean, and who
    owns settling it. One bullet per open decision named in the blockquote.
  - Why the sizing is what it is, especially when it contradicts an assumption.
  - The core business rule restated as a rule, when it is easy to lose.
  - Companion tickets that must ship WITH this one, not after it.
  - Non-functional expectations (perf, security/permissions, a11y, i18n,
    analytics) when the story carries money, PII, auth or bulk data.
  - **Design:** {{design_link_or_none}} — a link for UI work, or "no UI change".
No `TBD` / `???` / "etc." anywhere in the description: an unresolved item is a
question for the BA during authoring, or an explicit bullet here naming who
resolves it.
-->
