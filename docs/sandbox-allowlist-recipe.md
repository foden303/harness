# Sandbox Allowlist Recipe (for Firecrawl / Web Scraping)

A recipe for when Firecrawl, tech-blog fetching, or external API calls are blocked with `HTTP/2 403 / x-deny-reason: host_not_allowed` in another project that installed harness.

> **TL;DR**: The CC sandbox defaults to an **empty allowlist = deny all**. The proper route is to add `sandbox.network.allowedDomains` to the user-global `~/.claude/settings.json`. Rewriting via AI is denied by the self-audit guard, so **edit manually as the user**.

## Symptoms

In an external project, Firecrawl CLI / WebFetch / curl returns 403 / connection refused. The Bash subprocess log shows the following:

```
HTTP/2 403
x-deny-reason: host_not_allowed
```

or

```
curl: (6) Could not resolve host: api.firecrawl.dev
```

## Cause

The Claude Code sandbox (macOS Seatbelt / Linux bubblewrap) is **allowlist by default**. No `sandbox.network.allowedDomains` in `~/.claude/settings.json` means no outbound communication to any host.

Checking the Firecrawl plugin's `SKILL.md` shows `allowed-tools: Bash(firecrawl *)`. In other words, the Firecrawl CLI runs as a Bash subprocess and is directly affected by the sandbox (it is not an MCP server).

## Migration: runtime floor secret allow moves to plan-time pre-approval

Avoid broad, permanent secret-read allow declarations like `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` in new operations.
Instead, at plan confirmation in `/harness-plan create`, emit a **pre-approval section** and approve, in bulk, the secret-read paths / external sends / destructive operations needed per task scope.

The approval results are saved to `.claude/state/plan-preapprovals.json` (`plan-preapproval.v1`), and at the start of a `/harness-work` / `/breezing` run, `scripts/plan-preapproval.sh apply-secret-allow "$PROJECT_ROOT"` reflects only approved `secret-read` paths into the project config's `runtimefloor.secretAllow`.
Unplanned secret-read / external sends not in the record still stop at the runtime floor / ask as before, so the safety net is not narrowed.

## Solution: merge sandbox settings into `~/.claude/settings.json`

**Important**: There are 2 cases depending on **whether a `sandbox` key already exists** in `~/.claude/settings.json`. Accidentally overwriting an existing sandbox erases existing guardrails such as `failIfUnavailable` / `filesystem.denyRead` / `network.deniedDomains`.

### Step 0: Check whether an existing sandbox is present

```bash
jq 'has("sandbox")' ~/.claude/settings.json
# false → Case A (new addition)
# true  → Case B (inner merge)
```

### Case A: When no `sandbox` key exists (new addition)

Add a single `sandbox` key at **the same level (top-level)** as existing `permissions` / `hooks` / `enabledPlugins` / `mcpServers`, etc. Do not touch existing keys:

```json
{
  "permissions": { /* keep existing */ },
  "hooks": { /* keep existing */ },
  "enabledPlugins": { /* keep existing */ },
  "mcpServers": { /* keep existing */ },
  /* ... keep all other existing top-level keys ... */

  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": [
      "docker", "docker-compose", "watchman",
      "systemctl", "launchctl", "brew services"
    ],
    "network": {
      "allowedDomains": [
        "github.com", "api.github.com", "raw.githubusercontent.com",
        "codeload.github.com", "objects.githubusercontent.com",
        "registry.npmjs.org", "api.anthropic.com",
        "pypi.org", "files.pythonhosted.org",
        "proxy.golang.org", "sum.golang.org",
        "crates.io", "static.crates.io", "rubygems.org",
        "api.firecrawl.dev", "firecrawl.dev",
        "techblog.zozo.com", "note.com", "assets.st-note.com",
        "zenn.dev", "qiita.com", "dev.to", "medium.com",
        "cdn-ak.f.st-hatena.com",
        "engineering.dena.com", "developers.cyberagent.co.jp",
        "tech.uzabase.com", "engineer.crowdworks.jp", "tech.smarthr.jp"
      ],
      "deniedDomains": [
        "169.254.169.254", "metadata.google.internal", "metadata.azure.com",
        "pastebin.com", "transfer.sh", "0x0.st",
        "paste.ee", "termbin.com", "ix.io"
      ]
    }
  }
}
```

### Case B: When a `sandbox` key already exists (inner merge)

**Keeping** existing `sandbox.failIfUnavailable` / `sandbox.filesystem` / `sandbox.network.deniedDomains`, etc., add / consolidate fields on the inside. **Replacing the entire `sandbox` block is prohibited** (it destroys existing guardrails).

merge rules:

| Field | Operation | Note |
|------|------|------|
| `sandbox.enabled` | Set to `true` | Keep if already `true` |
| `sandbox.autoAllowBashIfSandboxed` | Set to `true` | New addition |
| `sandbox.failIfUnavailable` | **Keep existing** | Do not touch |
| `sandbox.excludedCommands` | If an array, **union (dedupe and merge)**; if absent, add new | Do not remove existing items |
| `sandbox.network.allowedDomains` | **Union of the existing array + this recipe's 29 entries** | Do not remove existing hosts |
| `sandbox.network.deniedDomains` | **Union of the existing array + this recipe's 9 entries** | Keep existing blocked hosts |
| `sandbox.filesystem` | **Keep existing** | Do not touch (denyRead/allowRead etc. would be erased) |

### jq one-liner for automatic merge (works for both Case A / B)

Manual merge in an editor carries a high risk of duplication and guardrail erasure. The following jq one-liner is safe for both cases:

```bash
SETTINGS=~/.claude/settings.json

# 1. Save the original file mode (handles cases protected with 600 etc. because it contains a token)
#    cross-platform stat: try Linux GNU stat -c first, fall back to macOS BSD stat -f
#    (order matters: BSD stat -f misbehaves as a filesystem-status flag on Linux)
MODE=$(stat -c '%a' "$SETTINGS" 2>/dev/null || stat -f '%Lp' "$SETTINGS")

# 2. backup (cp -p preserves mode/ownership)
cp -p "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"

# 3. merge (keep existing sandbox.filesystem / failIfUnavailable; arrays are unioned)
jq '
  .sandbox.enabled = true |
  .sandbox.autoAllowBashIfSandboxed = true |
  .sandbox.excludedCommands = (((.sandbox.excludedCommands // []) + [
    "docker", "docker-compose", "watchman",
    "systemctl", "launchctl", "brew services"
  ]) | unique) |
  .sandbox.network.allowedDomains = (((.sandbox.network.allowedDomains // []) + [
    "github.com", "api.github.com", "raw.githubusercontent.com",
    "codeload.github.com", "objects.githubusercontent.com",
    "registry.npmjs.org", "api.anthropic.com",
    "pypi.org", "files.pythonhosted.org",
    "proxy.golang.org", "sum.golang.org",
    "crates.io", "static.crates.io", "rubygems.org",
    "api.firecrawl.dev", "firecrawl.dev",
    "techblog.zozo.com", "note.com", "assets.st-note.com",
    "zenn.dev", "qiita.com", "dev.to", "medium.com",
    "cdn-ak.f.st-hatena.com",
    "engineering.dena.com", "developers.cyberagent.co.jp",
    "tech.uzabase.com", "engineer.crowdworks.jp", "tech.smarthr.jp"
  ]) | unique) |
  .sandbox.network.deniedDomains = (((.sandbox.network.deniedDomains // []) + [
    "169.254.169.254", "metadata.google.internal", "metadata.azure.com",
    "pastebin.com", "transfer.sh", "0x0.st",
    "paste.ee", "termbin.com", "ix.io"
  ]) | unique)
' "$SETTINGS" > "${SETTINGS}.tmp" \
  && chmod "$MODE" "${SETTINGS}.tmp" \
  && mv "${SETTINGS}.tmp" "$SETTINGS"

# 4. Double-check the mode was preserved (should match the original mode)
#    Same order as the MODE lookup: Linux GNU stat -c → macOS BSD stat -f fallback
stat -c '%a' "$SETTINGS" 2>/dev/null || stat -f '%Lp' "$SETTINGS"
```

> **Why `chmod "$MODE"` is needed**: The `>` redirect + `mv` pattern creates the tmp file with umask (typically `022` → 644), so if the original `~/.claude/settings.json` was `600` (protected with strong permissions because it contains a token / secret), a security regression that **widens read access** occurs after the merge. Restoring the original mode explicitly with `chmod "$MODE"` keeps even token-containing files safe.

> **Why AI cannot run this jq**: `~/.claude/settings.json` is a target of AI self-tampering prevention (`Edit/Write(.claude/settings*)` deny + the auto mode classifier also blocks bypasses via Bash). This recipe assumes **the user runs it themselves in a terminal**.

### Verification

```bash
# JSON syntax
jq -e '.' ~/.claude/settings.json > /dev/null && echo "VALID JSON"

# allowedDomains count
# Case A (no existing sandbox): exactly 29
# Case B (existing sandbox): 29 or more (union with existing gives 29 + the existing extras)
jq '.sandbox.network.allowedDomains | length' ~/.claude/settings.json

# deniedDomains count
# Case A: exactly 9 / Case B: 9 or more
jq '.sandbox.network.deniedDomains | length' ~/.claude/settings.json

# Whether the required hosts are present (minimum condition common to Case A / B)
# Note: jq array `contains` is a string substring match, so "www.firecrawl.dev" is
# wrongly judged to contain "firecrawl.dev". Use any(. == "...") for an exact match
# (any() contains no !, so there is also no clash with zsh history expansion)
jq -e '
  (.sandbox.network.allowedDomains | any(. == "api.firecrawl.dev")) and
  (.sandbox.network.allowedDomains | any(. == "firecrawl.dev")) and
  (.sandbox.network.deniedDomains | any(. == "169.254.169.254")) and
  (.sandbox.network.deniedDomains | any(. == "pastebin.com"))
' ~/.claude/settings.json && echo "REQUIRED HOSTS PRESENT"

# Case B only: whether the existing filesystem section is intact
jq '.sandbox.filesystem // "no filesystem section (Case A)"' ~/.claude/settings.json

# Whether the existing enabledPlugins is intact (common to Case A / B)
jq '.enabledPlugins | length' ~/.claude/settings.json
# → keeps the existing count
```

### Restart CC

Sandbox settings are **read only at session start**. After the merge, initialize by fully restarting CC (cmd+Q → restart).

## Design intent

A design that pre-authorizes in 3 tiers:

| Tier | Domains | Use |
|------|---------|------|
| **Dev core** (14) | `github.com` / `api.github.com` / `raw.githubusercontent.com` / `codeload.github.com` / `objects.githubusercontent.com` / `registry.npmjs.org` / `api.anthropic.com` / `pypi.org` / `files.pythonhosted.org` / `proxy.golang.org` / `sum.golang.org` / `crates.io` / `static.crates.io` / `rubygems.org` | npm install / pip install / go mod / cargo / git clone |
| **Firecrawl** (2) | `api.firecrawl.dev` / `firecrawl.dev` | Firecrawl API endpoint |
| **Scrape targets** (13) | `techblog.zozo.com` / `note.com` / `assets.st-note.com` / `zenn.dev` / `qiita.com` / `dev.to` / `medium.com` / `cdn-ak.f.st-hatena.com` / `engineering.dena.com` / `developers.cyberagent.co.jp` / `tech.uzabase.com` / `engineer.crowdworks.jp` / `tech.smarthr.jp` | Scraping Japanese/English tech blogs and articles |

The 9 `deniedDomains` (cloud metadata endpoints and pastebin-type sites) are kept as a **block on SSRF + data-exfiltration paths**. Even if allowed via `allowedDomains`, these take precedence and are denied.

## Meaning of each sandbox option

| Key | Value | Meaning |
|------|-----|------|
| `enabled` | `true` | Turn the sandbox ON from CC startup. No need for manual startup with the `/sandbox` command |
| `autoAllowBashIfSandboxed` | `true` | Bash subprocesses confined to the sandbox are auto-approved without a permission dialog. Autonomous sessions do not stall |
| `excludedCommands` | `docker / docker-compose / watchman / systemctl / launchctl / brew services` | OS-level commands that cannot run inside the sandbox are offloaded to run outside it |
| `network.allowedDomains` | 29 entries | Hosts allowed for outbound communication |
| `network.deniedDomains` | 9 entries | Denied even if on the allowlist (takes precedence) |

## Outbound communication smoke test (requires `FIRECRAWL_API_KEY`)

Confirm that it actually passes through the sandbox:

```bash
firecrawl scrape "https://techblog.zozo.com/" -o /tmp/test.md
# → on success, markdown is written to /tmp/test.md
# → on failure (HTTP/2 403 / x-deny-reason: host_not_allowed),
#   the sandbox settings are not effective (you may have forgotten to restart CC)
```

## Why AI does not edit this automatically

`~/.claude/settings.json` is a security boundary that constrains CC itself. To prevent AI from loosening its own constraints (self-tampering), CC's auto mode classifier and the `Edit(.claude/settings*)` / `Write(.claude/settings*)` deny rule block it in a **double** layer. Bypasses via Bash are also denied by the classifier as "User Deny Rules circumvention".

Therefore:
- AI side: **only presents** the patch JSON
- User side: applies + verifies manually

This is a harness **responsibility boundary**. AI is not given autonomous authority to change security settings.

## Troubleshooting

### 403 still appears after editing

1. Possible JSON syntax error. Check with `jq -e '.' ~/.claude/settings.json`
2. **Fully restart** CC (cmd+Q → restart). Sandbox settings are read at session start
3. The `FIRECRAWL_API_KEY` environment variable may be unset. Check `.zshrc`

### `EPERM` appears even after adding `filesystem` write permission

⚠️ **The key name is `allowWrite`** (official: code.claude.com/docs/en/sandboxing).
Naming it `write` makes it ignored as an unknown key, and the setting has no effect.
`~/` is expanded on the sandbox side, so the tilde form is fine (official example `["~/.kube"]`).

Fix:

```jsonc
// ❌ does not work (wrong key name = ignored)
"filesystem": { "write": ["~/.kube"] }

// ✅ works (official key)
"filesystem": { "allowWrite": ["~/.kube"] }
```

A directory specification recursively allows everything beneath it.

### A different domain is needed

Just add it to the `allowedDomains` array. CC 2.1.113+ also supports `*.example.com` wildcards, but **explicit enumeration is recommended for visibility of gaps**.

### Temporarily removing the sandbox

Set `"enabled": false`, or launch with the `--no-sandbox` flag. This regresses security, so limit it to temporary use.

## Related

- `templates/sandbox-settings.json.template` — the harness reference config. **It is fully in sync with this recipe's 29-domain allowlist + 9-domain denylist**. For bulk reuse in a new project (= no existing `sandbox` = Case A), copying the template's entire `sandbox` section is reliable. **When an existing sandbox is present (Case B), use the jq merge** (copying the whole template destroys existing `filesystem` / `failIfUnavailable`)
- `CLAUDE.md` Permission Boundaries — the sandbox settings form defense in depth with the AI self-tampering prevention layer
- `.claude/rules/cross-repo-handoff.md` — the redact design of Layer 1 (server-side) / Layer 2/3 (client-side)
- CC v2.1.108+ sandbox spec: the `sandbox` section of the official docs

## History

- 2026-05-21: Initial version. Documented in response to a case where Firecrawl returned 403 in an external project
