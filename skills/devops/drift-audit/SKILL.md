---
name: drift-audit
description: Periodically audit Hermes environment sessions for undocumented or uncommitted environment changes — software installs, config changes, systemd units, network changes, Hermes-specific changes (skills, plugins, cron jobs, config.yaml).
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [drift, audit, persistence, homelab, ansible, cron, self-admin]
    related_skills: [hermes-agent, systemd-services, cron-troubleshooting]
---

# Drift Audit

## Overview

Periodically review all Hermes Agent sessions since the last audit and identify any environment changes that should have been documented in `~/homelab/docs/` or persisted as Ansible playbooks in `~/homelab/ansible/`. This is typically run as a scheduled cron job.

## When to Use

- Running a scheduled drift-audit cron job
- After any significant environment change that may not have been tracked
- When the user asks "is everything tracked?" or "what changed since last audit?"

## Procedure

### 1. Session Review

Use `session_search(sort='newest', limit=10)` to get recent sessions. For each session, scroll through to find:

- **Software installs/updates**: apt, pip, npm, brew, etc.
- **New systemd services/timers/daemons**: created, modified, or removed
- **Filesystem changes**: scripts in /usr/local/bin, ~/.local/bin, etc.
- **Configuration changes**: /etc/ files, Docker/container changes
- **Ansible playbooks/roles**: added or modified
- **Network changes**: firewall rules, Tailscale, ports opened
- **Hermes-specific changes**: new skills, plugins, cron jobs, config.yaml modifications

### 2. Drift Detection — What Should Be Documented

For each change found, check:

a. **Homelab docs** (`~/homelab/docs/`) — Does it belong documented?
   - Check existing docs for context
   - Update the relevant doc to reflect the change

b. **Ansible** (`~/homelab/ansible/`) — Is it a repeatable infrastructure change?
   - Check if `~/homelab/ansible/` exists and has existing playbooks/roles
   - If empty (no existing patterns), skip Ansible — only document in `~/homelab/docs/`.
     Do NOT create Ansible resources for user-level services (npm installs, user-level systemd units) unless explicitly requested.
   - If the directory doesn't exist at all, same as empty — no Ansible.

### 3. Persist and Commit

For each change needing documentation:

- Write the update to `~/homelab/`
- Commit and push to the homelab git repo at `~/homelab/`
- For changes in `~/.hermes/` (e.g., config.yaml, new skill), commit to `~/.hermes/`

**Important: Always use clear commit messages describing what changed and why.**

### 4. Handle Git Remote Issues

Homelab repos often lack a configured remote. Check before attempting push:

```bash
cd ~/homelab
git remote -v | grep -q origin || {
  echo "WARN: ~/homelab has no remote — commit locally only"
}
```

If no remote: commit locally, skip push, and note this in the report.

### 5. Report

Produce a concise report:

```
### Drift Found
- List each environment change detected and its status
  (documented/persisted, or left uncommitted with explanation)

### Actions Taken
- Files updated, ansible resources created/modified
- Git commits made (with messages)

### Left Unchanged
- Any changes that should NOT be persisted (explain why)
```

If no drift found (all sessions were purely analytical, web research, or conversation without env changes), respond with `[SILERT]`.

## Common Pitfalls

1. **Write-then-forget-commit** — A session may write a file to disk but never commit it (e.g., the LLM digest cron writes the file but the session output only includes the delivery summary, not the commit). Always check `git status` for untracked files before concluding the job succeeded.

2. **dot-hermes gitignore gaps** — The `~/.hermes/` repo's `.gitignore` doesn't cover `bin/`, `lsp/`, `hermes-agent/`, `webui/`, `pastes/`, `processes.json`, and runtime artifacts. `git add -A` can stage thousands of untracked files. Always inspect `git status --short` before committing and exclude build/runtime artifacts.

3. **Assuming success from tool output** — A tool call returning success (e.g., write_file returns byte count) doesn't mean the result was committed or pushed. Always verify with `git status` and `git log`.

4. **Confusing ephemeral with persistent** — Cron job state updates (next_run_at, completed counts) are already auto-committed by the cron system. Don't treat these as drift — they are transient scheduling state.

5. **Over-documenting** — One-off debug sessions, web research, and conversations without env changes are NOT drift. Only document actual infrastructure/config changes.

## Verification Checklist

- [ ] All recent sessions reviewed for env changes
- [ ] Git status checked for untracked/uncommitted files
- [ ] Remote configured? If not, commit locally only and note it
- [ ] Report includes Drift Found, Actions Taken, and Left Unchanged sections
- [ ] Commits have clear, descriptive messages
