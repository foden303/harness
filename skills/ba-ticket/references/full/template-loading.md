# Template loading (Step 1)

The template is the BA's format, not the skill's. This step resolves which one to
use, parses its sections, and decides epic-vs-story and the target project.

## Resolution order

1. `--template <path>` — a local `.md` file. Read it verbatim.
2. `--template-confluence <url>` — fetch with
   `mcp__claude_ai_Atlassian_Rovo__getConfluencePage` and treat the page body as
   the template.
3. Default — `${HARNESS_PLUGIN_ROOT}/templates/ticket-authoring/epic.md` for an
   Epic, `story.md` for a Story.

If both `--template` and `--template-confluence` are passed, stop and ask which
one; do not silently prefer one.

## Parsing a template

Whatever the source, extract:

- **Sections** — every `## Heading`. These become the required sections of the
  issue description, in order.
- **Slots** — every `{{slot_name}}`. These are what the skill fills.
- **Gate tags** — every `<!-- gate: <id> -->`. The gate immediately following a
  heading binds that section to a rubric gate (see `authoring-rubric.md`). A
  section with no gate tag is filled best-effort and never blocks readiness.
- **Guidance comments** — any `<!-- ... -->` block. These are instructions to the
  author and are **stripped** before the description is written to JIRA.

A custom template need not use `{{slots}}` or gate tags at all. When it has none,
treat each `## Heading` as a section to fill from the intent, and apply the
default blocker gates (`goal-value-clear`, `ac-present-testable`,
`ac-covers-happy-path`, `scope-boundaries`) by meaning rather than by tag.

## Epic vs Story

- `--epic` / `--story` decides explicitly.
- Otherwise infer: language like "epic", "initiative", "break into stories",
  "several tickets", or a multi-deliverable intent → Epic; a single capability →
  Story. State the inference in one line and proceed (case: minor scope judgment,
  not a confirmation — `autonomous-confirmation-scope.md`). If genuinely
  ambiguous, ask once.

## Resolving the project + issue type

The draft cannot be created without a real project key and a valid issue type.

1. Project: `--project KEY`, else a key named in the intent, else ask via
   `AskUserQuestion` (never guess a project — creating in the wrong project is an
   external write in the wrong place). `getVisibleJiraProjects` can populate the
   options.
2. Issue type: confirm the type name ("Epic" / "Story" / "Task") exists in that
   project with
   `mcp__claude_ai_Atlassian_Rovo__getJiraProjectIssueTypesMetadata`. If "Epic"
   is absent (some team-managed projects rename it), pick the hierarchy-level-1
   type and note the substitution.
3. Record `project_key`, `cloud_id`, and `issue_type` into the draft.

Resolving metadata is a **read** — it needs no approval. Only `createJiraIssue`
in Step 5 does.
