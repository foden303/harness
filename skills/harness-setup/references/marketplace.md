# Harness Setup Reference: marketplace

This file is part of `${CLAUDE_SKILL_DIR}/references/` for `harness-setup`.

## Plugin install (v2.1.71+ Marketplace)

v2.1.71 significantly improved Marketplace stability.
The plugin / managed settings policy for Claude Code 2.1.117-2.1.118 and later is
governed by `docs/plugin-managed-settings-policy.md` as the source of truth.

### Recommended install method

```bash
# Pin the version with @ref format (recommended)
claude plugin install owner/repo@v4.0.0

# Latest version
claude plugin install owner/repo
```

The `owner/repo@vX.X.X` format is recommended. Thanks to the `@ref` parser fix, tags, branches, and commit hashes all resolve accurately.

### Update

```bash
claude plugin update owner/repo
```

v2.1.71 fixed merge conflicts during update, enabling stable updates.

### Other improvements

- MCP server deduplication: automatically prevents multiple registrations of the same MCP server
- `/plugin uninstall` uses `settings.local.json`: reflected accurately in the user's local settings

### Managed marketplace / dependency policy (v2.1.117+)

To control the plugin marketplace in enterprise use, use Claude Code's built-in managed settings.
Harness does not layer its own marketplace resolver or dependency resolver on top.

| Item | Purpose | Harness's handling |
|------|---------|--------------------|
| `extraKnownMarketplaces` | Recommend and register marketplaces for the team | Prefer this in normal onboarding |
| `blockedMarketplaces` | Block specific marketplace sources | Managed settings only. Not in defaults for regular users |
| `strictKnownMarketplaces` | Allow adding only approved marketplace sources | Managed settings only. Not in defaults for regular users |
| Plugin dependency auto-resolve | Auto-install `dependencies` / missing dependency hints | Leave to Claude Code. Harness adds no custom resolver |
| Plugin `themes/` directory | A plugin distributes themes | P: future task for now. Harness does not bundle themes |

`DISABLE_AUTOUPDATER` stops automatic updates.
`DISABLE_UPDATES` stops even manual `claude update`, suited to enterprise fixed-version operation.
Put neither in Harness project defaults; organizations that need them configure via managed settings or device management.

If a dependency is missing, first check Claude Code's `/plugin` Errors, `/doctor`, and `claude plugin list --json`.
If an unregistered marketplace is the cause, register it with `/plugin marketplace add` or `claude plugin marketplace add` and leave auto-resolve to the core.

