<!--
ba-ticket (default mode) :: default STORY (child ticket) template
==============================================================
The DEFAULT format ba-ticket fills in (without --draft) when authoring a single Story,
or each child story proposed under an Epic. It is modelled on a real,
well-shaped story (secuw.atlassian.net/browse/DPD-838), the sibling of the epic
that epic.md is modelled on (DPD-832).

Same conventions as epic.md:
  - `## Heading` = a required section of the description.
  - {{double-braces}} = a slot filled from the BA's answers.
  - `<!-- gate: <id> -->` ties a section to an authoring-rubric gate
    (skills/ba-ticket/references/full/authoring-rubric.md); a slot the BA
    has not answered is ASKED, never guessed.
  - `<!-- ... -->` lines are guidance, stripped before writing to JIRA.

The shape is deliberately TABLE-DRIVEN. Prose acceptance criteria drift into
"works well"; a Given/When/Then row forces one decidable outcome per line, and
QA can lift the rows straight into test cases.

Override with: /ba-ticket "<intent>" --template <your-copy.md>
-->

# {{story_title}}
<!--
summary/title. A capability the user gains, prefixed with the epic tag and
suffixed with the owning area when the project uses that convention.
e.g. "[Stream Detection]Rule outbox + relay worker-(KAFKA/BE)".
-->

**Epic:** {{epic_key_or_none}} · **Teams:** {{teams}} · **Points:** {{points}}
<!-- gate: invest-sizing -->
<!--
A single metadata line, first thing in the description — it is what a planner
reads before opening anything else. `Epic:` is the parent key, or "none".
`Teams:` lists every build team plus any team with a note below (FE / BE /
Data / AI / QA), the LEAD team first — the one that drives the story and the
one the epic's Team split groups it under; there is no separate Owner.
`## Notes per team` carries one line per team listed here. Dependencies live
under `## Scope`, not here.
Points are a rough size, 1 / 2 / 3 / 5 and never more: a
story that needs more than 5 is split into two (`invest-sizing`). If the story
is not yet sizable, say so here and explain why in Notes & Risks rather than
inventing a number.
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
{{context_lines_or_none}}
<!--
Write the benefit as the consequence the user avoids or gains, not a restatement
of the capability. Below it, at most two lines of context: what happens today
and why it hurts ("Today the header checkbox selects only the 20 rows on the
current page."). If a user-story shape genuinely does not fit (pure infra),
state the outcome and why it matters instead — and say which it is.
-->

## Scope
<!-- gate: scope-boundaries / dependencies-identified -->
**In:**
- {{in_scope}}

**Out:**
- {{out_of_scope}}

**Dependencies:**
- {{dependencies_or_none}}
<!--
Bullets, not prose. "In" lists what this story delivers, one capability per
bullet. "Out" lists what a reader might expect but is deliberately left out,
each with where it goes instead: "later story", "DPD-123", "not planned".
"Dependencies" lists what must exist or be settled BEFORE this story can be
built: upstream ticket keys, another team's API or data, a feature flag, a
schema or decision not yet final, a design still to be delivered — or the
literal "none". This is the only place a dependency is written. A ticket that
ships WITH this one (not before) is a companion, listed in `## Notes & Risks`.
The core business rule every design choice follows from, and a sizing warning
when the story looks like a reuse but is new construction, belong in
`## Notes & Risks`, not here.
-->

## Assumptions
<!-- gate: assumptions-confirmed -->
{{assumptions_bullets_or_none}}
<!--
Things the story takes as true but nobody has confirmed yet, one bullet each,
marked with who confirmed it ("— confirmed by <BA>") once they do. Each
unconfirmed bullet is asked to the BA during authoring. Write "None" when the
story rests on no assumption.
-->


## Acceptance Criteria Table
<!-- gate: ac-present-testable / ac-covers-happy-path -->

| # | Scenario | Given (Context) | When (Action) | Then (Expected Outcome / Requirement) |
| --- | --- | --- | --- | --- |
| {{n}} | {{scenario_name}} | {{given}} | {{when}} | {{then}} |

<!--
One row per criterion, each decidable Yes/No by a person or a test. Together the
rows must cover the main success path end to end (trigger -> action -> result);
`ac-covers-happy-path` fails if they only cover fragments.
`#` is 1, 2, 3 ... in order; AC rows are referenced by it (AC-1, AC-2) from the
scenarios, test cases and the UAT checklist.
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

## Notes per team
<!-- gate: design-reference -->
<!--
Only the teams in **Teams:**. Write what the BA knows and that ONE team needs
to build or test; leave the "how" to the team. A note that only one team acts
on belongs here; a note that changes the plan for everyone belongs in
`## Notes & Risks`. Say each thing once: the design link lives ONLY on the FE
line, a dependency ONLY under `## Scope` > Dependencies, an unresolved item ONLY as an
"Open —" bullet in Notes & Risks.
This is the ONLY section where code names (APIs, endpoints, tables, audit
keys) may appear, and only in the BE / FE lines.
  FE   screens, states (loading / empty / error), exact copy, and the design
       link — a URL, "mockup needed", or "no UI change" (gate design-reference)
  BE   business rules, data in / out, permissions, limits
  Data fields, source of truth, retention, which report / dashboard uses it
  AI   expected behaviour with a good and a bad example, the quality bar
  QA   test data to prepare, what must not regress
Delete a line for a team not in **Teams:**; never leave an empty one.
-->
- **FE:** {{screens_states_copy_design_link}}
- **BE:** {{business_rules_data_in_out_permissions}}
- **Data:** {{fields_source_retention_reports}}
- **AI:** {{expected_behaviour_good_and_bad_examples_quality_bar}}
- **QA:** {{test_data_and_what_to_regress}}

## Notes & Risks
<!-- gate: no-ambiguous-wording / nonfunctional-stated -->
{{notes_and_risks_bullets}}
<!--
What the WHOLE team needs to plan correctly. Bullets, each standing alone:
  - **Blocking decision #N — <name>.** The options, the current lean, and who
    owns settling it. One bullet per open decision named in the blockquote.
  - **Open — <topic>.** An unresolved item that does not block the start, with
    who resolves it. This is the only place open items live.
  - Why the sizing is what it is, especially when it contradicts an assumption.
  - The core business rule restated as a rule, when it is easy to lose.
  - Companion tickets that must ship WITH this one, not after it (a ticket
    that must ship BEFORE goes under `## Scope` > Dependencies, not here).
  - Non-functional expectations (perf, security/permissions, a11y, i18n,
    analytics) when the story carries money, PII, auth or bulk data.
Write the decision, not its history: "Compromised has four states, never
three; do not write a tri-state test", not the date, author and comment number
of the amendment — those stay in JIRA. Nothing here repeats a Notes per team
line or the design link.
No `TBD` / `???` / "etc." anywhere in the description: an unresolved item is a
question for the BA during authoring, or an "Open —" bullet here naming who
resolves it.
-->
