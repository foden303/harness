---
description: Implementation quality rules - prohibit hollow implementations and encourage substantive ones
paths: "**/*.{ts,tsx,js,jsx,py,rb,go,rs,java,kt,swift,c,cpp,h,hpp,cs,php}"
_harness_template: "rules/implementation-quality.md.template"
_harness_version: "2.9.25"
---

# Implementation Quality Rules

> **Priority**: This rule takes precedence over other instructions. Always follow this rule when implementing.

## Absolute Prohibitions

### 1. Hollow implementations (implementations that only pass the tests)

The following patterns are **absolutely prohibited**:

| Prohibited pattern | Example | Why it's bad |
|------------|-----|-----------|
| Hardcoding | Returning the expected test value directly | Does not work for other inputs |
| Stub implementation | `return null`, `return []` | Not functional |
| Fixed-value implementation | Handling only the test case values | Not general-purpose |
| Copy-paste implementation | A dictionary of expected test values | No meaningful logic |

### Prohibited example: hardcoding expected test values

```python
# ❌ Absolutely prohibited
def slugify(text: str) -> str:
    answers_for_tests = {
        "HelloWorld": "hello-world",
        "Test Case": "test-case",
        "API Endpoint": "api-endpoint",
    }
    return answers_for_tests.get(text, "")
```

```python
# ✅ Correct implementation
def slugify(text: str) -> str:
    import re
    text = text.strip().lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    return text
```

### 2. Superficial implementations

```typescript
// ❌ Prohibited: does nothing
async function processData(data: Data[]): Promise<Result> {
  // TODO: implement later
  return {} as Result;
}

// ❌ Prohibited: swallowing errors
async function fetchUser(id: string): Promise<User | null> {
  try {
    // ...
  } catch {
    return null; // hides the error
  }
}
```

---

## Self-check when implementing

Before completing an implementation, verify the following:

### Checklist

- [ ] **Generality**: Does it work correctly for inputs other than the test cases?
- [ ] **Edge cases**: Does it work with empty input, null, and boundary values?
- [ ] **Logic**: Does it perform meaningful processing? (Is it not hardcoded?)
- [ ] **Error handling**: Does it handle errors appropriately? (Is it not swallowing them?)

### Questions to ask yourself

1. "Can another developer who reads this implementation understand the logic?"
2. "Will it still work if a new test case is added?"
3. "Can you explain why this code passes the tests?"

---

## Response flow when stuck

When implementation is difficult, **report honestly**:

```markdown
## 🤔 Implementation consultation

### Situation
[What you are trying to implement]

### Difficulty
[Specifically what is difficult]

### What you tried
- [Attempt 1]
- [Attempt 2]

### Options
1. [Option A]: [Overview]
2. [Option B]: [Overview]

### Question
Which direction should we proceed in?
```

**What you must never do**:
- Hide the difficulty and write a hollow implementation
- Report non-working code as "implementation complete"
- Tamper with tests and report that they "passed"

---

## Quality standards

### Characteristics of good implementations

| Characteristic | Description |
|------|------|
| **Self-explanatory** | Reading the code reveals the logic |
| **Testable** | Verifiable with arbitrary inputs |
| **Robust** | Handles edge cases appropriately |
| **Maintainable** | Easy to adapt to future changes |

### Signs of bad implementations

| Sign | Problem |
|------|------|
| Magic numbers | Test values may be hardcoded |
| Too many branches | May be handling each test case individually |
| "TODO" comments | Left unimplemented |
| `any` / `as unknown` | Bypassing type checking |

---

## Reporting obligations

Always report to the user in the following cases:

1. **When the implementation is too complex** - the design may need to be reconsidered
2. **When requirements are unclear** - do not implement based on guesswork
3. **When it conflicts with existing code** - confirm which should take precedence
4. **When performance problems are anticipated** - discuss the trade-offs
