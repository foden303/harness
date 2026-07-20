# Plugin and Managed Settings Policy

Last updated: 2026-05-03

This document fixes the operational decisions around the plugin / managed settings / managed sandbox features added in Claude Code `2.1.117-2.1.126`, as Harness setup guidance.

## In one line

Harness helps explain the safe operation of the plugin marketplace, but it does not replace Claude Code's own resolver or managed settings enforcement.

## An analogy

In a building's access control, Harness is the signboard that tells employees which entrance to use. The actual turnstile that inspects entry passes is Claude Code itself. If the signboard built its own turnstile, the rules would be duplicated and it would become unclear which one is correct.

## Official references

- Claude Code changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code settings: <https://code.claude.com/docs/en/settings>
- Claude Code plugin dependency versions: <https://code.claude.com/docs/en/plugin-dependencies>
- Claude Code plugin install guide: <https://code.claude.com/docs/en/discover-plugins>

## Scope and decisions

| Item | Purpose | Harness decision |
|------|------|--------------|
| plugin `themes/` directory | plugin bundles a visual theme | plugin `themes/` directory is P for now. Since Harness is an operations-support plugin, it does not bundle a theme at this time |
| `DISABLE_AUTOUPDATER` | stop automatic updates | Use to adjust individual or team update timing. Does not block manual update |
| `DISABLE_UPDATES` | stop all update paths | Use only in managed environments. DISABLE_UPDATES also blocks manual `claude update` |
| `blockedMarketplaces` | block specific marketplace sources | managed settings only. Do not include in defaults aimed at regular users |
| `strictKnownMarketplaces` | allow adding only approved marketplace sources | managed settings only. Do not include in defaults aimed at regular users |
| `extraKnownMarketplaces` | announce and register a marketplace the team uses | Prefer this for normal team onboarding |
| plugin dependency auto-resolve / missing dependency hints | automatic resolution of dependency plugins and error guidance | Do not add a Harness-specific dependency resolver. Leave it to Claude Code itself |
| `wslInheritsWindowsSettings` | inherit Windows-side managed settings into WSL | Candidate for mixed Windows / WSL enterprise environments. Do not include in Harness defaults |
| `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` | move the managed sandbox allow boundary to administrator settings | managed settings only. Do not include in Harness's normal templates / plugin defaults / harness.toml, and do not override Claude Code's own precedence |

## Update controls

`DISABLE_AUTOUPDATER` is an environment variable for stopping automatic updates. Use it when you want to stop automatic updates of Claude Code itself and of plugins.

`DISABLE_UPDATES` is a stronger management-oriented environment variable. It stops not only automatic updates but also manual `claude update`. This is for environments where an enterprise distributes only verified versions.

| Goal | What to use | Caveat |
|------|----------|--------|
| An individual wants to avoid being updated unexpectedly | `DISABLE_AUTOUPDATER=1` | Manual updates remain available |
| An IT administrator wants to fully close off update paths | `DISABLE_UPDATES=1` | Manual `claude update` is also blocked, so provide a separate distribution/update procedure |
| Stop Claude Code core updates but keep plugin auto-updates | `DISABLE_AUTOUPDATER=1` + `FORCE_AUTOUPDATE_PLUGINS=1` | Check the plugin-side dependency constraints and marketplace policy first |

Harness policy:

- Do not include `DISABLE_UPDATES` as a default in `.claude-plugin/settings.json` or project templates.
- For enterprise distribution, set it as a managed setting or as a device-managed environment variable.
- Even when updates are stopped, keep the `harness-release` version sync / plugin tag / validate flow intact.

## Marketplace policy

`blockedMarketplaces` and `strictKnownMarketplaces` are managed settings for administrators to control marketplace sources. They are not meant to be included in defaults for regular users or open-source projects.

| Setting | What it does | When it fits |
|------|------------|----------------|
| `blockedMarketplaces` | blocks the specified marketplace sources | You want to explicitly stop dangerous or deprecated marketplaces |
| `strictKnownMarketplaces` | allows adding only marketplace sources on the allowlist | An enterprise wants to allow only vetted marketplaces |
| `extraKnownMarketplaces` | announces and registers a marketplace | You want to distribute recommended marketplaces to a team |

`strictKnownMarketplaces` is a policy gate. It only decides whether to allow; it does not automatically register a marketplace. If you also want everyone to register it, combine `strictKnownMarketplaces` and `extraKnownMarketplaces` in managed settings.

Example:

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "acme-corp/approved-plugins" }
  ],
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": {
        "source": "github",
        "repo": "acme-corp/approved-plugins"
      }
    }
  }
}
```

Harness policy:

- Do not include `blockedMarketplaces` / `strictKnownMarketplaces` in defaults for regular users.
- Harness setup announces `extraKnownMarketplaces` during team onboarding.
- In enterprise-managed environments, leave it to the top precedence of managed settings.
- Do not implement a Harness-specific marketplace allowlist / blocklist evaluator.

## Dependency resolution

Claude Code reads a plugin's `dependencies` and automatically resolves dependency plugins at install time. If a dependency goes missing later, it is resolved from the configured marketplace via `/reload-plugins`, background plugin auto-update, re-running `claude plugin install`, or `claude plugin marketplace add`.

When a dependency cannot be resolved, the correct entry points are the Claude Code plugin UI, `/doctor`, and the `errors` field of `claude plugin list --json`. Do not add a Harness-specific dependency resolver.

What Harness does:

- In setup docs, advise following Claude Code's hints for missing dependencies.
- In release docs, use `claude plugin tag` and version constraints to create tags that make dependency resolution easier.
- If the marketplace is not registered, advise using `/plugin marketplace add` or `claude plugin marketplace add` first.

What Harness does not do:

- Do not go find and install a plugin from another marketplace on its own.
- Do not interpret `dependencies` in its own way and directly rewrite the cache.
- Do not build a resolver that bypasses `blockedMarketplaces` / `strictKnownMarketplaces`.

## Plugin prune

`claude plugin prune` is a cleanup command that removes automatically installed dependency plugins that are no longer needed. It targets plugins that Claude Code installed to satisfy another plugin's `dependencies`; it is not meant to arbitrarily remove plugins the user installed directly.

Harness policy:

- Use it as cleanup guidance after a plugin uninstall.
- Advise `claude plugin prune --dry-run` first.
- Use `-y` only when running in non-interactive CI.
- Do not run it unconditionally as part of release / setup.
- If there is state that should be kept under `${CLAUDE_PLUGIN_DATA}`, consider `--keep-data` on the uninstall side.

Recommended example:

```bash
claude plugin prune --dry-run
claude plugin prune -y
```

## Project purge

`claude project purge [path]` is a strong cleanup command that deletes the transcripts, tasks, file history, and config entry that Claude Code holds for a project.

Harness policy:

- Advise it only when there is a clear reason to erase local Claude state, such as archiving, handoff, or a path / owner change.
- Use `--dry-run` or `--interactive` first.
- Do not use it when in-progress tasks, review evidence, or handoff records are needed.
- Do not treat it as an alternative cleanup for Harness's `Plans.md` or git history.

Recommended example:

```bash
claude project purge . --dry-run
claude project purge . --interactive
```

## Plugin-bundled hooks

Plugins can bundle hooks, but Harness avoids a design where "just installing a plugin runs strong side effects."

Harness policy:

- Make bundled hooks opt-in by default.
- Disable writes, pushes, deploys, external sends, and tool-output modification by default.
- When using `PostToolUse.hookSpecificOutput.updatedToolOutput`, follow `docs/output-governance.md`.
- Hook stdout must honor the JSON contract; human-facing logs go to stderr.

Reason:

A plugin sits close to the trust boundary. If a project's behavior changes significantly just because a user enabled it, tracing causes and confirming safety become difficult.

## Themes decision

In Claude Code `2.1.118`, `/theme` can create and switch named custom themes, and a plugin can bundle a `themes/` directory.

The decision this time:

- Harness does not bundle a theme this time.
- In Phase 53 it stays as `P: future task`.
- The reason is that Harness's core value is the operational safety of Plan / Work / Review, and a distributed theme needs a separate review for branding, accessibility, and terminal compatibility.

If a theme is added in the future, do so only after meeting the following:

1. Readable in both light / dark terminals.
2. `/plugin` badges and warning text are not garbled.
3. Consistent with Harness's docs / screenshots / release copy.
4. The features work fully even without the theme.

## Windows / WSL managed settings

`wslInheritsWindowsSettings` is for enterprise environments that want to inherit Windows-side managed settings into WSL. In companies that use Claude Code on both Windows and WSL, it reduces double-managing settings.

Harness policy:

- Do not include it in Harness defaults.
- Only organizations that do device management for Windows / WSL should consider it.
- Because unintended strong policy entering the WSL side can affect the development experience, confirm the active settings source with `/status` before adopting it.

## Managed sandbox precedence

Claude Code `2.1.126` added precedence hardening for `allowManagedDomainsOnly` and `allowManagedReadPathsOnly`.

This is a safety-side change that prevents a project-local template or plugin default from loosening the sandbox boundary an administrator has decided to allow only "this range."

Harness policy:

- Treat `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` as managed settings only.
- Do not include them as defaults in Harness's normal distribution artifacts: `harness.toml`, `.claude-plugin/settings.json`,
  `templates/claude/settings.security.json.template`, and
  `templates/sandbox-settings.json.template`.
- When using them in an enterprise-managed environment, make device management or Claude Code's managed settings the source of truth.
- Harness does not build its own managed sandbox resolver.
- `scripts/ci/check-consistency.sh` regression-checks that these managed-only keys do not leak into the normal templates.

## Why this way

The plugin marketplace and managed settings are the trust boundary itself. A trust boundary is the line that decides "from where onward do we consider things safe." Claude Code itself should handle this line, through managed settings precedence and pre-install checks.

On top of that, Harness adds the work quality and guardrails of Plan / Work / Review. So rather than building the inspection machine itself, Harness takes the approach of documenting the correct operation that uses the official mechanisms, and stopping drift in the explanation with the necessary tests.
