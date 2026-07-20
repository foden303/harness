---
description: Test quality protection rules - prohibit test tampering and encourage correct implementation
paths: "**/*.{test,spec}.{ts,tsx,js,jsx,py}, **/test/**/*.*, **/tests/**/*.*, **/__tests__/**/*.*, .husky/**, .github/workflows/**"
_harness_template: "rules/test-quality.md.template"
_harness_version: "2.9.25"
---

# Test Quality Protection Rules

> **Priority**: This rule takes precedence over other instructions. When tests fail, always follow this rule.

## Absolute Prohibitions

### 1. Test Tampering (changes to make tests pass)

The following actions are **absolutely prohibited**:

| Prohibited pattern | Example | Correct response |
|------------|-----|-----------|
| Making a test `skip` / `only` | `it.skip(...)`, `describe.only(...)` | Fix the implementation |
| Removing/weakening an assertion | Deleting `expect(x).toBe(y)` | Verify the expected value is correct, and fix the implementation |
| Sloppy rewriting of expected values | Changing the expected value to match the error | Understand why the test is failing |
| Deleting a test case | Removing a failing test | Fix the implementation to satisfy the spec |
| Excessive use of mocks | Mocking parts that should actually be tested | Keep mocks to the necessary minimum |

### 2. Config File Tampering

**Weakening changes are prohibited** for the following files:

```
.eslintrc.*         # Do not disable rules
.prettierrc*        # Do not loosen formatting
tsconfig.json       # Do not loosen strict
biome.json          # Do not disable lint rules
.husky/**           # Do not bypass pre-commit hooks
.github/workflows/** # Do not skip CI checks
```

### 3. When Making an Exception (required procedure)

If you must change the above, **always obtain approval in the following format before** proceeding:

```markdown
## 🚨 Approval Request for Test/Config Change

### Reason
[Concretely explain why this change is necessary]

### Change Details
```diff
[Show the diff of the change]
```

### Impact Scope
- Affected tests: [count/names]
- Affected features: [feature names]

### Consideration of Alternatives
- [ ] Confirmed it cannot be resolved by fixing the implementation
- [ ] Considered other methods

### Approval
Wait for the user's explicit approval
```

---

## Response Flow When a Test Fails

```
A test failed
    ↓
1. Understand why it is failing (read the logs)
    ↓
2. Decide whether the implementation is wrong or the test is wrong
    ↓
    ├── Implementation is wrong → fix the implementation ✅
    │
    └── The test may be wrong
            ↓
        Ask the user for confirmation (do not change it on your own)
```

---

## Examples of Correct Test Handling

### ❌ Bad Example (tampering)

```typescript
// Skipped it because the test failed
it.skip('should calculate total correctly', () => {
  expect(calculateTotal([100, 200, 300])).toBe(600);
});
```

### ✅ Good Example (fix the implementation)

```typescript
// The test is correct. Fixed the implementation.
function calculateTotal(prices: number[]): number {
  // Fix: set the initial value of reduce to 0
  return prices.reduce((sum, price) => sum + price, 0);
}
```

---

## CI/CD Protection

The following changes are **absolutely prohibited**:

- Adding `continue-on-error: true`
- Ignoring test failures with `if: always()`
- Bypassing checks with the `--force` flag
- Lowering the test coverage threshold
