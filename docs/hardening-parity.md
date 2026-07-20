# Hardening Parity

Last updated: 2026-07-20

This document lays out what Harness treats as dangerous and where each policy is
enforced on **Claude Code**, the one supported host.

Enforcement has two layers:

- **PreToolUse hooks** stop an action before it runs (the binding layer)
- **Pre-merge verification** catches what no hook surface covers

A second column for Codex CLI existed while Harness was multi-host; that backend
was removed before v1.0.0, and with it the instruction-injection substitute for
hooks.

## Policy Matrix

| Policy | Example | Severity | Claude Code |
|--------|----|----------|-------------|
| No verification bypass | `git commit --no-verify`, `git commit --no-gpg-sign` | Deny | PreToolUse deny |
| Protected branch destructive reset | `git reset --hard origin/main`, `git reset --hard main` | Deny | PreToolUse deny |
| Direct push to protected branch | `git push origin main` | Confirm | PreToolUse ask (can be set to deny / allow) |
| Force push | `git push --force`, `git push -f` | Deny | PreToolUse deny |
| Protected files editing | `package.json`, `Dockerfile`, `.github/workflows/*`, `schema.prisma`, etc. | Warn | PreToolUse approve + warning |
| Pre-push secrets scan | hardcoded secret, DB URL, private IP, token-like string | Deny | Deny or fail before the push-equivalent Bash |

## Protected Files Profile

The default protected files are narrowed to those that "have wide impact if broken, but aren't touched every time in normal implementation".

- `package.json`
- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/*.yml`
- `.github/workflows/*.yaml`
- `schema.prisma`
- `wrangler.toml`
- `index.html`

Design intent:

- **Warn, not deny, by default**
  Since there are legitimate changes, prioritize confirming intent first
- **Clearly confidential / dangerous files such as `.env` or private keys are denied by a separate rule**
  This is the responsibility of the existing protected path rule, not protected files

## Runtime Mapping

### Claude Code

For Claude Code, runtime enforcement takes priority.

- **PreToolUse**
  Deny / ask / warn on dangerous commands before execution
- **PostToolUse**
  Warn on tampering or security patterns after a write
- **PermissionRequest**
  Auto-permit only safe read-only / test commands

## Enforcement reach

Hooks stop an action before it runs, which is the strongest position Harness
has. It is not total: a tool surface with no hook (or a command shape the rule
table does not match) reaches the working tree, and worktree-escape containment
plus pre-merge verification are what catch it afterwards.

| Item | Claude Code |
|------|-------------|
| Pre-execution interruption | Possible (PreToolUse) |
| Post-execution warning | Possible (PostToolUse) |
| Per-command deny | Strong, rule-table driven |
| Blocking before merge into main | Possible |
| protected files | Warn-centered |
| direct push / force push | Detectable at runtime |

## Operator Guidance

- Irreversible git operations (`--force`, `reset --hard`) stay operator-run by
  design; Harness denies them rather than asking.
- Work touching protected files or release areas should expect a warn, then a
  pre-merge check — not a silent pass.

## Validation Surface

At minimum, aim for a state where the `validate-plugin` family can verify that the following 4 points are in place.

- A shared policy document exists
- The Claude Code guardrail has the target rules
- The rule table and this document do not disagree on severity
