# Browser Automation with agent-browser

A detailed guide to browser automation using the agent-browser CLI.

---

## Installation

```bash
# Global install
npm install -g agent-browser

# Download Chromium
agent-browser install

# On Linux, install system dependencies too
agent-browser install --with-deps
```

---

## Basic operations

### Open a page

```bash
# Basic
agent-browser open https://example.com

# Open with the browser visible (for debugging)
agent-browser open https://example.com --headed

# With custom headers
agent-browser open https://api.example.com --headers '{"Authorization": "Bearer token"}'
```

### Click

```bash
# Click by element reference (recommended)
agent-browser click @e1

# Click by CSS selector
agent-browser click "button.submit"

# Double-click
agent-browser dblclick @e1
```

### Input

```bash
# Clear and fill a form
agent-browser fill @e1 "hello@example.com"

# Append (do not clear)
agent-browser type @e1 "additional text"

# Press keys
agent-browser press Enter
agent-browser press Tab
agent-browser press "Control+a"
```

### Form operations

```bash
# Checkbox
agent-browser check @e1
agent-browser uncheck @e1

# Select box
agent-browser select @e1 "option-value"

# File upload
agent-browser upload @e1 /path/to/file.pdf
```

### Scroll

```bash
# Specify a direction
agent-browser scroll down
agent-browser scroll up 500

# Scroll an element into view
agent-browser scrollintoview @e1
```

---

## Information retrieval

```bash
# Get text
agent-browser get text @e1

# Get HTML
agent-browser get html @e1

# Get an attribute
agent-browser get attr href @e1

# Get value (input)
agent-browser get value @e1

# Current URL
agent-browser get url

# Page title
agent-browser get title

# Element count
agent-browser get count "li.item"

# Element position and size
agent-browser get box @e1
```

---

## State checks

```bash
# Is it visible?
agent-browser is visible @e1

# Is it enabled (not disabled)?
agent-browser is enabled @e1

# Is it checked?
agent-browser is checked @e1
```

---

## Waiting

```bash
# Wait until an element is visible
agent-browser wait @e1
agent-browser wait "button.loaded"

# Wait by time (milliseconds)
agent-browser wait 2000
```

---

## Screenshots

```bash
# Basic
agent-browser screenshot

# Specify a filename
agent-browser screenshot output.png

# Full page
agent-browser screenshot --full page.png

# Save as PDF
agent-browser pdf document.pdf
```

---

## Running JavaScript

```bash
# Run a script
agent-browser eval "document.title"
agent-browser eval "localStorage.getItem('token')"
agent-browser eval "window.scrollTo(0, document.body.scrollHeight)"
```

---

## Network operations

```bash
# Mock a request
agent-browser network route "*/api/users" --body '{"users": []}'

# Block a request
agent-browser network route "*/analytics/*" --abort

# Remove a route
agent-browser network unroute "*/api/users"

# Request history
agent-browser network requests
agent-browser network requests --filter "api"
agent-browser network requests --clear
```

---

## Cookie/Storage

```bash
# Get cookies
agent-browser cookies get

# Set a cookie
agent-browser cookies set '{"name": "session", "value": "abc123", "domain": "example.com"}'

# Clear cookies
agent-browser cookies clear

# LocalStorage
agent-browser storage local get "key"
agent-browser storage local set "key" "value"
agent-browser storage local clear

# SessionStorage
agent-browser storage session get "key"
```

---

## Tab management

```bash
# Open a new tab
agent-browser tab new

# List tabs
agent-browser tab list

# Switch tabs
agent-browser tab 2

# Close a tab
agent-browser tab close
```

---

## Browser settings

```bash
# Viewport size
agent-browser set viewport 1920 1080

# Device emulation
agent-browser set device "iPhone 12"

# Geolocation
agent-browser set geo 35.6762 139.6503

# Offline mode
agent-browser set offline on
agent-browser set offline off

# Dark mode
agent-browser set media dark
agent-browser set media light

# Credentials
agent-browser set credentials admin password123
```

---

## Debugging

```bash
# Show console logs
agent-browser console
agent-browser console --clear

# Show page errors
agent-browser errors
agent-browser errors --clear

# Highlight an element
agent-browser highlight @e1

# Record a trace
agent-browser trace start
# ... operations ...
agent-browser trace stop trace.zip
```

---

## Find command (advanced element search)

```bash
# Search by role and click
agent-browser find role button click --name "Submit"

# Search by text
agent-browser find text "Click here" click

# Search by label
agent-browser find label "Email" fill "test@example.com"

# Search by placeholder
agent-browser find placeholder "Enter your name" fill "John"

# Search by test ID
agent-browser find testid "submit-btn" click

# First / last / nth
agent-browser find first "button" click
agent-browser find last "input" fill "text"
agent-browser find nth 2 "li" click
```

---

## Mouse operations (low-level)

```bash
# Move the mouse
agent-browser mouse move 100 200

# Mouse buttons
agent-browser mouse down
agent-browser mouse up
agent-browser mouse down right

# Wheel
agent-browser mouse wheel 100
agent-browser mouse wheel 100 50  # dy, dx
```

---

## Drag & drop

```bash
# Drag between elements
agent-browser drag @e1 @e2

# Specify coordinates
agent-browser drag @e1 "500,300"
```

---

## Session management

```bash
# Named session
agent-browser --session myapp open https://example.com

# List sessions
agent-browser session list

# Current session name
agent-browser session

# Can also be set via an environment variable
AGENT_BROWSER_SESSION=myapp agent-browser snapshot
```

---

## JSON output

```bash
# Output in JSON format
agent-browser snapshot --json
agent-browser get text @e1 --json
agent-browser network requests --json
```

---

## Custom browser

```bash
# Custom executable
agent-browser --executable-path /path/to/chrome open https://example.com

# Can also be set via an environment variable
AGENT_BROWSER_EXECUTABLE_PATH=/path/to/chrome agent-browser open https://example.com
```
