---
name: harness-epic-verify
description: "Verify that a BA-authored Epic is clear enough to break down and build, asking from three angles: backend, frontend, and business. Scores the Epic itself against an epic-level rubric (goal, definition of done, team split, critical path, dependencies), then drafts one comment per lens — BE questions, FE questions, BA questions — each approved separately before posting. On posting it hands the Epic back: mentions the reporter, assigns it to them, and moves the status to a clarification state. Read-only until you approve; it never plans, implements, or commits. Child stories are inventoried here and verified by harness-story-verify. Trigger: verify an epic, is this epic clear, epic clarity check, ask the BA about an epic, epic DoR check, EPIC-100 clear enough, verify epic from BE/FE/BA angle. Do NOT load for: verifying a single user story or ticket list (use harness-story-verify), authoring a new epic (use harness-story-author), implementing (use harness-flow), bug triage, code review, or release."
description-en: "Verify that a BA-authored Epic is clear enough to break down and build, asking from three angles: backend, frontend, and business. Scores the Epic itself against an epic-level rubric (goal, definition of done, team split, critical path, dependencies), then drafts one comment per lens — BE questions, FE questions, BA questions — each approved separately before posting. On posting it hands the Epic back: mentions the reporter, assigns it to them, and moves the status to a clarification state. Read-only until you approve; it never plans, implements, or commits. Child stories are inventoried here and verified by harness-story-verify. Trigger: verify an epic, is this epic clear, epic clarity check, ask the BA about an epic, epic DoR check, EPIC-100 clear enough, verify epic from BE/FE/BA angle. Do NOT load for: verifying a single user story or ticket list (use harness-story-verify), authoring a new epic (use harness-story-author), implementing (use harness-flow), bug triage, code review, or release."
kind: workflow
purpose: "Verify ONE Epic against the epic rubric -> ask it from the BE, FE, and BA lenses -> operator approves each lens -> post one comment per lens + hand the Epic back to its reporter -> track replies per lens"
trigger: "verify an epic, epic clarity check, is this epic clear, ask the BA about an epic, epic DoR check"
shape: delegate
role: orchestrator
base: harness-story-verify
pair: harness-story-verify
owner: harness-core
since: "2026-08-11"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "AskUserQuestion", "ScheduleWakeup", "mcp__claude_ai_Atlassian_Rovo__*"]
argument-hint: "[<EPIC-KEY>|<url>] [--lens be,fe,ba] [--ask-status \"<name>\"] [--no-handoff] [--with-children] [--resume] [--report-only] [--dry-run]"
user-invocable: true
effort: high
---

# harness-epic-verify

The clarity gate for an **Epic**, before it is broken into stories:

> **Epic link → verify the Epic itself → ask it from the BE, FE, and BA lenses →
> operator approves each lens → post one comment per lens + hand the Epic back to
> its reporter → track each lens thread → re-verify.**

The Epic sibling of `harness-story-verify`. That skill judges a *story* against a
user-story rubric; this one judges an *Epic* against an epic rubric — goal,
definition of done, team split, critical path, dependencies — and asks about it
from the three angles that will have to build it.

| | harness-story-verify | harness-epic-verify |
|---|---|---|
| Unit | one story (or a list of stories) | **one Epic** |
| Rubric | 12 user-story gates | **12 epic gates** |
| Questions | one set, one comment | **three lenses, one comment each (BE / FE / BA)** |
| Children | n/a | inventoried, then handed to `harness-story-verify` |
| On posting | mention + assign + transition | mention + assign + transition (once per Epic) |

## Core contract (read first)

- **Read-only until you approve.** Fetching the Epic and scoring it writes
  nothing to JIRA. The external writes — comment, assignee, status — happen only
  on explicit approval (`.claude/rules/autonomous-confirmation-scope.md` case 1).
  Nothing auto-posts.
- **One lens = one comment = one thread.** BE, FE, and BA questions are never
  pooled into one comment. Each lens carries its own nonce, is approved
  separately, and is answered and re-verified independently. A lens with no
  questions produces no comment.
- **Questions must trace to a failing gate.** `epic-verify-record.sh` rejects a
  question citing a gate that did not fail, so the BA is never asked about
  something the Epic already answers.
- **No requirement invention.** A missing section is asked about, never
  filled in with a plausible guess.
- **Verify the Epic, not the children.** Child tickets are inventoried (count,
  keys, coverage of the DoD) but scored only by `harness-story-verify`. Use
  `--with-children` to chain into it after this run.
- **MCP dependency.** JIRA access uses the Atlassian Rovo MCP tools. Absent
  (headless/cron) → tri-state health reports `not-configured` and the skill
  pauses at the first step that needs it rather than guessing.
- **No HTML surface (yet).** `--html` exists on `harness-story-verify` only; the
  terminal report is this skill's surface.

## Quick Reference

| Input | Behavior |
|------|------|
| `/harness-epic-verify PROJ-100` | Verify the Epic, ask from all three lenses |
| `/harness-epic-verify https://<site>/browse/PROJ-100` | Same, from a URL |
| `/harness-epic-verify PROJ-100 --lens be,fe` | Only the backend and frontend lenses |
| `/harness-epic-verify PROJ-100 --ask-status "Waiting for BA"` | Force the status the handoff moves to |
| `/harness-epic-verify PROJ-100 --no-handoff` | Comment only; do not touch assignee or status |
| `/harness-epic-verify PROJ-100 --with-children` | After the Epic, run `harness-story-verify` on its children |
| `/harness-epic-verify --resume` | Re-check BA replies per lens, fold them in, re-verify |
| `/harness-epic-verify PROJ-100 --report-only` | Verify + report, never offer to post (no JIRA writes) |
| `/harness-epic-verify PROJ-100 --dry-run` | Walk the flow, write no state and no comments |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<EPIC-KEY>` / `<url>` | The Epic to verify | required (unless `--resume`) |
| `--lens be,fe,ba` | Which lenses to ask from | all three |
| `--ask-status "<name>"` | Status the handoff transitions to | matched from a candidate list |
| `--no-handoff` | Never change assignee or status | off (handoff on) |
| `--with-children` | Chain into `harness-story-verify` for the children | off |
| `--resume` | Re-check BA replies on the existing record | - |
| `--report-only` | Never post; output the report only | off |
| `--dry-run` | No state writes, no comments | off |

**Not an Epic?** If the ref resolves to a Story/Task/Bug, do not score it here —
say so and route to `/harness-story-verify <KEY>`. The reverse also holds:
`harness-story-verify` routes an Epic key back to this skill.

## Resolving the plugin bundle root

Same as `harness-story-verify`: resolve `HARNESS_PLUGIN_ROOT` from
`CLAUDE_PLUGIN_ROOT` (if it contains `scripts/`), else from `CLAUDE_SKILL_DIR`
(`${CLAUDE_SKILL_DIR}/../..`, or `../../..` for a mirror). Call only
`${HARNESS_PLUGIN_ROOT}/scripts/...`; keep state under the host project's
`.claude/state/epic-verify/`.

## State

One record per Epic: `.claude/state/epic-verify/<epic-id>/epic.json`
(`epic-verification.v1`), written **only** through
`${HARNESS_PLUGIN_ROOT}/scripts/epic-verify-record.sh`. `<epic-id>` is the Epic
key lowercased (`PROJ-100` → `proj-100`). Each lens thread lives in
`clarifications[]` keyed by lens; the handoff result lives in `handoff`.

```
[Step 0] Resolve + probe
  Resolve HARNESS_PLUGIN_ROOT.
  Probe MCP once:
    bash "${HARNESS_PLUGIN_ROOT}/scripts/flow-mcp-health.sh" --probe <result>
  not-configured / unreachable -> decision_needed.v1 and STOP. Never guess.
  |
  v
[Step 1] Fetch + expand      Reference: references/expansion.md
  getJiraIssue on the ref. Confirm issuetype is Epic — if not, route to
  harness-story-verify and stop. Inventory the children (parent, then the
  Epic Link fallback) for the coverage gate; never broaden the query.
  Report the Epic + child inventory BEFORE verifying.
  |
  v
[Step 2] Verify the Epic     Reference: references/epic-rubric.md
  12 gates (8 blocker + 4 advisory), each scored pass | fail | n-a(+note),
  each carrying the quoted evidence it rests on.
  |
  v
[Step 3] Lens pass           References: references/lens-be.md, lens-fe.md, lens-ba.md
  For each requested lens, walk its checklist against the failing gates and
  write questions tagged with that lens. A lens that finds nothing stays empty —
  do not manufacture a question to fill it.
  Persist with epic-verify-record.sh (it derives the verdict and rejects a
  question whose gate did not fail).
  |
  v
[Step 4] Report
  Verdict line, the gate table, then the questions grouped by lens exactly as
  they would be posted. --report-only -> STOP here.
  |
  v
[Step 5] Approve + post + handoff    Reference: references/lens-comment.md
  ONE AskUserQuestion listing every lens draft; the operator approves per lens.
  Per approved lens: addCommentToJiraIssue (reporter @mentioned).
  Then ONCE per Epic, unless --no-handoff:
    editJiraIssue     assignee = reporter
    transitionJiraIssue -> the status chosen by jira-status-match.sh
  A missing transition is a recorded skip, never a failure.
  |
  v
[Step 6] Track replies       Reference: references/lens-comment.md (resume section)
  ScheduleWakeup re-entry: re-fetch comments, match each lens thread via
  flow-ba-match.sh, fold replies in, re-run Steps 2-3 for the affected gates.
  All lenses answered + re-verify clear -> clear. Round cap 3 per lens -> escalated.
  |
  v
[Done] Summary + next action
  Report the verdict, per-lens state, and the handoff result. Then:
  --with-children -> run harness-story-verify on the child keys.
```

## Stop / pause conditions

| Condition | Response |
|-----------|----------|
| MCP not-configured / unreachable | `decision_needed.v1`, stop |
| Ref is not an Epic | Report the type, route to `/harness-story-verify <KEY>`, stop |
| Epic unreadable (permission) | Record verdict `blocked`, report, stop |
| Epic has zero children | Not fatal — `epic-team-split` / `epic-children-coverage` judge it; report the count |
| Operator declines a lens | That lens stays `skipped`; the draft stays in the report |
| Transition unavailable | Post + assign anyway, record `transition_skipped_reason`, say so in the summary |
| Reporter missing on the Epic | Skip the assign, record `assign_skipped_reason`, still post and still transition |
| Round cap (3) reached on a lens | That lens `escalated` → `decision_needed.v1` |

## Silence policy

Report on: the Epic + child inventory, the verdict and failing gates, the full
lens drafts before approval, what was posted, the handoff result (assignee +
status, or why skipped), replies folded in, the final summary. Stay silent on:
per-gate scoring narration, quiet reply-poll waits. Always end a completed run by
naming the verdict, the per-lens state, and the next action.

## Related skills

- `harness-story-verify` — verify the child stories once the Epic is clear
- `harness-story-author` — the inverse: author an Epic from a template
- `harness-flow` — build a ticket once it is verified clear
- `harness-plan` — turn verified stories into Plans.md tasks
