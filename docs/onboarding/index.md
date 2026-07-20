# Tool-First Onboarding

Start here by choosing the tool you are using now.
Claude Code Harness is still Claude-first, but Phase 73 makes the entry point
explicit for every host so users do not mistake a candidate route for a proven
install path.

Detailed commands live in [install.md](install.md). Existing users should run
the report-first migration path in [migration.md](migration.md) before cleanup.

## Support Tier Rule

Public wording must keep these tiers unchanged:

| Tool | Support tier | Start here |
|---|---|---|
| Claude Code | `supported` | Use the Claude plugin install path in [install.md](install.md#claude-code-supported). |
| Any other CLI | no claim | See [Other hosts](install.md#other-hosts). |

`not_observed != absent`: missing local runtime evidence means the capability is
not observed in the current artifact set. It does not prove the capability is
absent.

## Choose The Route

| If you are using... | Do this first | Do not claim |
|---|---|---|
| Claude Code | Install the marketplace plugin, then run `/harness-setup`. | Generic multi-host support beyond proven gates. |
| Any other CLI | Nothing — there is no Harness route for it. | Install, setup, bootstrap, or adapter support. |

## First Successful Session

A route is usable only when it has all of these:

- first prompt,
- first command,
- verification command,
- success look,
- support tier and known asymmetry.

For candidate and unsupported hosts, the success look is not "installed". It is
"the boundary stayed honest": evidence is recorded as `candidate`,
`future/unsupported`, `manual`, or `not observed`.
