# sync subcommand — progress sync flow

Reconcile the implementation status with Plans.md, detecting and updating diffs.

## Step 0: Validate Plans.md

Confirm the existence and format of Plans.md. If there is a problem, immediately guide the user and stop.

| State | Guidance |
|-------|----------|
| Plans.md does not exist | `Plans.md not found. Please create it with /harness-plan create.` → **stop** |
| Header has no DoD / Depends columns (v1 format) | `Plans.md is in the old format (3 columns). Please regenerate it as v2 (5 columns) with /harness-plan create. Existing tasks are carried over automatically.` → **stop** |
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

### Artifact hash backward compatibility

Recognize both the `cc:done [a1b2c3d]` format (with commit hash) and `cc:done` (without a hash).

**Matching rules**:
- `cc:done` → treat as a completion without a hash
- `cc:done [xxxxxxx]` → treat as a completion with a hash. Keep the 7-char short hash
- When a hash is present, you can reconcile with `git log --oneline` to confirm the commit exists

> **Backward compatibility**: the no-hash format is still valid. Do not break existing Plans.md.

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

When running `sync`, if there is at least one `cc:done` task, automatically run a retrospective.
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
