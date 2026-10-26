<!--
ba-uat :: UAT CHECKLIST template (for the client / business tester)
Plain business language only: what to do, what you should see.
No endpoints, status codes, dev tools, database checks, or test-case jargon.
HTML comments are guidance and are stripped before saving or publishing.
-->

# Acceptance checklist — {{run_title}}

**Version / sprint:** {{version_or_sprint_or_omit}} · **Prepared:** {{date}} · **Covers:** {{ticket_keys}}

## Before you start

- {{account_or_role_to_log_in_with}}
- {{data_that_must_exist}}
<!-- e.g. "Log in as a Finance user at the test site", "Org Alpha has at least 120 September transactions".
Keep it to what the tester needs; no environment internals. -->

## How to use this checklist

Do each step in order. Tick **Pass** if you see what is described, **Fail** if
you do not, and write what you saw in **Comment** (a screenshot helps).

## {{flow_name}}
<!-- One section per user flow, in the order a real user goes through the work.
A flow may span several tickets. -->

| # | Scenario | What to do | What you should see | Pass | Fail | Comment | Ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| {{flow_n}}.{{n}} | {{scenario_in_business_words}} | {{plain_actions}} | {{visible_result}} | ☐ | ☐ | | {{key}} |

<!-- Ref is the ticket key, for traceability; the tester can ignore it. -->

## Not included in this round

- {{scenario}} — {{plain_reason}}
<!-- Items under "Cannot test yet" in the QA file, in plain words
("Large-file limit — the rule is still being decided"). Delete when empty. -->

## Sign-off

| | |
| --- | --- |
| **Tester name** | |
| **Role / company** | |
| **Date tested** | |
| **Decision** | ☐ Accept · ☐ Accept with issues · ☐ Reject |
| **Issues to fix before go-live** (if "Accept with issues") | |
| **Signature** | |

<!-- Accept = everything passed. Accept with issues = go live, the listed failures are fixed after.
Reject = do not go live until the failures are fixed and re-tested. -->
