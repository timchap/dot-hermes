---
name: browser-setup
description: Setup and configure browser automation tools for Hermes — agent-browser CLI, Camoufox anti-detection, Chromium/Camoufox binary paths, and headless environment.
version: 1.0.0
author: agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [browser, automation, agent-browser, camoufox, chromium, headless]
---

# Browser Automation Setup

Configure Hermes with robust browser automation for navigation, data extraction, form filling, screenshots, and dynamic/JS-rendered pages.

## When to Use

When the user needs browser automation, interactive web pages, form submission, login flows, screenshots of rendered pages, or scraping JS-heavy sites that `web_extract` can't handle.

## Architecture

Hermes ships two browser backends:

| Backend | Best for | Detectable as bot? |
|---------|----------|-------------------|
| **agent-browser + Chromium** | General automation, forms, screenshots, data extraction | Yes — use stealth features or Camoufox for sensitive sites |
| **Camoufox** | Anti-detection scraping, auth flows, YouTube transcripts, site testing | No — fingerprint-mimicking Firefox with built-in anti-detect features |

**Default**: agent-browser + system Chromium covers 90% of use cases. Fall back to Camoufox when bot detection blocks access.

## Step 1: Install Node.js Prerequisites

```bash
# Verify node + npm available
node --version    # >= 18.x
npm --version
```

## Step 2: Install agent-browser

```bash
npm install -g --prefix ~/.hermes/node --silent --ignore-scripts \
  "agent-browser@^0.26.0" \
  "@askjo/camofox-browser@^1.5.2"
```

This installs both `agent-browser` (Chromium-based automation) and `camofox-browser` (anti-detect Firefox wrapper).

## Step 3: Install Chromium / Headless Browser

### Linux (Debian/Ubuntu on Pi or x86)
```bash
sudo apt install -y chromium-browser
# On ARM64 (Raspberry Pi), Chrome for Testing has no builds.
# Use system Chromium instead.
# agent-browser wired to: /usr/lib/chromium/chromium
```

### Linux (ARM64 — Chrome for Testing has no builds)
```bash
sudo apt install -y chromium-browser
# Then verify agent-browser can see it:
export PATH="$HOME/.hermes/node/bin:$PATH"
agent-browser --executable-path /usr/lib/chromium/chromium open "data:text/html,<h1>Test</h1>"
agent-browser snapshot -i
```

### macOS
```bash
brew install --cask chromium
# agent-browser will auto-detect the Chrome binary
```

### Windows
```bash
winget install --id Google.Chrome
# agent-browser install will download Chrome for Testing on x64
```

## Step 4: Install Camoufox (Anti-Detection Firefox)

Camoufox is a separate ~557MB download that provides anti-detect capabilities:

```bash
export PATH="$HOME/.hermes/node/bin:$PATH"
# Download can take 5-15 minutes on constrained networks.
# Run in background with notify_on_complete=true for long downloads.
camofox-browser fetch
```

**Pitfall**: Camoufox requires Xvfb on headless Linux for virtual display:
```bash
sudo apt install -y xvfb
```

## Step 5: Verify Installation

```bash
# Check agent-browser works
agent-browser open "data:text/html,<h1>Browser Test</h1>"
agent-browser snapshot -i
agent-browser close

# Check camofox works
camofox-browser --version
```

## Step 6: Configure Hermes

Verify in config.yaml:
```yaml
browser:
  inactivity_timeout: 120
  cloud_provider: local    # or 'browserbase' / 'camofox' for cloud
  use_gateway: false
```

Enable browser toolset:
```bash
hermes tools enable browser
```

## Usage Patterns

### Core browsing loop
```bash
agent-browser open <url>          # 1. Navigate
agent-browser snapshot -i         # 2. See interactive elements (@refs)
agent-browser click @e3           # 3. Act on refs
agent-browser snapshot -i         # 4. Re-snapshot after page change
agent-browser close               # When done
```

### Screenshot capture
```bash
agent-browser open <url>
agent-browser screenshot output.png
agent-browser close
```

### Form filling
```bash
agent-browser open <url>
agent-browser snapshot -i
agent-browser fill @e1 "username"
agent-browser fill @e2 "password"
agent-browser click @e3            # Submit button
```

### Wait for dynamic content
```bash
agent-browser open <url>
agent-browser wait --load networkidle   # Wait for network to settle
agent-browser snapshot -i
```

## Troubleshooting

### "Chrome for Testing does not provide Linux ARM64 builds"
Use system Chromium instead. On Pi/ARM64:
```bash
sudo apt install -y chromium-browser
export PATH="$HOME/.hermes/node/bin:$PATH"
agent-browser --executable-path /usr/lib/chromium/chromium open <url>
```

### "CannotFindXvfb"
```bash
sudo apt install -y xvfb
```

### "Cannot find version.json" / "Camoufox binaries not installed"
```bash
export PATH="$HOME/.hermes/node/bin:$PATH"
camofox-browser fetch
# Wait for 557MB download to complete (5-15 min)
```

### "browser-cdp (system dependency not met)"
Verify Node.js is installed and agent-browser is globally available:
```bash
which agent-browser
npm list -g agent-browser
```

### Browser tool doesn't show up after installation
```bash
hermes tools enable browser
/hermes /reset   # New session picks up tool changes
```

### agent-browser --executable-path ignored
The daemon may be running from a previous session. Reset it:
```bash
agent-browser close
agent-browser --executable-path /usr/lib/chromium/chromium open <url>
```