# Pi ARM64 Chromium Installation

**Problem**: Chrome for Testing (agent-browser's default download) does not provide ARM64/Linux builds.

**Diagnosis**: When you see:
```
✗ Chrome for Testing does not provide Linux ARM64 builds.
  Install Chromium from your system package manager instead
```

**Fix**: Install system Chromium, then point agent-browser at it:

```bash
sudo apt install -y chromium-browser

# Verify path
dpkg -L chromium-browser | grep bin/
# Expected: /usr/bin/chromium (wrapper) → /usr/lib/chromium/chromium (binary)

# Test with --executable-path flag:
export PATH="$HOME/.hermes/node/bin:$PATH"
agent-browser --executable-path /usr/lib/chromium/chromium open "data:text/html,<h1>Test</h1>"
agent-browser snapshot -i
```

**Pitfall**: `--executable-path` is ignored if the daemon is already running. Close the daemon first:
```bash
agent-browser close
agent-browser --executable-path /usr/lib/chromium/chromium open <url>
```

**Note**: On Pi, the chromium launcher script at `/usr/bin/chromium` is a shell wrapper. The actual binary lives at `/usr/lib/chromium/chromium`. Both paths generally work, but the binary path is more direct.