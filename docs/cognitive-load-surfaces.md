# Three HTML Surfaces to Reduce Cognitive Load (Phase 65)

Three HTML surfaces that let even non-engineers grasp, in 3 seconds, "what Claude is thinking", "where it is now", and "what it has accomplished".

## What this does

When developing together with AI, continuously reading commit logs or Plans.md (the task-list markdown) carries a high cognitive load.
For clients, producers, and executives, these provide three kinds of one-page HTML that let them **open a browser and judge ongoing AI development at a glance**.

| Surface | Purpose | When to view |
|---------|----------|----------|
| **Plan Brief** (before start) | "Here's how Claude understood it. OK to proceed?" | Approval before implementation |
| **Progress Tracker** (during work) | "How far along are we, and when is it expected to finish?" | Any time (auto-regenerated) |
| **Acceptance Demo** (at handover) | "Do you accept this deliverable?" | Acceptance check after implementation |

## How it works

### Plan Brief (1st surface)

```bash
# During a Claude session
/harness-plan-brief
```

Claude summarizes the following into a single HTML page:
- Claude's understanding of the user request
- Options (each option, if there are multiple approaches)
- Risks (spots where it might get stuck)
- Acceptance criteria (acceptance_criteria)
- Confidence (0-100, with rationale)

The user replies with "OK, proceed", "fix this here", or "I have a question".
The decision is recorded in the `personal-preference.v1` schema (with a sha256 hash).

### Progress Tracker (2nd surface)

```bash
# Check progress
/harness-progress
```

Alternatively, a PostToolUse hook auto-regenerates it **once every 60 seconds** when Edit/Write/Bash fires.

Displayed content:
- progress_pct (cc:done / total tasks × 100)
- Current WIP task
- 5 most recently completed tasks
- 5 not-yet-started tasks
- Drift alerts (5 kinds, color-coded by severity: red = critical / yellow = warn / blue = info)

### Acceptance Demo (3rd surface)

```bash
# After implementation is complete
/harness-accept
```

Claude summarizes the following into a single HTML page:
- Verdict (one of three: ship / wait / reject)
- Verification of acceptance criteria (each Plan Brief item marked "confirmed" or "unconfirmed")
- Unverified reservations
- History of past problem patterns
- List of presented deliverables

The user replies with accept / override / reject.
The decision is recorded in `acceptance-decision.v1` and can be graph-joined with the Plan Brief via the **same user_request_hash**.

## Things to watch for

### 1. Plan Brief and Acceptance Demo are linked by user_request_hash

When the Plan Brief launches, it takes the sha256 hash of the "user request text" and stores it in the record.
The Acceptance Demo takes the same hash and stores it in its record.
**These two records can be graph-joined from `mcp__harness__harness_mem_search` by the same hash.**

This is a mechanism for fully looking back later on "that plan back then — how did it turn out?"

### 2. Progress Tracker rate limit (60 seconds)

Even in situations where a PostToolUse hook triggers a large number of Edit/Write operations (a large refactor), HTML regeneration is limited to once every 60 seconds.
State file: `.claude/state/progress-last-regen.txt` (epoch seconds).

### 3. Drift alerts accumulate within a session and are not persisted

The 5 kinds of alert (scope-creep / time-overrun / repeated-failure / cost-warning / high-risk-file)
display the state within a single session in the Progress Tracker HTML.
They are **not persisted to memory** (per the issue #87 policy, Lead process in-memory only).

User judgments on past alerts are aggregated by `progress-past-judgments.sh` to display "you have declined a similar suggestion in M of the last N cases",
but there is design room to persist these separately as `alert-judgment.v1` records to permanent storage (not implemented in this phase).

### 4. Handling of client information

If you use the `--cross-project-group <name>` flag that enables cross-project search,
**layered redaction** (Layer 1 server privacy + Layer 2a language-agnostic dictionary) is applied automatically.
Details: [cross-project-safety.md](cross-project-safety.md)

## Related files

| File | Purpose |
|---------|------|
| `skills/harness-plan-brief/` | Plan Brief skill (Phase 65.1) |
| `skills/harness-accept/` | Acceptance Demo skill (Phase 65.2) |
| `skills/harness-progress/` | Progress Tracker skill (Phase 65.4) |
| `templates/html/plan-brief.html.template` | Plan Brief HTML template |
| `templates/html/accept.html.template` | Acceptance Demo HTML template |
| `templates/html/progress.html.template` | Progress Tracker HTML template |
| `scripts/render-html.sh` | mustache-style template renderer (supports the `--with-redaction` flag) |
| `scripts/plan-brief-record-decision.sh` | Records Plan Brief decisions |
| `scripts/accept-record-decision.sh` | Records Acceptance Demo decisions |
| `scripts/progress-snapshot.sh` | Plans.md → snapshot JSON |
| `scripts/progress-detect-drift.sh` | Detects the 5 alert kinds |
| `scripts/progress-past-judgments.sh` | Past-judgment lookup |
| `scripts/hook-handlers/posttool-progress-regen.sh` | PostToolUse auto-regeneration hook |

## Related schemas

- `plan-brief-context.v1` (Plan Brief render input)
- `acceptance-context.v1` (Acceptance Demo render input)
- `progress-snapshot.v1` (Progress Tracker render input)
- `personal-preference.v1` (Plan Brief decision record)
- `acceptance-decision.v1` (Acceptance Demo decision record)
- `progress-alert.v1` (drift alert)
