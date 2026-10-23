# harness-epic-verify

Check whether an **Epic** is clear enough to break into stories — and ask the BA
the missing questions from three angles: **backend**, **frontend**, and
**business**.

It is the Epic half of `harness-story-verify`. That skill judges one story
against a user-story rubric; this one judges an Epic against an epic rubric
(goal, definition of done, team split, critical path, dependencies, rollout) and
posts **one comment per lens**, so the backend thread and the frontend thread can
be answered independently.

---

## Quick start

```bash
# Verify an Epic and ask from all three lenses
/harness-epic-verify PROJ-100

# Only the backend and frontend angles
/harness-epic-verify PROJ-100 --lens be,fe

# Look first, touch nothing in JIRA
/harness-epic-verify PROJ-100 --report-only

# Verify the Epic, then run the child stories through harness-story-verify
/harness-epic-verify PROJ-100 --with-children
```

Nothing is written to JIRA until you approve — and you approve **per lens**.

---

## What happens on a run

1. **Fetch + inventory** — reads the Epic, confirms it is an Epic (a Story gets
   routed to `/harness-story-verify`), and lists the children by type and role.
2. **Score** — 12 epic gates, 8 blocking and 4 advisory, each backed by quoted
   evidence from the Epic. A missing section is never filled in with a guess.
3. **Three lenses** — every failing gate is turned into questions from the BE, FE,
   and BA angles. A lens with nothing to ask stays empty.
4. **Report** — the verdict, the failing gates, and the exact questions grouped by
   lens, before anything is sent.
5. **Approve + post** — you pick which lenses to send. Each becomes one comment.
6. **Handoff** — the Epic is @mentioned to its reporter, assigned to them, and
   moved to a clarification status.
7. **Track** — each lens thread is watched for a reply, folded back in, and
   re-scored on its own.

---

## The reporter handoff

When a lens comment posts, the Epic goes back to the person who has to answer it:

| Step | What it does | When it is skipped |
|------|--------------|--------------------|
| **Tag** | `[~accountid:…]` mention so the reporter is notified | No reporter → falls back to the display name |
| **Assign** | Assignee ← the reporter | No reporter, already assigned, or the field rejects it |
| **Status** | Moves to a clarification status | No matching transition on the workflow |

The status is never assumed. The skill reads the transitions the Epic actually
offers and takes the first of `Clarification`, `Waiting for BA`, `Needs Info`,
`In Review`. Override it with `--ask-status "In Review"`; if that exact status is
not available the transition is skipped and reported, never swapped for a
different one.

Turn the whole handoff off with `--no-handoff` — the comments still post.

Every skip is reported in one line, e.g.
*"assigned to Jamie Tran; status left at To Do (no clarification transition
available: In Progress, Done)."*

---

## Options

| Option | Description |
|--------|-------------|
| `--lens be,fe,ba` | Which angles to ask from (default: all three) |
| `--ask-status "<name>"` | Force the status the handoff moves to |
| `--no-handoff` | Comment only — never touch assignee or status |
| `--with-children` | Chain into `harness-story-verify` for the child stories |
| `--resume` | Re-check BA replies per lens and re-verify |
| `--report-only` | Verify and report; no JIRA writes at all |
| `--dry-run` | Walk the flow, write no state and no comments |

---

## When to use which skill

| You have | Use |
|----------|-----|
| An Epic to check before breaking it down | `harness-epic-verify` |
| One story, or a list of stories | `harness-story-verify` |
| An idea and no ticket yet | `harness-story-author` |
| A verified ticket to build | `harness-flow` |

---

## Requirements

- The Atlassian Rovo MCP tools (JIRA access). Without them the skill reports
  `not-configured` and stops at the first step that needs JIRA — it never
  guesses at ticket content.
- `jq` and `python3` for the record helper.

State lives in `.claude/state/epic-verify/<epic-key>/epic.json`
(`epic-verification.v1`), so a re-run resumes instead of re-asking.
