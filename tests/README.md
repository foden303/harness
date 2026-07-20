# Test Suite

This directory contains the tests that guarantee the quality of the harness plugin.

## Tests for VibeCoders

Rather than complex enterprise-grade tests, these are simple tests that let a **VibeCoder handling a client project solo** easily confirm that the plugin works correctly.

## How to Run the Tests

### Validating the plugin structure

Validates that the basic structure of the plugin is correct:

```bash
./tests/validate-plugin.sh
./tests/validate-plugin-v3.sh
./scripts/ci/check-consistency.sh
```

### Unified Memory validation

Validates the basic behavior of the shared memory daemon:

```bash
./tests/test-memory-daemon.sh
```

Loops to verify that no zombie processes are left behind:

```bash
./tests/test-memory-daemon-zombie.sh 100
```

Validates search quality (hybrid ranking / privacy filter / API path):

```bash
./tests/test-memory-search-quality.sh
```

These checks confirm the following:

1. **Plugin structure**: existence and validity of plugin.json
2. **Commands**: existence of registered command files
3. **Skills**: existence and basic quality of skill definitions
4. **Agents**: existence of agent definitions
5. **Hooks**: validity of hooks.json
6. **Scripts**: existence and execute permissions of automation scripts
7. **Documentation**: required docs such as the README

### Expected output

```
==========================================
Claude harness - Plugin validation test
==========================================

1. Validating the plugin structure
----------------------------------------
✓ plugin.json exists
✓ plugin.json is valid JSON
✓ plugin.json has a name field
✓ plugin.json has a version field
...

==========================================
Test result summary
==========================================
Passed: 25
Warnings: 1
Failed: 0

✓ All tests passed!
```

## Adding Tests

When you add a new command or skill, run this test to confirm that the structure is correct.

## Use in CI/CD

In GitHub Actions, `.github/workflows/validate-plugin.yml` runs the following:

- `./tests/validate-plugin.sh`
- `./scripts/ci/check-consistency.sh`
- `cd core && npm test`

The success / failure fixtures for `/harness-work all` are managed separately as smoke / full. For details, see [docs/evidence/work-all.md](../docs/evidence/work-all.md).

## Troubleshooting

### The jq command is not found

The test scripts use the `jq` command. If it is not installed:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (WSL)
sudo apt-get install jq
```

### When a test fails

1. Check the error message
2. Check whether the relevant file exists
3. Check for syntax errors in the JSON files

## Points for VibeCoders

- **Simple**: no complex test framework needed
- **Practical**: detects the structural errors that actually cause problems
- **Fast**: completes in seconds
- **Easy to understand**: the results are clear at a glance

This test is meant for quickly confirming that "nothing is broken" after you change the plugin.
