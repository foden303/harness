---
name: ci
description: "CI red? Call us. Pipeline fire brigade deploys. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
description-en: "CI red? Call us. Pipeline fire brigade deploys. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
allowed-tools: ["Read", "Grep", "Bash", "Task", "Monitor"]
user-invocable: true
context: fork
argument-hint: "[analyze|fix|run]"
---

# CI/CD Skills

A set of skills for resolving CI/CD pipeline problems.

---

## Trigger conditions

- "CI failed", "GitHub Actions failed"
- "build error", "tests won't pass"
- "fix the pipeline"

---

## Feature details

| Feature | Details | Trigger |
|------|------|----------|
| **Failure analysis** | See [references/analyzing-failures.md](${CLAUDE_SKILL_DIR}/references/analyzing-failures.md) | "look at the log", "find the cause" |
| **Test fixing** | See [references/fixing-tests.md](${CLAUDE_SKILL_DIR}/references/fixing-tests.md) | "fix the tests", "propose a fix" |

---

## Execution steps

1. **Test vs implementation decision** (Step 0)
2. Classify the user's intent (analyze or fix)
3. Determine the complexity (see below)
4. Read the appropriate reference file from "Feature details" above, or launch the ci-cd-fixer subagent
5. Verify the result and re-run if needed

### Step 0: Test vs implementation decision (quality decision gate)

On CI failure, first isolate the cause:

```
CI failure report
    ↓
┌─────────────────────────────────────────┐
│        Test vs implementation decision   │
├─────────────────────────────────────────┤
│  Analyze the cause of the error:         │
│  ├── Implementation is wrong → fix impl  │
│  ├── Test is stale → confirm with user   │
│  └── Environment issue → fix environment │
└─────────────────────────────────────────┘
```

#### Prohibited (tampering prevention)

```markdown
⚠️ Prohibited on CI failure

The following "solutions" are prohibited:

| Prohibited | Example | Correct response |
|------|-----|-----------|
| Skipping tests | `it.skip(...)` | Fix the implementation |
| Removing assertions | Deleting `expect()` | Confirm the expected value |
| Bypassing CI checks | `continue-on-error` | Fix the root cause |
| Loosening lint rules | `eslint-disable` | Fix the code |
```

#### Decision flow

```markdown
🔴 CI is failing

**A decision is needed**:

1. **Implementation is wrong** → fix the implementation ✅
2. **The test's expected value is stale** → ask the user to confirm
3. **Environment issue** → fix the environment settings

⚠️ Tampering with tests (skipping, removing assertions) is prohibited

Which one applies?
```

#### When approval is needed

When a test/config change is unavoidable:

```markdown
## 🚨 Approval request for test/config change

### Reason
[Why this change is needed]

### Change content
[Diff]

### Consideration of alternatives
- [ ] Confirmed it cannot be resolved by fixing the implementation

Wait for the user's explicit approval
```

### Leveraging git log extension flags (CC 2.1.49+)

Use structured logs to identify the culprit commit on CI failure.

#### Identifying the culprit commit

```bash
# Analyze commits in a structured format
git log --format="%h|%s|%an|%ad" --date=short -10

# Chronological analysis in topological order
git log --topo-order --oneline -20

# Link changed files to the cause
git log --raw --oneline -5
```

#### Main use cases

| Use case | Flag | Effect |
|------|--------|------|
| **Identify the failure cause** | `--format="%h|%s"` | Structure the commit list |
| **Track chronologically** | `--topo-order` | Track considering merge order |
| **Grasp change impact** | `--raw` | Show file change details |
| **Exclude merges** | `--cherry-pick --no-merges` | Extract only real commits |

#### Example output

```markdown
🔍 CI failure cause analysis

Recent commits (structured):
| Hash | Subject | Author | Date |
|------|---------|--------|------|
| a1b2c3d | feat: update API | Alice | 2026-02-04 |
| e4f5g6h | test: add tests | Bob | 2026-02-03 |

Changed files (--raw):
├── src/api/endpoint.ts (Modified) ← type error here
├── tests/api.test.ts (Modified)
└── package.json (Modified)

→ Commit a1b2c3d is the likely cause
  Type error: src/api/endpoint.ts:42
```

## Subagent integration

When the following conditions are met, launch ci-cd-fixer with the Task tool:

- The fix → re-run → fail loop occurs **2 or more times**
- Or the error spans multiple files (a complex case)

**Launch pattern:**

```
Task tool:
  subagent_type="ci-cd-fixer"
  prompt="Diagnose and fix the CI failure. Error log: {error_log}"
```

ci-cd-fixer operates safety-first (default dry-run mode).
For details, see `agents/ci-cd-fixer.md`.

---

## For VibeCoders

```markdown
🔧 How to phrase it when CI breaks

1. **"CI failed" / "it went red"**
   - The automated tests are failing

2. **"Why is it failing?"**
   - You want the cause investigated

3. **"Fix it"**
   - Attempt an automatic fix

💡 Important: fixes that "cheat" the tests are prohibited
   - ❌ Deleting or skipping tests
   - ⭕ Fixing the code correctly

If you think "the test seems wrong,"
confirm first, then decide the response
```
