# Claude Code Setup: MCP, Telemetry, Provider Guidance

Last updated: 2026-05-05

Operational guidance for the setup / MCP / telemetry / provider area that grew in Claude Code 2.1.120 and later.

## In one line

Harness guides Claude Code's new features without hiding them, but does not replace the meaning of the official settings.
MCP always-load, telemetry, provider, Windows shell, and deferred tools are opted into in small amounts per use case.

## An analogy

Claude Code is a toolbox, and Harness is a work-procedure manual.
Rather than arbitrarily rebuilding the contents of the toolbox, it says "for this task, have this tool out."

## Setup checklist

| Item | Harness guidance |
|------|------------------|
| `${CLAUDE_EFFORT}` | Use it only when referring to the current effort in the skill body. The decision of effort stays with the caller |
| MCP `alwaysLoad` | Set `true` only for the few tools required every turn. Large servers stay deferred |
| `claude plugin prune` | Cleanup of orphaned dependencies after plugin uninstall. `--dry-run` first |
| `claude project purge` | A strong cleanup that erases project state. `--dry-run` or `--interactive` first |
| `ANTHROPIC_BEDROCK_SERVICE_TIER` | Only Bedrock users set it in the provider environment. Do not put it in the Harness default |
| `claude_code.skill_activated.invocation_trigger` | In telemetry, view skill invocation reasons distinctly |
| PowerShell primary shell | On Windows, guide assuming PowerShell primary and avoid Bash-fixed examples |
| forked skills / subagents deferred tools | For workflows that need deferred tools on the first turn, write in a way that allows explicit tool discovery |

## Effort guidance

`${CLAUDE_EFFORT}` is a variable for referring to the current effort level from the skill body.
This is not for "the skill deciding effort itself," but for "using which effort it was called at right now" in explanations or branching.

Acceptable examples of use:

```md
Current effort: `${CLAUDE_EFFORT}`.
If effort is low, keep the review to confirmed blockers.
If effort is xhigh, include adversarial checks.
```

Examples to avoid:

- Demanding "always change to xhigh" in the skill body
- Ignoring the effort specified by the user / parent workflow
- Treating an empty `${CLAUDE_EFFORT}` as a failure

## MCP `alwaysLoad`

MCP tool search lazily loads tool schemas to save context.
`alwaysLoad: true` is a setting that excludes a server from this lazy loading, making its tools always visible at session start.

When to use:

- A small core tool server used every turn
- A server always needed at the first move of a workflow
- A few servers where tool search delays discovery and lowers work quality

When to avoid:

- Servers with many tools
- Integrations used only occasionally
- Database / observability servers with large schemas

Example:

```json
{
  "mcpServers": {
    "core-tools": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "alwaysLoad": true
    }
  }
}
```

## Plugin cleanup

`claude plugin prune` is a cleanup that removes plugins auto-installed as plugin dependencies but no longer needed.
It is not for arbitrarily removing directly installed plugins.

Recommended:

```bash
claude plugin prune --dry-run
claude plugin prune -y
```

In Harness setup, present it as post-uninstall guidance.
Do not run it unconditionally within initial setup or release procedures.

## Project state cleanup

`claude project purge [path]` is a strong cleanup that deletes the transcripts, tasks, file history, and config entries that Claude Code holds for a project.

Recommended:

```bash
claude project purge . --dry-run
claude project purge . --interactive
```

When to use:

- Archiving a project
- Erasing old local state before a team handoff
- The project path / owner changed and the old state is in the way

When to avoid:

- Work currently in progress remains
- You need to keep transcripts or the task queue as evidence
- You just "vaguely want it lighter" and have not checked the deletion targets

## Provider guidance

`ANTHROPIC_BEDROCK_SERVICE_TIER` is treated as an environment variable involved in provider-side tuning when using Bedrock.
Do not include it as a default in Harness's plugin default, templates, or shared project settings.

Reasons:

- Unnecessary for users who do not use Bedrock
- The correct value changes by team / account / region
- Provider settings are close to the user / organization responsibility boundary

Bedrock guidance keeps Claude Code's `CLAUDE_CODE_USE_BEDROCK` / `ANTHROPIC_*` series
scoped to Claude Code and does not mix them with other providers' settings.

## Telemetry guidance

`claude_code.skill_activated.invocation_trigger` is a telemetry attribute for viewing how a skill was invoked.

Representative values:

| Value | Meaning |
|----|------|
| `user-slash` | The user invoked it explicitly as a slash command |
| `claude-proactive` | Claude invoked it proactively from context |
| `nested-skill` | Invoked internally from another skill / workflow |

In Harness, we keep `user-invocable: false` skills such as media / announcement types
from presupposing `claude-proactive`.
The expected invocation is `user-slash` or `nested-skill`.

## Windows shell guidance

On Windows, when the PowerShell tool is available, treat PowerShell as the primary shell.
Avoid Git Bash-fixed guidance.

How to write:

- Also include `pwsh` / PowerShell-assuming examples
- Do not end with only POSIX-shell-specific `export`
- Be mindful of differences in path separators and quoting

## Forked skills / subagents and deferred tools

Deferred tools become necessary even in `context: fork` skills and subagents.
In the workflow body, do not leave the tools used on the first turn ambiguous, and make tool discovery explicit when needed.

Examples:

- If WebFetch is needed, include it in allowed-tools / tools
- If an MCP tool is needed, state the server name and purpose
- Write on the premise that tools may not be visible on the first turn, including search / confirmation steps

This makes it less likely to misjudge, at the first decision in a forked context, that "a tool that should be usable is missing."

## Sources

- Claude Code changelog: https://code.claude.com/docs/en/changelog
- Claude Code MCP docs: https://code.claude.com/docs/en/mcp
- Claude Code plugins reference: https://code.claude.com/docs/en/plugins-reference
