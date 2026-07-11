# Root + Git Safe.Directory Deadlock

**Session date:** 2026-07-11  
**Skill:** systemd-services

## Symptom

A systemd service accessing a user-owned git repo silently fails:
- `git rev-parse --show-toplevel` → `NOT_A_REPO`
- `git status --porcelain` → empty or fails silently
- No visible error in `journalctl`

## Root Cause

When a systemd service unit has no `User=` directive, it runs as **root** by default. Git's `safe.directory` security check blocks root from accessing repos owned by a different user, returning "NOT_A_REPO" for all commands.

## Diagnosis

1. Check the service unit: `cat /etc/systemd/system/<name>.service | grep User`
   - If no `User=` line → running as root
2. Check journal: `journalctl -u <name> -n 20 | grep -i repo`
   - Look for `NOT_A_REPO` or empty git output
3. Manual test: `sudo -u hermes bash -l -c 'cd /home/hermes/.hermes && git rev-parse --show-toplevel'`
   - Works when run as the repo owner, fails as root

## Fix

Add `User=<owner>` to the service unit:

```ini
[Service]
User=hermes
Environment=HOME=/home/hermes
```

Then: `sudo systemctl daemon-reload && sudo systemctl restart <name>`

## Prevention

Always explicitly set `User=` in systemd units unless the service genuinely needs root privileges. This is especially critical for any service that accesses user-owned git repos, SSH keys, or credential stores.
