# Install, Update, Uninstall

Choose the tool you are using now before running commands.
This page keeps the Claude-first install path intact while showing candidate and
unsupported hosts without upgrading their support tier.

`not_observed != absent`: when runtime proof is missing, record `not observed`
instead of turning uncertainty into a support or rejection claim.

## Common Success Contract

Every host section has:

- first prompt,
- first command,
- verification command,
- success look.

For candidate or unsupported hosts, these fields describe a research or boundary
check. They are not install instructions.

### Claude Code (`supported`)

Install:

```bash
claude
```

Then inside Claude Code:

```text
/plugin marketplace add foden303/harness
/plugin install harness@harness-marketplace
/harness-setup
```

Update:

```text
/plugin update harness
/harness-setup
```

Uninstall:

```text
/plugin uninstall harness
```

First prompt:

```text
Plan a small change with acceptance criteria.
```

First command:

```text
/harness-plan
```

Verification command:

```text
/harness-sync
```

Success look: the session can see the Harness workflow skills, `Plans.md`
status is readable, and the next suggested action is plan, work, review, or
release instead of raw ad hoc implementation.

### Other hosts

Harness has one supported host. Adapters for other CLIs were tracked as
candidates before v1.0.0 and removed with the research files that backed them.
Adding a host back means producing its own bootstrap, skill-routing, install,
update, and uninstall evidence first — see
[tool-capability-matrix.md](../tool-capability-matrix.md).
