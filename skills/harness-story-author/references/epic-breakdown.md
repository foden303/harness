# Epic breakdown (Step 4, epic mode only)

Once the epic draft is `ready`, propose the child stories that deliver it. This
is the `## Team split` table plus one drafted story per row. The operator keeps,
edits, or drops children **before** anything is created.

## Proposing the child set

Slice the epic into **INVEST** child stories — each an independently valuable,
one-sprint vertical slice, not a horizontal layer ("the backend part"). Group
them by the role that owns them, mirroring the default epic template:

| Key | Title | Points |
| --- | --- | --- |
| (blank until created) | Accept `stream` as a conversion backend | 2 |

- **Points** are a rough size (Fibonacci-ish), a hint not a commitment.
- **Key** stays blank in the draft; it is backfilled with the real JIRA key after
  creation (Step 5) via `editJiraIssue` on the epic.
- Derive dependencies into the epic's `## Critical path` (A → B → C), and surface
  genuinely unresolved cross-team decisions in `## Open questions` — do not invent
  a lean the BA never stated.

Size discipline: if a proposed child is obviously multi-sprint or bundles
unrelated deliverables, split it. If two children are trivially coupled, merge
them. Aim for children that would each pass `harness-story-verify` on their own.

## Drafting each child

For every proposed child, fill the **story template** (`story.md`) and score it
with the authoring rubric, exactly as for a standalone story. A child that has an
unfilled blocker gate is `needs-input` — batch those questions with the epic's
gap questions in Step 3 so the BA answers everything in one pass, not one prompt
per child.

Store children in the epic's draft record under `children[]`:

```json
{
  "mode": "epic",
  "title": "[Stream Detection] Rule Flow & OCSF Transition",
  "children": [
    {"local_id": "c1", "title": "Accept `stream` as a conversion backend",
     "role_group": "Backend Engineer", "points": 2,
     "body_markdown": "## Story\n…", "checks": [ … ], "readiness": "ready"},
    {"local_id": "c2", "title": "Sigma to OCSF matcher AST",
     "role_group": "Data Engineer", "points": 13,
     "body_markdown": "## Story\n…", "open_questions": [ … ], "readiness": "needs-input"}
  ]
}
```

`local_id` (`c1`, `c2`, …) is the stable handle used for the "pick which children
to create" prompt and for the critical-path chain before real keys exist.

## Showing the set for approval

Before Step 5, present the whole plan compactly so the operator can judge it as a
unit:

- the epic title + one-line goal + DoD;
- the child table (role group | title | points | readiness);
- any child still `needs-input`, flagged.

Then the Step 5 approval prompt (`create-jira.md`) offers: create the epic + all
`ready` children, let the operator pick a subset, edit first, or cancel. A child
left `needs-input` is not created unless the operator explicitly opts to author
it with its gap moved to an `> Open question:` note.

## Scale note

For an epic with **≥6 children**, drafting each child in-context is slow. Fan out
with `Task` — one read-only sub-agent per child, each filling the story template
and returning its draft JSON — then collect them into `children[]`. Fewer than 6:
draft in-context. Either way the operator sees one consolidated set, and no child
is created without the single Step-5 approval.
