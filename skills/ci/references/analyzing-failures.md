---
name: ci-analyze-failures
description: "Analyze CI failure logs and identify the cause. Use when tests or builds fail in a CI/CD pipeline."
allowed-tools: ["Read", "Grep", "Bash"]
---

# CI Analyze Failures

A skill for analyzing CI/CD pipeline failures and identifying the cause.
It interprets logs from GitHub Actions, GitLab CI, etc.

---

## Input

- **CI log**: the log of the failed job
- **run_id**: the CI run identifier (if available)
- **Repository context**: the CI config files

---

## Output

- **Cause identification**: the concrete cause
- **Fix proposal**: a proposed remedy

---

## Execution steps

### Step 1: Check CI status

```bash
# For GitHub Actions
gh run list --limit 5

# Check the latest failure
gh run view --log-failed
```

### Step 2: Retrieve the failure log

```bash
# Log of a specific run
gh run view {{run_id}} --log

# Failed steps only
gh run view {{run_id}} --log-failed
```

### Step 3: Analyze the error pattern

#### Build error

```
Pattern: "error TS\d+:" or "Build failed"
Candidate causes:
- TypeScript type error
- Missing dependency
- Syntax error
```

#### Test error

```
Pattern: "FAIL" or "✕" or "AssertionError"
Candidate causes:
- Test failure
- Test timeout
- Mock mismatch
```

#### Dependency error

```
Pattern: "npm ERR!" or "Could not resolve"
Candidate causes:
- package.json inconsistency
- Private package authentication
- Version conflict
```

#### Environment error

```
Pattern: "not found" or "undefined"
Candidate causes:
- Unset environment variable
- Missing secret
- Path issue
```

### Step 4: Output the analysis result

```markdown
## 🔍 CI failure analysis

**Run ID**: {{run_id}}
**Failure time**: {{timestamp}}
**Failed step**: {{step_name}}

### Cause identification

**Error type**: {{build / test / dependency / environment}}

**Error message**:
```
{{core part of the error}}
```

**Cause analysis**:
{{concrete explanation of the cause}}

### Related files

| File | Relevance |
|---------|-------|
| `{{path}}` | {{relevance}} |

### Fix proposal

1. {{concrete fix step 1}}
2. {{concrete fix step 2}}

### Auto-fixability

- Auto-fix: {{possible / not possible}}
- Reason: {{reason}}
```

---

## Error pattern dictionary

### TypeScript errors

| Error code | Meaning | Typical fix |
|-------------|------|-------------|
| TS2304 | Name not found | Add import |
| TS2322 | Type mismatch | Fix type |
| TS2345 | Argument type differs | Fix argument |
| TS7006 | Implicit any | Add type annotation |

### npm errors

| Error | Meaning | Typical fix |
|--------|------|-------------|
| ERESOLVE | Dependency resolution failed | Delete package-lock & reinstall |
| ENOENT | File not found | Check path |
| EACCES | Permission error | Check CI settings |

### Jest/Vitest errors

| Error | Meaning | Typical fix |
|--------|------|-------------|
| Timeout | Test timeout | Extend timeout or fix async |
| Snapshot | Snapshot mismatch | `npm test -- -u` |

---

## Priority for multiple errors

1. **Build errors**: fix first
2. **Dependency errors**: must be resolved before the build
3. **Test errors**: address after a successful build
4. **Lint errors**: address last

---

## Connecting to the next action

After analysis is complete:

> 📊 **Analysis complete**
>
> **Cause**: {{summary of the cause}}
>
> **Next action**:
> - "Fix it" → attempt an automatic fix
> - "More detail" → a more detailed analysis
> - "Skip" → switch to manual handling

---

## Notes

- **Logs are large**: extract the important parts
- **Beware chained errors**: find the first error
- **Environment differences**: account for local vs CI differences
