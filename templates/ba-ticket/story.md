<!--
harness-ba-ticket :: STORY template
Target: one screen, readable in two minutes by FE, BE, Data, AI and QA.
{{slots}} are filled from the BA's intent and answers. HTML comments are
guidance and are stripped before the ticket goes to JIRA.
Override with: /harness-ba-ticket "<intent>" --template <your-copy.md>
-->

# [{{area}}] [{{build_team_or_omit}}] {{title}}
<!--
Format: [Area] [Team] What the user can do after this ships.
e.g. "[Admin Portal] [BE] Export audit log API"   (one build team)
     "[Admin Portal] Invite a user into an organization"   (BE + FE ship it together)
[Team] is the one build team: FE, BE, Data or AI (QA is never a title tag).
When several build teams deliver ONE feature that only works once all of them
are done, keep one story, drop the team tag, and list the teams in **Teams:**.
Split per team only when each part can ship and be tested on its own.
-->

**Epic:** {{epic_key_or_none}} · **Teams:** {{teams}} · **Depends on:** {{depends_on_or_none}}

## Why
**As a** {{role}}, **I want to** {{capability}}, **so that** {{benefit}}.

{{context_1_to_2_lines}}
<!-- Only what the reader needs: the pain today, or the business rule that drives every choice. -->

## Scope
**In:**
- {{in_scope}}

**Out:**
- {{out_of_scope}} <!-- say where it goes instead: "later story", "DPD-123", "not planned" -->

## Acceptance criteria

| # | Given | When | Then |
| --- | --- | --- | --- |
| 1 | {{given}} | {{when}} | {{then}} |

<!-- One outcome per row, each checkable Yes/No. Row 1 is the main success path end to end.
Name the fields: "Admin enters email, first and last name (all required)". -->

## Fields

| Field | Required | Rules | Default / example |
| --- | --- | --- | --- |
| {{field}} | {{yes_no_or_when}} | {{format_length_allowed_values_uniqueness}} | {{default_or_example}} |

<!--
Every value a user enters, picks, or gets back from this story (form input,
API input, returned value). Required: "Yes", "No", or the condition
("Yes, when Owner = New owner"). Rules: format, length, allowed values,
uniqueness, who can see it. Group rows by form with a bold row when there are
several ("**Invite user**"). Write "None — no new inputs" if the story has none.
-->

## Edge & error cases

| # | Case | Expected |
| --- | --- | --- |
| 1 | {{case}} | {{expected}} |

<!-- Missing required field, invalid format, duplicate value, no permission, empty data, timeout/outage, limits.
Write "None — <why>" if truly none. -->

## Notes per team
<!-- Only the teams in **Teams:**. Write what the BA knows and needs; leave the "how" to the team.
This is the ONLY section where code names (APIs, endpoints, tables, audit keys) may appear, and only in the BE / FE lines. -->
- **FE:** {{screens_states_copy_design_link}}
- **BE:** {{business_rules_data_in_out_permissions}}
- **Data:** {{fields_source_retention_reports}}
- **AI:** {{expected_behaviour_good_and_bad_examples_quality_bar}}
- **QA:** {{test_data_and_what_to_regress}}

## Open questions
<!-- Only questions the BA could not answer during authoring. Delete the section when empty. -->

| # | Question | Owner |
| --- | --- | --- |
| 1 | {{question}} | {{owner}} |
