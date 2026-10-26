# Feature spec template (step 2)

Fill every section the input answers. A section that does not apply says so in
one line with the reason (`No UI — this is a nightly batch job.`); never leave
an empty heading or `n/a`. All `{{...}}` slots must be replaced; no `TBD`,
`???` or `etc.` may remain.

Strip this preamble and the HTML comments when rendering.

````markdown
# {{Feature name}}: feature spec

**Project:** {{KEY}} · **Status:** {{Draft / In review / Agreed}} · **Owner:** {{BA name}} · **Updated:** {{YYYY-MM-DD}} · **Source:** {{brief path or page URL or "idea"}}

## 1. Overview

**Problem.** {{who suffers what today, with a number when known}}

**Goal.** {{the outcome after this ships}}

**Success metrics**

| Metric | Today | Target | How measured |
| --- | --- | --- | --- |
| {{report requests to Support}} | {{40 / month}} | {{under 5 / month}} | {{Support ticket tag count}} |

## 2. Users & personas

| Persona | Role in the product | Goal in this feature | Permissions |
| --- | --- | --- | --- |
| {{Finance analyst}} | {{Finance role}} | {{export for reconciliation}} | {{view + export}} |

## 3. Scope

**In**
- {{item}}

**Out**
- {{item}} — {{why, or where it goes}}

**Later**
- {{item}} — {{target phase or quarter}}

## 4. User flows
<!-- One subsection per flow. Steps numbered. Every flow has an end state and at least one error path. -->

### F-1 {{flow name}}

**Actor:** {{persona}} · **Starts when:** {{trigger}}

1. {{step}}
2. {{step}}

**End state:** {{what is true when the flow succeeds}}

**Error paths**
- At step {{n}}, if {{condition}}: {{what the user sees and what happens}}

<!-- Optional, when the flow branches -->
```mermaid
flowchart TD
  A[{{step}}] --> B{{{decision}}}
  B -- yes --> C[{{end state}}]
  B -- no --> D[{{error path}}]
```

## 5. Business rules
<!-- Testable: a condition and an outcome a tester can check Yes/No. -->

| ID | Rule | Applies to | Source |
| --- | --- | --- | --- |
| BR-1 | {{When X, then Y}} | {{F-n / screen / field}} | {{R-n / BA answer, date}} |

## 6. Data

| Entity | Field | Required | Rules | Default | Source |
| --- | --- | --- | --- | --- | --- |
| {{Export record}} | {{Requested by}} | {{Yes / No / Yes, when ...}} | {{format, length, allowed values, uniqueness, retention}} | {{default or "none"}} | {{user input / system / other system name}} |

## 7. Screens / UI
- {{screen name}} — {{design link}} — {{states: loading / empty / error}}

## 8. Non-functional
<!-- Only the rows that apply. Each with a number or a named role. -->

| Area | Requirement |
| --- | --- |
| Performance | {{an export of one month of data finishes in under 30 s}} |
| Security / permissions | {{only Finance and Support roles can export}} |
| Audit | {{every export is recorded with who, when, filters}} |
| i18n | {{Vietnamese characters preserved in exported names}} |
| Accessibility | {{export button reachable by keyboard}} |

## 9. Integrations & dependencies

| System / team | What we need | Direction | Status |
| --- | --- | --- | --- |
| {{Audit service}} | {{store export records}} | {{out}} | {{agreed / to request}} |

## 10. Rollout & migration
- **Release:** {{all at once / behind a flag / by tenant}}
- **Migration:** {{existing data to move, or "none — new data only"}}
- **Communication:** {{who is told, how}}

## 11. Risks

| Risk | Impact | Mitigation | Owner |
| --- | --- | --- | --- |
| {{risk}} | {{High / Medium / Low}} | {{mitigation}} | {{name}} |

## 12. Open questions

| # | Question | Owner | Blocks |
| --- | --- | --- | --- |
| Q-1 | {{decision-shaped question with options}} | {{name}} | {{BR-n / F-n / section}} |

## 13. Traceability

| Requirement | Covered by | Note |
| --- | --- | --- |
| R-1 {{need}} | {{F-1, BR-2, §6}} | |
| R-5 {{need}} | Dropped | {{reason, who agreed}} |
````

## Rules for filling

- **IDs are stable.** Revise mode and re-runs keep existing BR / F / Q numbers;
  new items take the next number; a removed rule keeps its number struck
  through with the reason, so links from tickets stay valid.
- **Source column.** Every BR cites an `R-n` from the brief, a BA answer with
  a date, or an existing page section. Nothing is uncited.
- **Data.** One row per field users enter, see, or that another team depends
  on. Field names are the names users see.
- **Idea input** (no brief): Traceability lists the needs stated in the idea
  as `I-1..` with the idea text quoted, in place of `R-n`.
- **Revise mode:** keep the page's own headings that are not in this template
  under their original names after section 13; never delete them silently.
