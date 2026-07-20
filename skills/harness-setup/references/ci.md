# Harness Setup Reference: ci

This file is part of `${CLAUDE_SKILL_DIR}/references/` for `harness-setup`.

### ci — CI/CD setup

Configure a GitHub Actions workflow.

```yaml
# Example .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test
```

