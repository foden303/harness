<!--
ba-release-notes :: NOTES template
Filled in step 5 from the classified, rewritten items.
HTML comments are guidance and are stripped before saving or publishing.
Delete any section that has no items ("No known issues" is fine as one line
under Known issues; empty New / Improved / Fixed / Action sections are removed).
-->

# {{product_name}} {{version_or_sprint}} — Release notes

**Released:** {{release_date}} · **Version:** {{version_or_sprint_name}} · **Audience:** {{client / internal / support}}

{{highlight_2_to_3_sentences}}
<!-- What matters most to this audience, in plain words. Lead with the biggest
user benefit. No counts of tickets, no team names. -->

## New

### {{group_name}}
- {{benefit_line}} ({{key_links}})

## Improved

### {{group_name}}
- {{benefit_line}} ({{key_links}})

## Fixed

- {{now_correct_behaviour}} ({{key_links}})
<!-- Fixed is a flat list unless it has more than 8 items; then group like New. -->

## Known issues

- {{what_the_user_may_notice}} — {{workaround_if_stated}} ({{key_link}})

## Action needed by users

- {{who}}: {{what_to_do}} {{by_when_if_stated}}
<!-- Only when an item requires the user to do something (sign in again, update
an app, change a setting). Delete the section otherwise. -->

## Internal
<!-- Only with --internal or --audience internal. Short, technical words allowed. -->
- {{internal_item}} ({{key_link}})

<!--
================ Audience variants ================

client (default)
  - Second person: "You can now ..."
  - Sections: highlight, New, Improved, Fixed, Known issues, Action needed.
  - No Internal section (unless --internal), no priorities, no team names.

support
  - Same items as client, plus for each New / Improved / Fixed line an
    indented "Users may ask:" line with the likely question and the answer
    from the ticket, e.g.
      - You can now export the filtered list to CSV (DPD-901, DPD-902)
        - Users may ask: "Why is Export greyed out?" — nothing matches the filter.
  - Known issues carry the workaround to give users, and who to escalate to
    when the ticket names one.
  - Adds a "Where to look" line per group only if the ticket names the screen.

internal (management / team)
  - Neutral voice: "Finance users can now ..."
  - Highlight adds the business outcome the Epic states (when it states one).
  - Internal section always included.
  - Adds a one-line count summary under the highlight:
    "New 4 · Improved 6 · Fixed 9 · Internal 7 · Held back 1".
-->
