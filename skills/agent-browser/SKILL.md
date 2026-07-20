---
name: agent-browser
description: "Browser automation through the repo agent-browser CLI. Explicit helper for navigation, forms, screenshots, scraping, and web-app checks. Prefer Browser Use or Playwright when available. Do NOT load for: sharing URLs, embedding links, or editing screenshot files."
description-en: "Browser automation through the repo agent-browser CLI. Explicit helper for navigation, forms, screenshots, scraping, and web-app checks. Prefer Browser Use or Playwright when available. Do NOT load for: sharing URLs, embedding links, or editing screenshot files."
allowed-tools: ["Bash", "Read"]
user-invocable: false
disable-model-invocation: true
context: fork
argument-hint: "[url] [--headless]"
---

# Agent Browser Skill

A browser automation skill. Uses the agent-browser CLI to perform UI debugging, verification, and automated operations.

---

## Trigger phrases

This skill auto-loads on the following phrases:

- "open this page", "check this URL"
- "click", "type", "fill in the form"
- "take a screenshot"
- "check the UI", "test the screen"
- "open this page", "click on", "fill the form", "screenshot"

---

## Feature details

| Feature | Details |
|------|------|
| **Browser automation** | See [references/browser-automation.md](${CLAUDE_SKILL_DIR}/references/browser-automation.md) |
| **AI snapshot workflow** | See [references/ai-snapshot-workflow.md](${CLAUDE_SKILL_DIR}/references/ai-snapshot-workflow.md) |

## Execution steps

### Step 0: Verify agent-browser

```bash
# Check installation
which agent-browser

# If not installed
npm install -g agent-browser
agent-browser install
```

### Step 1: Classify the user request

| Request type | Action |
|----------------|---------------|
| Open a URL | `agent-browser open <url>` |
| Click an element | snapshot → `agent-browser click @ref` |
| Fill a form | snapshot → `agent-browser fill @ref "text"` |
| Check state | `agent-browser snapshot -i -c` |
| Screenshot | `agent-browser screenshot <path>` |
| Debug | `agent-browser --headed open <url>` |

### Step 2: AI snapshot workflow (recommended)

For most operations, first **take a snapshot**, then operate using element references:

```bash
# 1. Open the page
agent-browser open https://example.com

# 2. Take a snapshot (for AI, interactive elements only)
agent-browser snapshot -i -c

# Example output:
# - link "Home" [ref=e1]
# - button "Login" [ref=e2]
# - input "Email" [ref=e3]
# - input "Password" [ref=e4]
# - button "Submit" [ref=e5]

# 3. Operate using element references
agent-browser click @e2           # Click the Login button
agent-browser fill @e3 "user@example.com"
agent-browser fill @e4 "password123"
agent-browser click @e5           # Submit
```

### Step 3: Verify the result

```bash
# Check the current state with a snapshot
agent-browser snapshot -i -c

# Or check the URL
agent-browser get url

# Take a screenshot
agent-browser screenshot result.png
```

---

## Quick reference

### Basic operations

| Command | Description |
|---------|------|
| `open <url>` | Open a URL |
| `snapshot -i -c` | Snapshot for AI |
| `click @e1` | Click an element |
| `fill @e1 "text"` | Fill a form |
| `type @e1 "text"` | Type text |
| `press Enter` | Press a key |
| `screenshot [path]` | Screenshot |
| `close` | Close the browser |

### Navigation

| Command | Description |
|---------|------|
| `back` | Go back |
| `forward` | Go forward |
| `reload` | Reload |

### Information retrieval

| Command | Description |
|---------|------|
| `get text @e1` | Get text |
| `get html @e1` | Get HTML |
| `get url` | Current URL |
| `get title` | Page title |

### Waiting

| Command | Description |
|---------|------|
| `wait @e1` | Wait for an element |
| `wait 1000` | Wait 1 second |

### Debugging

| Command | Description |
|---------|------|
| `--headed` | Show the browser |
| `console` | Console logs |
| `errors` | Page errors |
| `highlight @e1` | Highlight an element |

---

## Session management

Manage multiple tabs/sessions in parallel:

```bash
# Specify a session
agent-browser --session admin open https://admin.example.com
agent-browser --session user open https://example.com

# List sessions
agent-browser session list

# Operate in a specific session
agent-browser --session admin snapshot -i -c
```

---

## Choosing between MCP browser tools

| Tool | Recommendation | Use case |
|--------|--------|------|
| **agent-browser** | ★★★ | First choice. Its AI-oriented snapshots are powerful |
| chrome-devtools MCP | ★★☆ | When Chrome is already open |
| playwright MCP | ★★☆ | Complex E2E tests |

**Principle**: Try agent-browser first, and only use the MCP tools when it does not work.

---

## Notes

- agent-browser runs in headless mode by default
- The `--headed` option shows the browser
- A session is kept alive until you explicitly `close` it
- Use sessions for sites that require authentication
