---
name: hermes-webui
description: >
  Install, configure, and maintain Hermes WebUI on Linux. Covers cloning, Python
  venv setup, .env configuration, systemd service creation, password auth, and
  Tailscale/remote access. Pitfalls captured from real installations.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [hermes-webui, webui, python, systemd, tailscale]
    related_skills: [systemd-services, hermes-agent]
---

# Hermes WebUI Deployment

Install, configure, and maintain Hermes WebUI on a Linux host. This is a **Python + vanilla JS** app — NOT Node.js (ignore the repo's `package.json`, it's only for ESLint devtooling).

## When to Use

- User asks to set up the Hermes WebUI on a new machine
- WebUI is crashing, needs restart, or password auth needs enabling
- Remote/Tailscale access is needed

## Procedure

### 1. Clone the Repo

```bash
cd /home/hermes && git clone git@github.com:nesquena/hermes-webui.git
```

SSH clone is preferred — HTTPS can hang on slow connections.

### 2. Install Python Dependencies

```bash
cd /home/hermes/hermes-webui
python3 -m venv .venv
.venv/bin/pip install pyyaml cryptography
```

Only two hard deps: `pyyaml` (config) and `cryptography` (passkey/WebAuthn). Everything else (ML, agent runtime) lives in the hermes-agent venv.

### 3. Create .env

```bash
cat > .env << 'EOF'
HERMES_WEBUI_HOST=0.0.0.0
HERMES_WEBUI_PASSWORD=<your-password>
EOF
```

`HERMES_WEBUI_HOST=0.0.0.0` is required for remote access (Tailscale, SSH tunnel). Password auth is mandatory before exposing outside localhost.

### 4. Create Systemd Service

```ini
[Unit]
Description=Hermes WebUI
After=network.target tailscaled.service
Requires=tailscaled.service

[Service]
Type=simple
User=hermes
Group=hermes
WorkingDirectory=/home/hermes/hermes-webui
ExecStart=/usr/bin/bash /home/hermes/hermes-webui/start.sh
Restart=on-failure
RestartSec=5
Environment=HERMES_HOME=/home/hermes/.hermes
Environment=PATH=/home/hermes/.hermes/hermes-agent/venv/bin:/home/hermes/hermes-webui/.venv/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
```

Key points:
- **ExecStart uses `bash`, not `python`** — `start.sh` is a shell script
- **PATH must include agent venv** — server.py imports hermes-agent modules
- **HERMES_HOME must be set** — locates config.yaml

Install:
```bash
sudo tee /etc/systemd/system/hermes-webui.service > /dev/null << 'EOF'
<service file contents>
EOF
sudo systemctl daemon-reload
sudo systemctl enable hermes-webui.service
sudo systemctl start hermes-webui.service
```

### 5. Verify

```bash
curl -s http://<server-ip>:8787/health
```

Expected: `{"status": "ok", ...}`. If it fails, check `sudo systemctl status hermes-webui` and `journalctl -u hermes-webui -n 20`.

## Pitfalls

### start.sh is a BASH script — do NOT run via python

The service file must use `ExecStart=/usr/bin/bash .../start.sh`. Using `python` produces a Python `SyntaxError` on line 90+ because bash syntax isn't valid Python.

### Agent venv must be in PATH

The WebUI server imports modules from the hermes-agent venv. If the PATH doesn't include `/home/hermes/.hermes/hermes-agent/venv/bin`, the server starts but uses defaults or fails silently. Verify by checking for `(not found, using defaults)` in logs.

### HTTPS port scan exposure

The repo runs on port 8787 which is flagged by masscan as an "HTTPS" port. This is **just HTTP** — no TLS. Don't expose port 8787 to the public internet; use Tailscale or SSH tunneling instead.

## Verification

After deployment:
1. Health endpoint returns `{"status": "ok"}`
2. `sudo systemctl status hermes-webui.service` shows active
3. Access from remote device (phone, browser) with password

## Support Files

- `templates/.env-example` — ready-to-fill .env template
- `templates/hermes-webui.service` — systemd unit file