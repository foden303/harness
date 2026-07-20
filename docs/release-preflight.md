# Release Preflight

`scripts/release-preflight.sh` is a read-only check that stops you early to ask "is it OK to release now?" before publishing.
It assumes vendor neutrality, so it does not depend on AWS lock-in or any specific deploy platform.

## What It Checks

- Whether the working tree is clean
- Whether `CHANGELOG.md` has an `[Unreleased]` section
- Whether `.env.example` and `.env` have drifted much. For repos without `.env`, it only warns and does not over-block operations that assume managed secrets
- Whether the existing `healthcheck` / `preflight` commands pass
- Warns whether residue such as `mockData` / `dummy` / `localhost` / `TODO` / `FIXME` remains in the shipped surface of `agents/` / `core/` / `hooks/` / `scripts/`
- Runs `bash scripts/sync-skill-mirrors.sh --check` before tag creation to check that skill mirror drift is 0
- Whether the latest CI status succeeded, when it can be obtained

The mirror drift gate is a fail gate before the release tag. If `sync-skill-mirrors.sh --check` detects a diff, preflight fails; commit that diff and then proceed to tag creation.

Actions runtime audit (2026-05-11): repo workflows use `actions/checkout@v6`; Node setup uses `actions/setup-node@v6`; Go setup uses `actions/setup-go@v6`. These v6 action lines run on the Node 24 action runtime and avoid the Node 20 deprecation warning.

## Usage

```bash
scripts/release-preflight.sh
scripts/release-preflight.sh --root /path/to/other/repo
```

## Environment Variables

- `HARNESS_RELEASE_PROJECT_ROOT`: root when you want to inspect a different repo
- `HARNESS_RELEASE_HEALTHCHECK_CMD`: repo-specific healthcheck command
- `HARNESS_RELEASE_CI_STATUS_CMD`: command to override the CI status check

## Relationship to dry-run

Even with `/release --dry-run`, preflight always runs.
dry-run means "do not perform the publish operation," and preflight means "confirm whether the state is OK to publish."
They are different things, so do not skip preflight even in dry-run.

## GitHub Release workflow

In `.github/workflows/release.yml` as well, run `bash ./scripts/release-preflight.sh --check-adapters` before creating the GitHub Release or uploading assets to an existing release.

The tag-triggered workflow runs on a detached HEAD, so when CI status cannot be obtained, treat it as a warning boundary. Judge release-readiness on the premise that preflight failures such as clean tree, mirror drift, adapter smoke, and distribution archive gate are all 0.

`tests/test-distribution-archive.sh` verifies the shape of the distribution from `git archive HEAD`. This verifies the committed artifact and does not include dirty / untracked local files. Therefore, use it together with the clean-tree preflight before a release claim.
