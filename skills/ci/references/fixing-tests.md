---
name: ci-fix-failing-tests
description: "Guide for fixing tests that failed in CI. Use to attempt an automatic fix after the cause of a CI failure is identified."
allowed-tools: ["Read", "Edit", "Bash"]
---

# CI Fix Failing Tests

A skill for fixing tests that failed in CI.
It fixes the test code, or the production code.

---

## Input

- **Failing test info**: test name, error message
- **Test file**: the source of the failing test
- **Code under test**: the implementation being tested

---

## Output

- **Fixed code**: a fix to the test or the implementation
- **Confirmation that the test passes**

---

## Execution steps

### Step 1: Identify the failing test

```bash
# Run tests locally
npm test 2>&1 | tail -50

# Test a specific file
npm test -- {{test-file}}
```

### Step 2: Classify the error type

#### Type A: Assertion failure

```
Expected: "expected value"
Received: "actual value"
```

→ The implementation differs from expectation, or the test's expected value is wrong

#### Type B: Timeout

```
Timeout - Async callback was not invoked within the 5000ms timeout
```

→ An async operation doesn't complete, or takes too long

#### Type C: Type error

```
TypeError: Cannot read properties of undefined
```

→ Access to null/undefined, or an initialization problem

#### Type D: Mock-related

```
expected mockFn to have been called
```

→ Missing mock setup, or the call is never made

### Step 3: Decide the fix strategy

```markdown
## Fix strategy decision

1. **If the test is correct** → fix the implementation
2. **If the implementation is correct** → fix the test
3. **If both need fixing**   → prioritize the implementation

Criteria:
- Which is correct against the spec/requirements
- What changed recently
- Impact on other tests
```

### Step 4: Implement the fix

#### Fixing an assertion failure

```typescript
// When the test's expected value is wrong
it('calculates correctly', () => {
  // Before
  expect(calculate(2, 3)).toBe(5)
  // After (if the spec is multiplication)
  expect(calculate(2, 3)).toBe(6)
})

// When the implementation is wrong
// → fix the implementation file
```

#### Fixing a timeout

```typescript
// Extend the timeout
it('fetches data', async () => {
  // ...
}, 10000)  // extended to 10 seconds

// Or use async/await correctly
it('fetches data', async () => {
  await waitFor(() => {
    expect(screen.getByText('Data')).toBeInTheDocument()
  })
})
```

#### Fixing a mock-related issue

```typescript
// Add the mock setup
vi.mock('../api', () => ({
  fetchData: vi.fn().mockResolvedValue({ data: 'mock' })
}))

// Reset in beforeEach
beforeEach(() => {
  vi.clearAllMocks()
})
```

### Step 5: Confirm after fixing

```bash
# Re-run the failing test
npm test -- {{test-file}}

# Run all tests (regression check)
npm test
```

---

## Fix pattern collection

### Snapshot update

```bash
# Update snapshots
npm test -- -u

# A specific test only
npm test -- {{test-file}} -u
```

### Fixing async tests

```typescript
// Use findBy (auto-wait)
const element = await screen.findByText('Text')

// Use waitFor
await waitFor(() => {
  expect(mockFn).toHaveBeenCalled()
})
```

### Updating mock data

```typescript
// Update the mock to match the implementation change
const mockData = {
  id: 1,
  name: 'Test',
  createdAt: new Date().toISOString()  // new field
}
```

---

## Post-fix checklist

- [ ] The previously failing test passes
- [ ] Other tests are not broken
- [ ] It matches the intent of the implementation
- [ ] The test hasn't become overly loose

---

## Completion report format

```markdown
## ✅ Test fix complete

### Fix content

| Test | Problem | Fix |
|-------|------|------|
| `{{test name}}` | {{problem}} | {{fix content}} |

### Confirmation result

```
Tests: {{passed}} passed, {{total}} total
```

### Next action

"Commit it" or "Re-run CI"
```

---

## Notes

- **Do not delete tests**: deletion is a last resort
- **Skip only temporarily**: permanent skips are prohibited
- **Identify the root cause**: avoid surface-level fixes
