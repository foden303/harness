# Discovery brief template (step 5)

Fill every section the sources answer. Delete a section that has nothing to
say only when the sources are silent on it, and say so in the Summary
("No constraints were mentioned"). `{{...}}` slots must all be replaced; no
`TBD`, `???` or `etc.` may remain.

Strip this preamble and the HTML comments when rendering.

```markdown
# Discovery brief: {{topic}}

**Project:** {{KEY or "not set"}} · **Sources:** {{n}} read, {{n}} skipped · **Date:** {{YYYY-MM-DD}} · **Prepared by:** {{BA name or "ba-discovery"}}

## Summary
<!-- 3-5 lines: what the client wants, why, the biggest decision still open. -->
{{summary}}

## Sources

| # | Source | Kind | Lines | Status |
| --- | --- | --- | --- | --- |
| 1 | {{path or page}} | {{transcript / notes / email / page}} | {{n}} | {{read / skipped: why}} |

## Stakeholders

| Name / role | Cares about | Decides |
| --- | --- | --- |
| {{Lan, Head of Finance}} | {{monthly reconciliation}} | {{scope, priority}} |

## Goals
<!-- Outcomes, with a number when a source gave one. Each cites a source. -->
- {{goal}} — {{source:L}}

## Problems today
- {{problem}} — {{source:L}}

## Requirements

| ID | Need | Type | Source quote | Who · where | Priority |
| --- | --- | --- | --- | --- | --- |
| R-1 | {{one-line need}} | {{functional / non-functional / rule / question}} | "{{verbatim quote}}" | {{speaker}} · {{source:L}} | {{Must / Should / Could / Won't, or "ask <owner>"}} |

## Business rules
<!-- Each rule cites its R-n and source. Testable wording: a number, a role, a condition. -->
- **BR-1** {{rule}} — R-{{n}}, {{source:L}}

## Constraints
- {{constraint}} — {{source:L}}

## Decisions

| # | Decision | Decided by | Source |
| --- | --- | --- | --- |
| D-1 | {{decision}} | {{name}} | {{source:L or "BA answer, date"}} |

## Assumptions (to confirm)

| # | Assumption | Confirm with | Source |
| --- | --- | --- | --- |
| A-1 | {{assumption}} | {{owner}} | {{source:L}} |

## Conflicts

| # | Topic | A says | B says | Resolution |
| --- | --- | --- | --- | --- |
| C-1 | {{topic}} | "{{quote}}" ({{speaker}}, {{source:L}}) | "{{quote}}" ({{speaker}}, {{source:L}}) | {{BA answer, date / open → Q-n}} |

## Open questions

| # | Question | Owner | Blocks |
| --- | --- | --- | --- |
| Q-1 | {{decision-shaped question with options}} | {{name}} | {{R-n / BR-n / next step}} |

## Out of scope
- {{item}} — {{"phase 2" / "not planned"}}, {{source:L}}

## Suggested next step
{{one line why}}

`{{exact command}}`
```

## Rules for filling

- **Requirements**: every row has a quote and a citation. Answers from the BA
  in step 4 are added as a second citation (`BA answer, 2026-10-26`), never as
  the only one; a need that exists only in a BA answer belongs in Decisions.
- **Priority**: as stated by a speaker, or the BA's step-4 answer; otherwise
  `ask <owner>` and a matching Q-n.
- **Conflicts**: a resolved conflict keeps both quotes and shows the
  resolution; the losing side is not deleted.
- **Open questions**: every Q-n has an owner and says what it blocks. No owner
  known → ask the BA who owns it in step 4.
- **Suggested next step**: see `publish.md` (Choosing the next skill).
