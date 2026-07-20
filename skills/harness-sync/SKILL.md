---
name: harness-sync
description: "HAR: Sync Plans.md with implementation. Drift detect, marker update, retrospective. Trigger: sync-status, where am I, check progress. --snapshot for snapshots. Do NOT load for: planning, implementation, review, release."
description-en: "HAR: Sync Plans.md with implementation. Drift detect, marker update, retrospective. Trigger: sync-status, where am I, check progress. --snapshot for snapshots. Do NOT load for: planning, implementation, review, release."
kind: workflow
purpose: "Reconcile Plans.md, git, and implementation state"
trigger: "sync-status, where am I, check progress"
shape: workflow
role: synchronizer
pair: harness-plan
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Edit", "Bash", "Grep", "Glob"]
argument-hint: "[--snapshot|--no-retro]"
user-invocable: true
effort: medium
---

# Harness Sync

Reconcile Plans.md with the implementation status, detecting and updating diffs.
The standalone version of the old `sync-status` and the `harness-plan sync` subcommand.

## Quick Reference

| User input | Behavior |
|------------|----------|
| `harness-sync` | Progress sync + retrospective (default ON) |
| `harness-sync --no-retro` | Progress sync only (skip retrospective) |
| `harness-sync --snapshot` | Save a snapshot (a point-in-time record of progress) |
| `harness-sync --plan roadmap` | Sync the `roadmap` named Plans |
| "where are we?" / "check progress" | Same as above |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--snapshot` | Save the current progress as a snapshot | false |
| `--no-retro` | Skip the retrospective | false (runs by default) |
| `--plan NAME` | Use the named plan in `plans/manifest.json` | active/default |

## Step 0: Validate Plans.md

Confirm the existence and format of Plans.md. If there is a problem, immediately guide the user and stop.
In a repo with multiple Plans.md files, confirm the target plan with `scripts/plan-registry.sh list` or `--plan NAME` before reading.

| State | Guidance |
|-------|----------|
| Plans.md does not exist | `Plans.md not found. Please create it with harness-plan create.` → **stop** |
| Header has no DoD / Depends columns (v1 format) | `Plans.md is in the old format (3 columns). Please regenerate it as v2 (5 columns) with harness-plan create. Existing tasks are carried over automatically.` → **stop** |
| v2 format (5 columns) | Proceed to Step 1 as-is |

## Step 1: Collect the current state (parallel)

```bash
# State of Plans.md
cat Plans.md

# Git change status
git status
git diff --stat HEAD~3

# Recent commit history
git log --oneline -10

# Agent trace (recently edited files)
tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.files[].path' | sort -u
```

## Step 1.5: Agent Trace analysis

Get the recent edit history from the Agent Trace and reconcile it with the Plans.md tasks:

```bash
# List of recently edited files
RECENT_FILES=$(tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.files[].path' | sort -u)

# Project info
PROJECT=$(tail -1 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.metadata.project')
```

**Reconciliation points**:

| Check item | Detection method |
|------------|------------------|
| Files edited but not in Plans.md | Agent Trace vs task descriptions |
| Files that differ from the task description | Expected files vs actual edits |
| Tasks with no edits for a long time | Agent Trace timeline vs WIP duration |

## Step 2: Diff detection

| Check item | Detection method |
|------------|------------------|
| `cc:WIP` although complete | Commit history vs marker |
| `cc:TODO` although started | Changed files vs marker |
| `cc:done` although uncommitted | git status vs marker |

## Step 3: Propose Plans.md updates

When a diff is detected, propose and apply it:

```
Plans.md needs updating

| Task | Current | New | Reason |
|------|---------|-----|--------|
| XX   | cc:WIP | cc:done | committed |
| YY   | cc:TODO | cc:WIP | files edited |

Update? (yes / no)
```

## Step 4: Output the progress summary

```markdown
## Progress summary

**Project**: {{project_name}}

| Status | Count |
|--------|-------|
| Not started (cc:TODO) | {{count}} |
| In progress (cc:WIP) | {{count}} |
| Complete (cc:done) | {{count}} |
| PM-confirmed (pm:confirmed) | {{count}} |

**Progress rate**: {{percent}}%

### Recently edited files (Agent Trace)
- {{file1}}
- {{file2}}
```

## Step 4.5: Save a snapshot (when `--snapshot` is specified)

When `--snapshot` is specified, save the current progress state as a timestamped snapshot.

### Save location

Saved as JSON in the `.claude/state/snapshots/` directory:

```bash
SNAPSHOT_DIR="${PROJECT_ROOT}/.claude/state/snapshots"
mkdir -p "${SNAPSHOT_DIR}"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/progress-$(date -u +%Y%m%dT%H%M%SZ).json"
```

### Snapshot content

```json
{
  "timestamp": "2026-03-08T10:30:00Z",
  "phase": "Phase 26",
  "progress": {
    "total": 16,
    "todo": 5,
    "wip": 3,
    "done": 6,
    "confirmed": 2
  },
  "progress_rate": 50,
  "recent_commits": ["abc1234 feat: ...", "def5678 fix: ..."],
  "recent_files": ["skills/harness-work/SKILL.md", "..."],
  "notes": ""
}
```

### Diff comparison

When a previous snapshot exists, show the diff:

```markdown
## Snapshot diff

| Metric | Previous ({{prev_time}}) | Current | Change |
|--------|--------------------------|---------|--------|
| Progress rate | {{prev}}% | {{current}}% | +{{diff}}%pt |
| Done tasks | {{prev_done}} | {{current_done}} | +{{diff_done}} |
| WIP tasks | {{prev_wip}} | {{current_wip}} | {{diff_wip}} |
```

> **Design intent**: a snapshot is used manually when the user wants to "record the current state."
> It is separate from the automatic progress feed during breezing (26.2.3).

## Step 5: Propose the next action

```
What to do next

**Priority 1**: {{task}}
- Reason: {{requested / waiting to be unblocked}}

**Recommended**: harness-work, harness-review
```

## Anomaly detection

| Situation | Warning |
|-----------|---------|
| Multiple `cc:WIP` | Multiple tasks are in progress at once |
| Unprocessed `pm:pending` | Process the PM's request first |
| Large divergence | Task management is not keeping up |
| WIP not updated for 3+ days | Check whether it is blocked |

## Step 6: Retrospective (default ON)

If there is at least one `cc:done` task, automatically run a retrospective.
It can be explicitly skipped with `--no-retro`.

### Step R1: Collect completed tasks

```bash
# Extract cc:done / pm:confirmed tasks from Plans.md
grep -E 'cc:done|pm:confirmed' Plans.md

# Recent completion commit history
git log --oneline --since="7 days ago"

# Change size
git diff --stat HEAD~10
```

### Step R2: The 4 retrospective items

| Item | Analysis method |
|------|-----------------|
| **Estimate accuracy** | Infer the expected number of files from the Plans.md task description → compare with the actual number of changed files from `git diff --stat` |
| **Block causes** | Aggregate the reason patterns of tasks marked `blocked` (technical / external dependency / unclear spec) |
| **Quality marker hit rate** | Whether tasks tagged with `[feature:security]`, etc. actually surfaced related issues |
| **Scope change** | Task count at the first commit of Plans.md vs the current task count (added/removed count) |

### Step R3: Output the retrospective summary

```markdown
## Retrospective summary

**Period**: {{start_date}} – {{end_date}}

| Metric | Value |
|--------|-------|
| Done tasks | {{count}} |
| Blocks occurred | {{blocked_count}} |
| Scope change | +{{added}} / -{{removed}} |
| Estimate accuracy | expected {{est}} files → actual {{actual}} files |

### Learnings
- {{1-2 line learning}}

### To apply next time
- {{1-2 line improvement action}}
```

### Step R4: Record to harness-mem

Record the retrospective result to harness-mem so it can be referenced at the next `create`.
Save location: the relevant agent memory under `.claude/agent-memory/`.

## Related skills

- `harness-plan` — plan creation and task management
- `harness-work` — task implementation
- `harness-review` — code review
