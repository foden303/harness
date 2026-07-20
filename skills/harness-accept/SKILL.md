---
name: harness-accept
description: "Generate an Acceptance Demo HTML for non-engineer vibecoders right before ship/wait/reject decision. Reads back the acceptance_criteria that were stored as personal-preference.v1 by harness-plan-brief (joined by user_request_hash), then renders a single-file HTML showing each criterion as verified or unverified along with a ship/wait/reject recommendation. Use when the user asks for an acceptance review, wants to decide whether to ship a delivered task, or says: acceptance demo, accept demo, acceptance decision, acceptance review, ship/wait/reject decision, inspection review. Do NOT load for: implementation, code review, release work."
description-en: "Generate an Acceptance Demo HTML for non-engineer vibecoders right before ship/wait/reject decision. Reads back the acceptance_criteria that were stored as personal-preference.v1 by harness-plan-brief (joined by user_request_hash), then renders a single-file HTML showing each criterion as verified or unverified along with a ship/wait/reject recommendation. Use when the user asks for an acceptance review, wants to decide whether to ship a delivered task, or says: acceptance demo, accept demo, acceptance decision, acceptance review, ship/wait/reject decision, inspection review. Do NOT load for: implementation, code review, release work."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[task-description]"
user-invocable: true
---

# harness-accept

A skill that presents the acceptance decision (ship / wait / reject) for a completed task on **a single HTML page**, aimed at non-engineer clients and producer roles.
Used at the client's cognitive-load peak (3): the acceptance-decision stage.

It operates as the paired structure of Phase 65.1.x (`harness-plan-brief`), reading back the `acceptance_criteria` approved in the Plan Brief on the read side to evaluate them.

## Quick Reference

- "**Create an Acceptance Demo**" → this skill
- "**I want to make an acceptance decision**" → this skill
- "**ship/wait/reject decision**" → this skill

## Responsibility boundary

| Scope | This skill's responsibility |
|------|-----------------|
| Search | **Current project only** (always specify `project: <current>`, `strict_project: true`) |
| Cross-project | **Do not** (opened as opt-in via the `--cross-project-group <name>` flag from Phase 65.3 onward) |
| Plan Brief integration | Read `personal-preference.v1` (Phase 65.1.4) using `user_request_hash` as the join key |
| Writing | Do not (the memory write after acceptance approval is the responsibility of `accept-record-decision.sh`) |
| Recommendation calculation | Judge by the ratio of verified / total criteria against the 0.8 / 0.5 thresholds. The logic is computed right before `scripts/render-html.sh` |

## Input

Pass the user's request in the `[task-description]` argument (use the same text as at Plan Brief time).
If no argument is given, receive it interactively.

## Output

| Output | Path | Format |
|------|------|------|
| Acceptance Demo HTML | `.claude/state/views/accept-<timestamp>.html` | Standalone HTML (no server, no JS framework) |
| Acceptance context JSON | `.claude/state/views/accept-<timestamp>.context.json` | `acceptance-context.v1` schema |

## Schema: `acceptance-context.v1`

```json
{
  "schema": "acceptance-context.v1",
  "user_request": "string",
  "user_request_hash": "sha256 hex (joined with the Plan Brief side personal-preference.v1)",
  "demo_artifacts": [
    { "kind": "video|screenshot|text", "path": "string" }
  ],
  "verified_criteria": [
    { "name": "string", "passed": true, "evidence": "string" }
  ],
  "tdd_verified": "yes|no|not-required|skip:<reason>",
  "unverified_caveats": ["string"],
  "past_issue_patterns": [
    { "pattern_id": "P5", "title": "string", "verified_in_current_task": true }
  ],
  "recommendation": "ship|wait|reject",
  "recommendation_evidence": ["string"],
  "project": "string",
  "generated_at": "ISO8601"
}
```

For the complete schema, see [`schemas/acceptance-context.v1.schema.json`](${CLAUDE_SKILL_DIR}/schemas/acceptance-context.v1.schema.json).

## Recommendation calculation logic

```
verified_count    = count of verified_criteria where passed=true
total_criteria    = count of verified_criteria
ratio             = verified_count / total_criteria  (0 when total=0)

  ratio >= 0.8 → "ship"
  ratio >= 0.5 → "wait"
  ratio <  0.5 → "reject"
  total = 0    → "reject" (0 criteria means undecidable; reject on the safe side)
```

Leave the rationale as literal numbers in `recommendation_evidence`.
Example: `"verified 4 / 5 total (80%) → at or above the ship threshold"`

## Execution Flow

When the skill starts, Claude operates by the following steps.

### Step 1: Resolve project name and user_request_hash

```bash
PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)")"
USER_REQUEST_HASH="$(printf '%s' "$USER_REQUEST" | sha256sum | awk '{print $1}')"
```

If `PROJECT_NAME` is empty (outside git), use `current` as the default.

### Step 2: Search harness-mem **project-only** and retrieve the Plan Brief record (default)

When the `--cross-project-group <name>` flag is **absent** from the arguments (default behavior):

Call `mcp__harness__harness_mem_search` with the following parameters:

```
project: <PROJECT_NAME>
strict_project: true
tags: ["personal-preference", "plan-brief-approval"]
limit: 10
```

> **Important**: the `project` parameter is **required**. Specify `strict_project: true` and **never** perform a cross-project search.

Filter the retrieved records by `data.user_request_hash == <USER_REQUEST_HASH>` and pick the most recent one.
This holds the Plan Brief approval content (chosen_option / acceptance_criteria, etc.).

### Step 2 (alt): cross-project search (Phase 65.3.5 opt-in)

Only when the `--cross-project-group <name>` flag is **present** in the arguments, retrieve similar plan-brief-approval / acceptance-decision history from other projects in the cross group (D43 Option α):

```bash
MEMBERS_JSON="$(bash scripts/load-cross-project-groups.sh --group "<name>" 2>/dev/null)" || {
  echo "ERROR: cross-project group not found: <name>" >&2
  exit 1
}
```

If `MEMBERS_JSON` is `[]`, fall back to the default single-project search.

If `MEMBERS_JSON` is non-empty, issue one MCP search per member project:

```
for each project in MEMBERS_JSON:
  mcp__harness__harness_mem_search(
    project: <member>,
    strict_project: true,
    tags: ["personal-preference", "plan-brief-approval"],
    limit: 10
  )
```

Merge the results on the client side and filter by `data.user_request_hash == <USER_REQUEST_HASH>`.
Since a hash match generally originates from the same user request, duplicates across projects are rare, but dedupe by id just in case.

Because adopting a cross-project record may mix in chosen_option / acceptance_criteria from past unrelated cases, **always use the `--with-redaction` flag** when outputting the HTML:

```bash
bash scripts/render-html.sh --template accept ... --with-redaction
```

For details, see "Phase 65.3 implementation decisions (D43)" in `.claude/rules/cross-repo-handoff.md`.

### Step 3: Retrieve past issue patterns (Phase 65.2.2 delegation)

```bash
bash scripts/accept-past-issues.sh --project "$PROJECT_NAME" --task "$USER_REQUEST" > "$PAST_ISSUES_JSON"
```

This script semantic-searches patterns.md (P1-P33) and past `acceptance-context.v1` records and
returns up to 3 `past-issue.v1` items. Each has `verified_in_current_task: bool`.

### Step 4: Build verified_criteria

For each acceptance_criteria item from Plan Brief time, evaluate the current task's state.
The user (or Claude) presents the "evidence they verified," filling the `evidence` string.

If `evidence` is an empty string, a warning is shown on the HTML (DoD c).

For a task that requires TDD, always emit one line `TDD verified: yes|no` in the Acceptance Demo.
If TDD is not required or skipped, show `TDD verified: not-required` or `TDD verified: skip:<reason>`.
You can set `yes` only when you can confirm the Red evidence in `.claude/state/tdd-red-log/<task-id>.jsonl`, or literal failing test output.

### Step 5: Compute the recommendation

Decide ship / wait / reject following the "Recommendation calculation logic" above.

### Step 6: Generate the HTML

Call `scripts/render-html.sh` (Phase 65.1.1) with `templates/html/accept.html.template`:

```bash
bash scripts/render-html.sh \
  --template accept \
  --data "$CONTEXT_JSON" \
  --out "$HTML_OUT"
```

### Step 7: Auto-open in the browser

Reuse `scripts/plan-brief-open.sh` (a **general-purpose OS dispatcher** introduced in Phase 65.1.2):

```bash
bash scripts/plan-brief-open.sh "$HTML_OUT"
```

> **Note**: although the script name includes "plan-brief," it is actually a per-OS browser-open dispatcher and is kind-neutral.
> The name is historical because it was introduced earlier in Phase 65.1.2. It is reused for other purposes such as Layer 3 (final scan right before HTML).
> If the `BROWSER=true` env is set (CI environment), open is **skipped** and only the path is printed via `printf`.

### Step 8: Wait for the user's decision

Confirm "whether to adopt the ship / wait / reject recommendation or override it."
The memory write after the decision is the responsibility of a separate skill (`accept-record-decision.sh`, Phase 65.2.3).

## Behavior on failure

| Failure | Behavior |
|------|------|
| `mcp__harness__harness_mem_search` unreachable | Show a warning and continue with an empty `verified_criteria` array (recommendation = reject) |
| Plan Brief record not found | Emit a warning and continue with an empty `verified_criteria` array |
| `git rev-parse --show-toplevel` fails | Continue with `PROJECT_NAME=current` |
| `accept-past-issues.sh` fails | Continue with `past_issue_patterns: []` (best-effort) |
| `render-html.sh` fails | Output the error to stderr and exit 1 |

## Related

- `harness-plan-brief` (Phase 65.1.2) — the paired skill at the planning stage. This skill joins the Plan Brief's `personal-preference.v1` by `user_request_hash` to read
- `scripts/accept-past-issues.sh` (Phase 65.2.2) — retrieve past issue patterns (read side)
- `scripts/accept-record-decision.sh` (Phase 65.2.3) — write the approval memory (`acceptance-decision.v1`)
- `scripts/render-html.sh` (Phase 65.1.1) — the HTML template engine
- `scripts/plan-brief-open.sh` (Phase 65.1.2) — general-purpose OS browser dispatcher
- `harness-progress` skill (Phase 65.4.1) — the progress-management skill (the middle of the 3 surfaces)
