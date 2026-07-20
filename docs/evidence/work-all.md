# `/harness-work all` Evidence Pack

Last updated: 2026-03-06

This evidence pack is the minimal set for verifying the claims of `/harness-work all` by "what remains after you run it."
The current premise is a new contract: the Worker's self-check alone is not enough to mark a task complete; it must also pass the `sprint-contract` and an independent review artifact before completion.

## What is included

| Scenario | Goal | Expected result |
|----------|------|-----------------|
| success | Complete a small TODO repo with `work all` | Tests turn green and an additional commit remains |
| failure | Throw an impossible task and check the quality gate | Tests stay failing and no additional commit is created |

## Fixtures

- `tests/fixtures/work-all-success/`
- `tests/fixtures/work-all-failure/`

Both are built so that `npm test` fails at baseline.

## Smoke vs Full

| Mode | Command | What it does |
|------|---------|--------------|
| CI smoke | `./scripts/evidence/run-work-all-smoke.sh` | Verifies fixture consistency and baseline failure, and leaves a preview of the Claude execution command |
| Local full | `./scripts/evidence/run-work-all-success.sh --full` | Runs the success scenario with the Claude CLI, and on rate limit completes the artifact with a replay overlay |
| Local full (strict) | `./scripts/evidence/run-work-all-success.sh --full --strict-live` | Proves success with a live Claude run only, without using replay |
| Local full | `./scripts/evidence/run-work-all-failure.sh --full` | Runs the failure scenario with the Claude CLI and confirms no commit is added |

Artifacts are saved to `out/evidence/work-all/` by default.

## Prerequisites for full runs

- `claude --version` works (required when using strict live)
- Authenticated with Claude Code
- Run from the root of this repo

Full mode uses the following command internally:

```bash
claude --plugin-dir /path/to/harness \
  --dangerously-skip-permissions \
  --output-format json \
  --no-session-persistence \
  -p "$(cat PROMPT.md)"
```

## Saved artifacts

- `baseline-test.log`
- `claude-stdout.json`
- `claude-stderr.log`
- `elapsed-seconds.txt`
- `git-status.txt`
- `git-diff-stat.txt`
- `git-diff.patch`
- `git-log.txt`
- `commit-count.txt`
- `result.txt`
- `execution-mode.txt`
- `sprint-contract.json` or the contract generation log
- `review-result.json`
- `fallback-reason.txt`
- `rate-limit-detected.txt`
- `replay.log` (when a rate limit fallback occurs)

## Interpretation

- On success, if `post_test_status=0` and `final_commits > baseline_commits`, that is evidence that, for the minimal scenario, the run "completed and reached a commit"
- If `review-result.json` is also `APPROVE`, that is evidence that it "completed after passing an independent review"
- On failure, if `post_test_status!=0` and `final_commits == baseline_commits`, that is at least evidence that it "did not hide the failure and did not commit"
- If test tampering occurs in the failure fixture, it also remains in the diff artifact, making the quality gate behavior easy to review

## Live vs Replay

- `execution_mode=live` means the artifact is from the Claude CLI completing the success scenario as-is
- `execution_mode=replay-after-rate-limit` means the Claude run stopped at a rate limit, and the replay overlay bundled with the fixture was applied to build the happy-path artifact
- To claim "proven with a live Claude run" in public copy, capture a separate `--strict-live` success artifact
