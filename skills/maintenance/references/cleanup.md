# Cleanup Reference

Details of the execution steps, thresholds, and archive destinations for each `/maintenance` subcommand.

## Common: Environment Variables (same SSOT as auto-cleanup-hook)

| Variable | Default | Source |
|----------|---------|--------|
| `PLANS_MAX_LINES` | 200 | `scripts/auto-cleanup-hook.sh` |
| `SESSION_LOG_MAX_LINES` | 500 | same |
| `CLAUDE_MD_MAX_LINES` | 100 | same |
| `ARCHIVE_AFTER_DAYS` | 7 | Age threshold for completed Plans.md tasks |
| `LOGS_RETAIN_DAYS` | 30 | Retention days for `.claude/logs/` |

If the user specifies a different threshold in free-form, prefer that.

---

## plans — Plans.md archiving

### Prerequisites

1. If the `.claude/state/.ssot-synced-this-session` flag is absent → prompt for `/memory sync`
2. **Never move** lines tagged `cc:WIP` or `pm:pending`

### Steps

```bash
PLANS="Plans.md"
cp "$PLANS" "$PLANS.bak.$(date +%s)"

# 1. Measure current state
wc -l "$PLANS"
grep -c '\[x\].*pm:confirmed' "$PLANS" || true

# 2. Extract lines completed more than 7 days ago (individually, with the Edit tool)
#    Target: `- [x] ... (YYYY-MM-DD) ... pm:confirmed`
#    Exception: exclude lines containing cc:WIP / pm:pending

# 3. Append the extracted lines to the "## 📦 Archive" section
#    If no archive section exists, create one at the end
```

### Archive Section Format

```markdown
## 📦 Archive

### YYYY-MM (grouped by month)

- [x] Old task A (2026-04-05) pm:confirmed
- [x] Old task B (2026-04-07) pm:confirmed
```

### Output When Nothing Is Detected

```
✅ Plans.md: 180 lines (limit 200). 6 completed tasks, 0 older than 7 days. No tidy-up needed.
```

### Example Report After Execution

```
✅ Plans.md tidy-up complete
- Lines: 250 → 178 (-72)
- Archived: 9 tasks (2026-03 group)
- Backup: Plans.md.bak.1712900000
```

---

## session-log — split session-log.md by month

Target is `.claude/memory/session-log.md`. Splitting is recommended past 500 lines.

### Steps

```bash
LOG=".claude/memory/session-log.md"
ARCHIVE_DIR=".claude/memory/archive/sessions"
mkdir -p "$ARCHIVE_DIR"

# 1. Assumes entries are separated by `## YYYY-MM-DD` headers
# 2. Keep the most recent 30 days and split anything older by month
#    Output: .claude/memory/archive/sessions/YYYY-MM.md (append)
# 3. Delete the moved portions from the original file
```

### Split File Format

At the top of each `archive/sessions/YYYY-MM.md`, write:

```markdown
# Session Log — YYYY-MM

Source file: moved from `.claude/memory/session-log.md`, older than N days.
Move date: YYYY-MM-DD
```

### Example Report After Execution

```
✅ session-log.md split complete
- Lines: 620 → 180
- Split into: archive/sessions/2026-03.md (+230 lines), 2026-02.md (+210 lines)
```

---

## logs — delete old files in `.claude/logs/`

### Steps

```bash
LOGS_DIR=".claude/logs"
[ -d "$LOGS_DIR" ] || exit 0

# List targets in dry-run
find "$LOGS_DIR" -type f -mtime +${LOGS_RETAIN_DAYS:-30} -print

# Execute
find "$LOGS_DIR" -type f -mtime +${LOGS_RETAIN_DAYS:-30} -delete
```

### Example Report

```
✅ logs/ cleanup complete
- Deleted: 12 files (older than 30 days)
- Remaining: 34 files
```

---

## state — trim agent-trace / harness-usage

`.claude/state/agent-trace.jsonl` and `.claude/state/harness-usage.json` are
append-only / growing JSON that can reach tens of MB if left unchecked.

### Trimming agent-trace.jsonl

```bash
TRACE=".claude/state/agent-trace.jsonl"
[ -f "$TRACE" ] || exit 0

# Keep only the last 1000 lines
tail -1000 "$TRACE" > "$TRACE.tmp" && mv "$TRACE.tmp" "$TRACE"
```

### Compacting harness-usage.json

```bash
USAGE=".claude/state/harness-usage.json"
[ -f "$USAGE" ] || exit 0

# Delete entries older than 60 days (structure-dependent, so write the jq condition appropriately)
# Read the actual structure before implementing, then process
```

### Example Report

```
✅ state trim complete
- agent-trace.jsonl: 8421 lines → 1000 lines
- harness-usage.json: deleted entries before 2026-02
```

---

## all — run everything

Run in order: plans → session-log → logs → state. If an error occurs mid-run, stop and report to the user.

### Execution Flow

1. SSOT sync check (only when plans is among the targets)
2. Run each subcommand in sequence
3. Show a Before/After list at the end

### Example Report

```
✅ Full maintenance complete

| Target | Before | After | Change |
|--------|--------|-------|--------|
| Plans.md | 250 lines | 178 lines | -72 (9 archived) |
| session-log.md | 620 lines | 180 lines | -440 (split into 2 files) |
| logs/ | 46 files | 34 files | -12 (older than 30 days) |
| agent-trace.jsonl | 8421 lines | 1000 lines | -7421 |

Backup: Plans.md.bak.1712900000
```

---

## Handling Common Additional Instructions

| Instruction | Action |
|-------------|--------|
| "also delete old archives" | Additionally delete items in `.claude/memory/archive/` older than N days |
| "dry-run" | Replace all deletions/moves with `echo`, listing only what would be removed |
| "keep this file" | Exclude the named file from the target list and run |
| "raise the threshold to 300 lines" | Temporarily override the env var, e.g. `PLANS_MAX_LINES=300 ` |

---

## Prohibited

- ❌ Automatically editing `.claude/memory/decisions.md` / `patterns.md` (directly altering SSOT is prohibited)
- ❌ Compacting/archiving `CHANGELOG.md` (never delete history)
- ❌ Operating on anything under `.git/`
- ❌ Deleting lines without a backup (files over 200 lines must always be backed up)
