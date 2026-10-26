<!--
ba-uat :: QA TEST CASE template
Filled per run. {{slots}} come from the parsed tickets (references/case-rules.md).
HTML comments are guidance and are stripped before saving or publishing.
One "## <KEY>" section per ticket, in input order.
-->

# Test cases — {{run_title}}

**Source:** {{source_refs}} · **Generated:** {{date}} · **Tickets:** {{ticket_count}} · **Cases:** {{case_count}}

<!-- source_refs: the keys, "Epic DPD-832 (5 stories)", "JQL: ...", or the spec file name. -->

## Coverage

| Ticket | AC rows covered | Fields covered | Edge cases covered | Roles covered | Cannot test yet |
| --- | --- | --- | --- | --- | --- |
| {{key}} | {{ac_covered}} / {{ac_total}} | {{fields_covered}} / {{fields_total}} | {{edge_covered}} / {{edge_total}} | {{roles_covered}} / {{roles_total}} | {{cannot_test_count}} |

## {{key}} — {{ticket_title}}

**Roles:** {{roles_or_none}} · **Assumptions:** {{operator_confirmed_assumptions_or_none}}

| ID | Title | Traces to | Preconditions | Steps | Test data | Expected result | Type |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TC-{{key}}-{{n}} | {{title}} | {{AC-n / F-field (boundary) / E-n / Role: name}} | {{preconditions}} | 1. {{step}}<br>2. {{step}} | {{concrete_values}} | {{expected_from_ticket}} | {{positive / negative / edge / permission}} |

<!--
Order: AC positives, field boundaries, edge/error negatives, permissions.
Steps use <br> between numbered steps so the table survives Confluence and JIRA.
Test data is concrete: real emails, exact lengths ("a × 51 = 51 chars"), dates, counts.
Expected result is copied from the ticket, quoting message text when the ticket gives it.
-->

## Cannot test yet

| Ticket | Row | Reason | Next step |
| --- | --- | --- | --- |
| {{key}} | {{AC-n / F-field / E-n}} | {{why_not_testable}} | `/ba-story-verify {{key}}` |

<!-- Delete this section when every row is testable. -->
