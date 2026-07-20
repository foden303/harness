# Output Governance Policy

Last updated: 2026-05-05

This document defines the safety policy for when hooks or automatic formatting processes handle Claude Code tool output.

## In one line

`PostToolUse.hookSpecificOutput.updatedToolOutput` is not used by default.
When used, it is limited to opt-in redaction / compaction / normalization, and must not erase the audit trail or review / test evidence.

## By analogy

Tool output is like the surveillance camera footage of a worksite.
You may summarize it for readability, but you must not arbitrarily cut out the parts that would serve as evidence of an incident.

## Policy

| Item | Decision |
|------|------|
| Default behavior | Do not return `updatedToolOutput` |
| Permitted uses | Explicitly opt-in redaction, compaction, normalization |
| Prohibited uses | Concealing test failures, review findings, security findings, command errors |
| Audit trail | Keep the storage location of the original output, the reason for the transformation, and the transformation rules |
| Output contract | stdout is a single JSON object. Emit explanatory logs to stderr |

## Permitted transformations

### Redaction

A transformation that hides secret information.

Examples:

- Replace an API key with `<REDACTED:api-key>`
- Replace an access token with `<REDACTED:token>`
- Replace personal information with `<REDACTED:personal-data>`

Prohibited:

- Deleting entire error lines
- Erasing a failing test name
- Erasing the file:line of a review finding

### Compaction

A transformation that shortens huge output.

Examples:

- Collapse duplicate lines in success logs
- Summarize a dependency install log of 1000+ lines
- Keep `full_output_path` at the end and save the full text to a file

Prohibited:

- Omitting the failure summary
- Erasing both the head and tail of a stack trace
- Erasing the failure locations of `pytest`, `vitest`, `go test`, `npm test`

### Normalization

A transformation that unifies display variations.

Examples:

- Turn an absolute temp path into a stable placeholder
- Turn a timestamp into `<TIMESTAMP>`
- Remove the control characters of a progress spinner

Prohibited:

- Changing the meaning of the exit code
- Making stderr appear as success
- Replacing the verdict words of a review / test

## JSON stdout contract

When a hook returns structured output to Claude Code, stdout must be JSON only.
Emit human-facing logs to stderr.

Minimal form:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse"
  }
}
```

When using `updatedToolOutput`:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "updatedToolOutput": "redacted or compacted tool output",
    "additionalContext": "Output was redacted with policy output-governance.v1. Full output is stored at .claude/state/audit/tool-output/<id>.log."
  }
}
```

Required conditions:

1. Do not mix anything other than JSON into stdout.
2. When returning `updatedToolOutput`, verify the opt-in setting.
3. Save the full output or a restorable audit record.
4. Keep the transformation reason and transformation type in `additionalContext` or the audit record.
5. Do not delete review / test evidence.

## Harness default

By default, Harness does not use `updatedToolOutput`.
The reason is that arbitrarily shortening review or test evidence makes it impossible to later trace "was it really failing" and "what was fixed".

Only when needed, specify the following explicitly in an individual hook.

```json
{
  "outputTransform": {
    "enabled": true,
    "mode": "redact",
    "auditTrail": true
  }
}
```

This setting name is an example at the policy level; the implementation side only needs an equivalent opt-in.
What matters are the three points: "do not modify by default", "if modified, make it traceable", and "do not erase quality evidence".
