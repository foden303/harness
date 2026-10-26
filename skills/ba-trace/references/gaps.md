# Gaps and coverage (step 3)

## Gap rules

Check every rule. A gap carries: id, what is missing, the evidence (or the
absence searched), a suggested action, and the skill to run.

| # | Gap | Rule | Suggested action | Skill |
|---|-----|------|------------------|-------|
| G1 | Requirement with no ticket | R-n linked to no ticket (after the step-1 questions) | Write a ticket for it | `/ba-ticket "<R-n text>" --epic-key <EPIC>` |
| G2 | Done with no commit | Status category done, zero commits found | Ask the assignee where it was built (other repo, no key in commits) or whether it was dropped | `/ba-trace --repo <other repo>`, or ask on the ticket |
| G3 | Commits but still To Do | Status category to-do, one or more commits | Move the ticket to its real status, or check the commits are mislabelled | (status update by the team) |
| G4 | AC with no test | Requirement row with no test match (key, R-n, wording or ba-uat) | Write test cases | `/ba-uat <KEY>` |
| G5 | Orphan ticket | Ticket in scope traced to no requirement (only when `--brief` is given) | Link it to a requirement, add the requirement to the brief, or drop it | `/ba-story-verify <KEY>` or update the brief |
| G6 | Ticket has no AC | No AC rows found | Add acceptance criteria | `/ba-ticket <KEY>` (rewrite) |
| G7 | Failed UAT | A UAT checklist item for the requirement is marked Fail | Fix and re-run UAT | `/harness-bugfix` then `/ba-uat --refresh` |

Suppression, so the gap list is not noise:

- G2 and G3 are **not** raised when the commit source is `not-configured`
  (the repo carries no keys at all). The summary says that once instead.
- G4 is **not** raised when there is no test source at all (no test files and no
  ba-uat state); the summary says "no tests found in this repo" once.
- G7 needs recorded UAT; with no ba-uat state it is never raised.
- A ticket in status category done with commits only on a non-default branch is
  not G2; note "commits not merged to <default branch>" in the row instead (check
  with `git branch --all --contains <hash>`).

## Coverage

Three percentages over the requirements in scope:

| Metric | Numerator |
|--------|-----------|
| with ticket | requirements linked to at least one ticket |
| with commit | requirements whose tickets have at least one commit |
| with test | requirements with at least one test match |

Plus, when recorded: UAT passed = requirements whose latest UAT result is pass.

Rules:

- A metric whose source is `not-configured` or `unreachable` is shown as
  `n/a (<reason>)`, never `0%`. Example: "with commit: n/a — no commit in this
  repo mentions any JIRA key".
- Show counts with the percentage: `7 / 9 (78%)`.
- Wording-only test matches count, but the line says how many are wording-only.
- Without a brief (AC rows as requirements), "with ticket" is always 100% and is
  shown as `— (requirements come from tickets)`.

## Ordering

List gaps by impact: G1, G2, G7, G4, G3, G6, G5. Within a type, by ticket key.
