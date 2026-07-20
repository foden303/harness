# AI Snapshot Workflow

An AI-agent-oriented workflow that leverages agent-browser's `snapshot` command.

---

## Overview

The `snapshot` command retrieves the page's accessibility tree and assigns a reference ID (`@e1`, `@e2`, etc.) to each element. This provides:

1. **No CSS selectors needed**: no reliance on dynamic IDs or class names
2. **Context awareness**: each element's role (button, input, link) is clear
3. **Deterministic operations**: references like `@e1` let you operate reliably

---

## Basic workflow

### Step 1: Open the page

```bash
agent-browser open https://example.com
```

### Step 2: Take a snapshot

```bash
agent-browser snapshot -i -c
```

**Option descriptions**:
- `-i, --interactive`: show only interactive elements (buttons, links, input fields, etc.)
- `-c, --compact`: remove empty structural elements to keep it compact

**Example output**:
```
✓ Example Domain
  https://example.com/

- link "Home" [ref=e1]
- link "About" [ref=e2]
- button "Login" [ref=e3]
- input "Search" [ref=e4]
- button "Search" [ref=e5]
```

### Step 3: Operate using element references

```bash
# Click a link
agent-browser click @e1

# Fill the search form
agent-browser fill @e4 "search query"

# Click the search button
agent-browser click @e5
```

### Step 4: Verify the result

```bash
# Snapshot the new state
agent-browser snapshot -i -c
```

---

## Snapshot option details

### `-i, --interactive`

Show only interactive elements. Useful for narrowing down the operation targets.

```bash
# Interactive elements only
agent-browser snapshot -i

# All elements (including text nodes)
agent-browser snapshot
```

### `-c, --compact`

Remove empty structural elements (div, span, etc. with no content).

```bash
# Compact output
agent-browser snapshot -c

# Include structure as well
agent-browser snapshot
```

### `-d, --depth <n>`

Limit the tree depth. Useful for getting an overview of large pages.

```bash
# Up to depth 3
agent-browser snapshot -d 3
```

### `-s, --selector <sel>`

Scope to a specific selector.

```bash
# Inside the form only
agent-browser snapshot -s "form.login"

# Inside the navigation only
agent-browser snapshot -s "nav"
```

### Combinations

```bash
# Recommended: interactive + compact
agent-browser snapshot -i -c

# Interactive elements inside the form only
agent-browser snapshot -i -c -s "form"

# Overview with a shallow tree
agent-browser snapshot -i -d 2
```

---

## Workflows by use case

### Login flow

```bash
# 1. Open the login page
agent-browser open https://example.com/login

# 2. Take a snapshot
agent-browser snapshot -i -c
# Output:
# - input "Email" [ref=e1]
# - input "Password" [ref=e2]
# - button "Login" [ref=e3]
# - link "Forgot password?" [ref=e4]

# 3. Enter login credentials
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password123"

# 4. Click the login button
agent-browser click @e3

# 5. Verify the result
agent-browser snapshot -i -c
agent-browser get url
```

### Form submission

```bash
# 1. Open the form page
agent-browser open https://example.com/contact

# 2. Snapshot inside the form
agent-browser snapshot -i -c -s "form"
# Output:
# - input "Name" [ref=e1]
# - input "Email" [ref=e2]
# - textarea "Message" [ref=e3]
# - button "Send" [ref=e4]

# 3. Fill in the form
agent-browser fill @e1 "John Doe"
agent-browser fill @e2 "john@example.com"
agent-browser fill @e3 "Hello, this is a test message."

# 4. Submit
agent-browser click @e4

# 5. Verify
agent-browser snapshot -i -c
```

### Navigation exploration

```bash
# 1. Open the top page
agent-browser open https://example.com

# 2. Check the navigation
agent-browser snapshot -i -c -s "nav"
# Output:
# - link "Home" [ref=e1]
# - link "Products" [ref=e2]
# - link "About" [ref=e3]
# - link "Contact" [ref=e4]

# 3. Go to the Products page
agent-browser click @e2

# 4. Check the structure of the new page
agent-browser snapshot -i -c
```

### Operating on dynamic content

```bash
# 1. Open the page
agent-browser open https://example.com/dashboard

# 2. Initial snapshot
agent-browser snapshot -i -c

# 3. Open the dropdown
agent-browser click @e5

# 4. Wait (for the dynamic content to load)
agent-browser wait 500

# 5. New snapshot (the dropdown menu is now shown)
agent-browser snapshot -i -c
# New elements appear:
# - menuitem "Option 1" [ref=e10]
# - menuitem "Option 2" [ref=e11]
# - menuitem "Option 3" [ref=e12]

# 6. Select an option
agent-browser click @e11
```

---

## Troubleshooting

### Element not found

```bash
# Full snapshot (all elements)
agent-browser snapshot

# Narrow down with a specific selector
agent-browser snapshot -s "#target-element"

# Wait, then retry
agent-browser wait 2000
agent-browser snapshot -i -c
```

### Dynamic pages

```bash
# Snapshot after running JavaScript
agent-browser eval "document.querySelector('#load-more').click()"
agent-browser wait 1000
agent-browser snapshot -i -c
```

### Elements inside an iframe

```bash
# Snapshot the main frame
agent-browser snapshot -i -c

# Elements inside an iframe cannot be accessed directly,
# so operate inside the iframe with eval
agent-browser eval "document.querySelector('iframe').contentDocument.querySelector('button').click()"
```

---

## Best practices

### 1. Always start from a snapshot

Before operating, always take a snapshot to understand the current state.

### 2. Make interactive + compact the default

```bash
agent-browser snapshot -i -c
```

### 3. Verify the state after operating

```bash
agent-browser click @e1
agent-browser snapshot -i -c  # Verify the result
```

### 4. Add appropriate waits

When there is dynamic content, add waits:

```bash
agent-browser click @e1
agent-browser wait 500
agent-browser snapshot -i -c
```

### 5. Leverage sessions

Use sessions to maintain authentication state:

```bash
agent-browser --session myapp open https://example.com/login
# ... login operations ...
# From here, continue operating in the same session
agent-browser --session myapp open https://example.com/dashboard
```
