<!--
harness-ba-ticket :: EPIC template
Target: one screen. The epic says WHY and WHAT "done" looks like; each story
under it carries the detail. {{slots}} are filled from the BA's intent and
answers. HTML comments are guidance and are stripped before the epic goes to JIRA.
Override with: /harness-ba-ticket "<intent>" --epic --template <your-copy.md>
-->

# [{{area}}] {{title}}
<!-- Format: [Area] Capability. No team tag on an epic. e.g. "[Admin Portal] Organization onboarding" -->

**Teams:** {{teams}} · **Design:** {{design_link_or_none}}

## Why
{{problem_today}}
{{what_changes_for_the_user}}
<!-- 2-4 lines: the pain today, who feels it, and what is different after this epic.
Plain words only: no API names, tables, file paths or counts of code. Those live in the stories' BE / FE notes. -->

## Done when
- {{observable_outcome}}
<!-- 3-5 bullets someone can watch happen and call done / not done. No "works well", "is fast". -->

## Scope
**In:**
- {{in_scope}}

**Out:**
- {{out_of_scope}} <!-- say where it goes instead -->

## Stories

| # | Story | Teams | Depends on |
| --- | --- | --- | --- |
| 1 | {{story_title}} | {{teams}} | {{depends_on_or_none}} |

<!-- Each row is one user-visible slice, not a layer ("the backend part"). Keys are filled in after creation. -->

## Open questions
<!-- Only decisions the BA could not settle during authoring. Delete the section when empty. -->

| # | Question | Owner |
| --- | --- | --- |
| 1 | {{question}} | {{owner}} |
