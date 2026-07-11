---
name: systemd-services
description: Use when creating, managing, or debugging systemd services for background daemons on Linux — writing unit files, handling permissions, and diagnosing common pitfalls.
version: 1.1.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [systemd, service, daemon, boot, background, file-watcher, inotify, flock]
    related_skills: [hermes-agent, inotify-watcher]
---

# Systemd Services

## Overview

Create, manage, and debug systemd services for background daemons on Linux hosts. Covers writing unit files, handling permissions, git safe.directory deadlocks, lock files, journalctl debugging, and interpreter mismatches.

Create, manage, and debug systemd services for background daemons on Linux hosts.

## When to Use

- User asks to "run this in the background permanently" or "start this on boot"
- Need a process to watch files, poll APIs, or run periodic tasks
- Infrastructure involves background processes that should survive terminal closures

## Procedure

### 1. Write the Script

Place executable scripts in a stable, version-controlled path:

```bash
mkdir -p ~/.hermes/bin
# Write your script here
chmod +x ~/.hermes/bin/my-daemon.sh
```

### 2. Write the Service File

Template:

```ini
[Unit]
Description=<Short description>
After=multi-user.target

[Service]
Type=simple
User=<non-root-user>          # ← CRITICAL: omit this and the service runs as root
Environment=HOME=/home/<user>
ExecStart=/bin/bash -l -c 'cd <workdir> && <script>'
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=<service-name>

[Install]
WantedBy=multi-user.target
```

**Key decisions:**
- `Type=simple` — for processes that stay running (not forking)
- `User=<owner>` — **must match the repo owner** when the service accesses a git repo (see pitfalls)
- `Restart=on-failure` + `RestartSec=10` — auto-restart on crash with backoff
- `Environment=HOME=...` — ensure HOME is set; many tools (git, SSH, npm) depend on it
- `StandardOutput=journal` + `StandardError=journal` — logs via `journalctl -u <service>`
- Avoid `Restart=always` unless the process legitimately crashes; `on-failure` is safer

### 3. Install and Enable

```bash
sudo tee /etc/systemd/system/<service>.service > /dev/null << 'EOF'
<service file contents>
EOF

sudo systemctl daemon-reload
sudo systemctl enable <service>     # start on boot
sudo systemctl restart <service>    # start now
```

## Pitfalls

### Root + git safe.directory deadlock

If a systemd service has **no `User=` directive**, it runs as **root**. Root triggers git's `safe.directory` security check on user-owned repos — commands silently fail with `NOT_A_REPO` or `GIT_STATUS_FAILED`. Debugging shows `git rev-parse --show-toplevel` returning "NOT_A_REPO" even though the path exists and is a valid repo.

**Fix:** Always set `User=<owner>` in the unit file when the service accesses a user-owned repo. Verify with `journalctl -u <name> -n 20` — look for `NOT_A_REPO` or empty output from git commands.

```
[Service]
User=hermes          # ← must match the repo owner
```

### Script changes aren't picked up automatically

After editing the script, you MUST restart:
```bash
sudo systemctl daemon-reload && sudo systemctl restart <service>
```

The systemd service caches the binary path; editing the script in place does NOT trigger a reload.

### Lock files must live outside the watched tree

If a script writes a lock file inside a directory it's watching (e.g. via inotifywait), the lock file's own create/modify/delete events will trigger the watcher, creating a cascade. **Always place lock files in /tmp or another directory outside the watched tree.**

### git status --porcelain regex is tricky

Unstaged changes show as ` M file` (space-M-space), staged changes as `M file` (M-space). A grep for `'^M '` (M-space) will miss unstaged changes. Use `grep -v '^??'` to exclude untracked files and match all tracked changes regardless of staging state.

### `set -euo pipefail` + `while | read` pipeline breaks

```bash
# DANGEROUS: pipefail + inotifywait pipe can silently drop errors
some-command | while read -r line; do
    do-thing "$line"
done
```

When `pipefail` is set and the producer of the pipe exits with a non-zero status (e.g., signal), the entire pipeline fails. For long-running daemon watches:
- Either use `|| true` at the end of the pipeline
- Or use `set +o pipefail` inside the loop body
- Or prefer process substitution: `while read -r line; do ... done < <(some-command)`

### Background subshell traps don't work reliably

A `trap ... RETURN` inside a function that's `&`-backgrounded in a pipeline subshell may not fire. Use `flock(1)` from coreutils instead:

```bash
(
    flock -w 5 200 || exit 1
    # do work
) 200>/tmp/.service.lock
```

`flock` is kernel-level and auto-releases when the subshell exits.

### Journalctl is your friend

```bash
journalctl -u <service> -f           # follow logs
journalctl -u <service> --since "10 min ago"  # recent logs
sudo systemctl status <service>       # quick status + recent log lines
```

### PID files

Some services write PID files (e.g. `~/.hermes/.service.pid`). systemd already tracks PIDs via `Type=simple`, so PID files are only useful for cross-service coordination (e.g. "is watcher already running?"). Use a lock file pattern in the script for that purpose.

## Verification

After creating a service:

1. `sudo systemctl status <service>` — check active
2. Trigger the expected behavior and check `journalctl -u <service>` or the script's own log
3. `journalctl -u <service> --since "1 hour ago"` — verify no errors in last hour

### ExecStart must match the script's interpreter

If your script is a shell script, **do not** run it through `python`:

```ini
# WRONG — bash script interpreted as Python → SyntaxError
ExecStart=/usr/bin/python /opt/app/start.sh

# CORRECT
ExecStart=/usr/bin/bash /opt/app/start.sh
# OR
ExecStart=/bin/bash /opt/app/start.sh
```

Symptom: systemd reports `exit-code=1/FAILURE`, and the script's first line is `#!/usr/bin/env bash` but the error is a Python `SyntaxError` on line 90+. Always check the shebang, then use that interpreter in ExecStart.

### Python apps may need explicit PATH + environment vars

Python processes launched by systemd do NOT inherit the user's shell PATH. If the app imports a sibling project (e.g. hermes-agent from its own venv), the interpreter in the service PATH must point to the venv with those packages:

```ini
Environment=HERMES_HOME=/home/hermes/.hermes
Environment=PATH=/home/hermes/.hermes/hermes-agent/venv/bin:/usr/local/bin:/usr/bin:/bin
```

Missing this: the service starts but the app silently falls back to defaults or fails to find modules. Verify with `journalctl -u <service> -n 20` — look for `(not found, using defaults)` or `ModuleNotFoundError`.

## Verification Checklist

- [ ] Unit file has `User=<owner>` directive (not running as root)
- [ ] ExecStart matches the script's interpreter (bash for bash scripts, not python)
- [ ] Environment=HOME set for tools that depend on it
- [ ] StandardOutput and StandardError set to journal
- [ ] Service enabled (`systemctl enable`) and started (`systemctl restart`)
- [ ] `systemctl status <service>` shows active and running
- [ ] `journalctl -u <service> -n 20` shows no errors
- [ ] Lock files (if any) live outside the watched tree (not in the same directory being monitored)
- [ ] Script changes followed by `daemon-reload && restart`

## Support Files

- `templates/systemd-service-unit.md` — boilerplate unit file
- `templates/watcher-service.sh` — inotify-based file watcher with flock debounce
- `references/root-git-deadlock.md` — debug case study: root+safe.directory deadlock
- `references/inotify-watch-exclusion.md` — three-part pattern to exclude files from both inotifywait watching and git tracking
