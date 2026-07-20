# Self-Audit Rule

## Integrity Detection

There is a `<!-- harness-integrity: ... -->` marker at the end of CLAUDE.md.
Detection trigger: when running `/harness-review` or at the start of a diagnostic session,
**check the end of CLAUDE.md with the Read tool** and verify the following:

1. Whether the deny entries in `.claude-plugin/settings.json` have **decreased** since the last audit
   (machine run: `bin/harness self-audit baseline --settings .claude-plugin/settings.json --baseline templates/security/deny-baseline.json`.
   The SSOT is `templates/security/deny-baseline.json`. Updating the baseline is human-only)
2. Whether the deny in `.claude-plugin/settings.json` has **all 4 patterns** of settings self-modification protection
   (`Edit/Write(.claude/settings*)` and `Edit/Write(.claude-plugin/settings*)`)
   (the deny promised by CLAUDE.md Permission Boundaries; corresponds to the gate in `tests/validate-plugin.sh`)
3. Whether a Feature Table has been appended directly to CLAUDE.md (pointer-only is correct)
4. If `.claude/settings.local.json` exists, **check its `hooks` block with Read** and
   detect whether any hook the owner did not intend (especially `command` type) has been appended.
   Since settings.local.json is usually gitignored and does not go through code review,
   hook injection here is a breeding ground for persistent code execution (persistence).
5. If there is a discrepancy, run a diagnosis with `/harness-review`

Only the human owner updates the marker. The agent only reads and detects.

## Why this rule is needed

The deny rules in settings.json are "the chains that constrain the agent itself."
If the number of chains has decreased, there is a possibility of unintended relaxation or tampering.
By detecting the direction of decrease rather than the absolute count, legitimate additions are permitted while relaxations are caught.

Monitoring hook injection into settings.local.json separately is because, whereas deny
(`Write/Edit(.claude/settings*)`) is a **preventive layer that blocks the tool path**,
a **detective backstop** is needed against residual paths such as Bash redirection (where the guardrail only warns).
The two stages of preventive (deny prevents writing) and
detective (find injection after the fact) catch tampering that "removes the chains."

## settings.local.json hook-injection detection

Harness writes no delivery hooks of its own to settings.local.json, so the
allowlist (`CCHKnownHooks` in `go/internal/selfaudit/selfaudit.go`) is empty:
**every** `command`-type hook found there is reported as a potential injection.

Machine run: `bin/harness self-audit hooks --file .claude/settings.local.json`
