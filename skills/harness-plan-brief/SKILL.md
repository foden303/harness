---
name: harness-plan-brief
description: "Generate a Plan Brief HTML for non-engineer vibecoders before implementation starts. Searches harness-mem (project-only) for relevant past decisions, patterns, and Plans archive entries, then renders a single-file HTML artifact summarizing understanding, options, risks, acceptance criteria, and confidence. Use when the user requests a planning preview, a non-engineer-friendly summary before approval, or says: plan brief, planning preview. Do NOT load for: actual implementation, code review, release work."
description-en: "Generate a Plan Brief HTML for non-engineer vibecoders before implementation starts. Searches harness-mem (project-only) for relevant past decisions, patterns, and Plans archive entries, then renders a single-file HTML artifact summarizing understanding, options, risks, acceptance criteria, and confidence. Use when the user requests a planning preview, a non-engineer-friendly summary before approval, or says: plan brief, planning preview. Do NOT load for: actual implementation, code review, release work."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[task-description]"
user-invocable: true
---

# harness-plan-brief

A skill that presents the plan Claude is about to start, on **a single HTML page**, for non-engineer requesters and producer roles.
Use it at the requester's cognitive-load peak (1): understanding the plan.

## Quick Reference

- "**create a Plan Brief**" → this skill
- "**give me a rough overview before implementation**" → this skill
- "**show the plan for a non-engineer**" → this skill

## Responsibility boundaries

| Scope | This skill's responsibility |
|-------|-----------------------------|
| Search | **Current project only** (always specify `project: <current>`, `strict_project: true`) |
| Cross-project | **Do not do it** (opened up as opt-in via the `--cross-project-group <name>` flag from Phase 65.3 onward) |
| Writes | Do not do it (memory writes after Plan Brief approval are the responsibility of `plan-brief-record-decision.sh`) |
| plan_readiness computation | Delegated to `scripts/plan-brief-compile.sh`. The compat field name `confidence` is kept, but its meaning is limited to DoD clarity + dependency resolution rate |

## Input

Pass the user's request in the `[task-description]` argument.
When there is no argument, take it interactively.

## Output

| Output | Path | Format |
|--------|------|--------|
| Plan Brief HTML | `.claude/state/views/plan-brief-<timestamp>.html` | Standalone HTML (no server, no JS framework) |
| Plan Brief context JSON | `.claude/state/views/plan-brief-<timestamp>.context.json` | `plan-brief-context.v1` schema |

## Schema: `plan-brief-context.v1`

```json
{
  "schema": "plan-brief-context.v1",
  "user_request": "string (the user's original request)",
  "my_understanding": "string (Claude's understanding in 1-3 paragraphs)",
  "options": [
    { "name": "string", "summary": "string", "pros": ["string"], "cons": ["string"] }
  ],
  "risks": [
    { "kind": "string", "severity": "info|warn|critical", "description": "string", "mitigation": "string" }
  ],
  "acceptance_criteria": [
    { "id": "string", "description": "string", "verifiable_by": "string" }
  ],
  "tdd_required": "yes|no|skip:<reason>",
  "confidence": 0,
  "confidence_evidence": ["string (plan_readiness evidence: DoD clarity + dependency resolution only)"],
  "related_decisions": [
    { "id": "string", "title": "string", "relevance": "string" }
  ],
  "similar_past_plans": [
    { "archive_path": "string", "phase": "string", "outcome": "cc:done|cc:WIP|cc:TODO|skipped", "relevance": "string" }
  ],
  "project": "string",
  "generated_at": "ISO8601"
}
```

For the full schema, see [`schemas/plan-brief-context.v1.schema.json`](${CLAUDE_SKILL_DIR}/schemas/plan-brief-context.v1.schema.json).

## Execution Flow

When the skill starts, Claude operates in the following steps.

### Step 1: Resolve the project name

```bash
PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)")"
```

If `PROJECT_NAME` is empty (outside git), use `current` as the default.

### Step 2: Search harness-mem **project-only** (default)

When the arguments do **not** include the `--cross-project-group <name>` flag (default behavior):

Call `mcp__harness__harness_mem_search` **always** with the following parameters:

```
project: <PROJECT_NAME>
strict_project: true
query: <user request>
expand_links: true
limit: 5
```

> **Important**: the `project` parameter is **required**. Do not pass an empty string or `null`.
> Specify `strict_project: true` and **never** perform a cross-project search.
> You may narrow with a `tags` filter for `decision` / `pattern` if needed, but keep `project` fixed.

Retrieve up to 5 similar items from past decisions (D1-D41) / patterns (P1-P33) / the 28 Plans archive entries.

### Step 2 (alt): cross-project search (Phase 65.3.5 opt-in)

Only when the arguments **do** include the `--cross-project-group <name>` flag:

Following D43 Option α (MCP N-call), perform the cross-project search in the following steps.

```bash
# (a) resolve group → member projects (yaml SSOT)
MEMBERS_JSON="$(bash scripts/load-cross-project-groups.sh --group "<name>" 2>/dev/null)" || {
  echo "ERROR: cross-project group not found: <name>" >&2
  exit 1
}
# MEMBERS_JSON is a JSON array in the form ["proj1","proj2",...]
```

If `MEMBERS_JSON` is `[]` (empty array), emit a warning and fall back to the default single-project search.

When `MEMBERS_JSON` is non-empty, **issue one MCP search per member project**:

```
for each project in MEMBERS_JSON:
  mcp__harness__harness_mem_search(
    project: <member>,
    strict_project: true,
    query: <user request>,
    expand_links: true,
    limit: 5
  )
```

**Merge, dedupe (by id), and sort by relevance_score descending on the client side**, then narrow to at most 5 items.
Note that the total number of calls grows (5 calls for a 5-project group), so latency increases.

> **Why N calls**: the memory search tool schema exposes neither `projects: [array]` nor `strict_project: false`,
> so client-side N-call is the only option for cross-project search.

Always pass cross-project results through the Layer 2/3 (Phase 65.3.2-65.3.4) redaction:
- Use `bash scripts/render-html.sh ... --with-redaction` when rendering the HTML
- This ensures proper nouns do not leak, via the 3-stage dictionary + NER + final scan

### Step 3: Assemble the context JSON

Use `scripts/plan-brief-compile.sh` to build JSON conforming to the
`plan-brief-context.v1` schema from the mem search results.

From Phase 105.3 onward, the Plan Brief `confidence` is a backward-compatible field name, and
its displayed meaning is treated as `plan_readiness`. Fix the computation axes to just the following two.

- DoD clarity: how many machine-verifiable numbers / conditions the request / DoD contains
- Dependency resolution rate: the fraction of similar Plans whose dependencies can be treated as complete

Display the success rate of similar past cases and the count of related Decisions / Patterns as context-only evidence;
do not add them to the readiness score on a separate axis. This avoids being misread as "the AI's comprehension" or "probability of success."

Always generate at least one `options` / `risks` / `acceptance_criteria` entry.
Even when the mem search is empty, fill in at minimum the following.

- `options`: at least one recommended option. Add alternatives if needed, with pros / cons
- `risks`: at least one risk specific to this plan, such as readiness misread, scope creep, or unobserved data
- `acceptance_criteria`: at least one condition that can be machine-verified or visually confirmed after execution

Example:

```bash
jq -n \
  --arg req "$USER_REQUEST" \
  --arg proj "$PROJECT_NAME" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    schema: "plan-brief-context.v1",
    user_request: $req,
    my_understanding: "(not started yet)",
    options: [{name:"Option A: proceed with minimal validation", summary:"confirm DoD and dependencies before implementing", pros:["small impact"], cons:["large redesigns need to be split into separate tasks"]}],
    risks: [{kind:"readiness-misread", severity:"warn", description:"risk of misreading plan_readiness as the AI's comprehension", mitigation:"state clearly in evidence that it is only a metric of DoD clarity + dependency resolution rate"}],
    acceptance_criteria: [{id:"AC-1", description:"the Plan Brief context contains non-empty options / risks / acceptance_criteria", verifiable_by:"tests/test-plan-brief-compile.sh"}],
    confidence: 0,
    confidence_evidence: ["plan_readiness DoD clarity: 0/60", "plan_readiness dependency resolution rate: 0/40"],
    tdd_required: "no",
    related_decisions: [],
    similar_past_plans: [],
    project: $proj,
    generated_at: $ts
  }' > "$CONTEXT_JSON"
```

### Step 4: Generate the HTML

Call `scripts/render-html.sh` (Phase 65.1.1) with `templates/html/plan-brief.html.template`:

The HTML displays the TDD decision in one line.
The format is one of `tdd_required: yes`, `tdd_required: no`, or `tdd_required: skip:<reason>`.

```bash
bash scripts/render-html.sh \
  --template plan-brief \
  --data "$CONTEXT_JSON" \
  --out "$HTML_OUT"
```

### Step 5: Auto-open in the browser

OS-specific dispatch via `scripts/plan-brief-open.sh`:

```bash
bash scripts/plan-brief-open.sh "$HTML_OUT"
```

When the `BROWSER=true` env is set (CI environment), open is **skipped** and only the path is printed via `printf`.

### Step 6: Wait for user approval

Confirm "is it OK to proceed to implementation with this understanding."
Memory writes after approval are the responsibility of a separate skill (Phase 65.1.4's `plan-brief-record-decision.sh`).

## Failure behavior

| Failure | Behavior |
|---------|----------|
| `mcp__harness__harness_mem_search` unreachable | Show a warning and continue with `related_decisions` / `similar_past_plans` as empty arrays |
| `git rev-parse --show-toplevel` failed | Continue with `PROJECT_NAME=current` |
| `render-html.sh` failed | Print the error to stderr and exit 1 |
| `plan-brief-open.sh` failed | Just print the HTML path to stdout and exit 0 (browser open is best-effort) |

## Related

- `scripts/render-html.sh` (Phase 65.1.1) — HTML template engine
- `scripts/plan-brief-compile.sh` (Phase 65.1.3) — context compilation
- `scripts/plan-brief-record-decision.sh` (Phase 65.1.4) — approval memory write
- `harness-accept` skill (Phase 65.2.1) — acceptance-decision skill (paired structure)
- `harness-progress` skill (Phase 65.4.1) — progress-management skill (paired structure)
