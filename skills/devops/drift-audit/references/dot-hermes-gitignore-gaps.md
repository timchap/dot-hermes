# Dot-Hermes Gitignore Gaps

## Problem

The `~/.hermes/` repo's `.gitignore` covers many runtime artifacts but misses several that leak into `git add -A`:

**Currently missing from .gitignore:**
- `bin/` — installed binaries (uv, uvx, tirith, language servers)
- `lsp/` — LSP node_modules and dependencies
- `hermes-agent/` — the embedded hermes-agent git repo
- `webui/` — webui secrets (.pbkdf2_key, .sessions.json, .signing_key), login state
- `pastes/` — paste archives
- `processes.json` — process state
- `.update_check`, `.scratch_tip_shown`, `.no-bundled-skills` — session flags

## What Happens

When `git add -A` runs (e.g., during auto-commit or manual staging), it can pick up 3000+ files including `lsp/node_modules/`, `bin/tirith` (2MB+), etc. In a real incident, `git add -A` staged **3890 files, 577K insertions** — mostly `node_modules/` and built binaries.

## Fix

When committing drift to `~/.hermes/`, never use `git add -A`. Instead:

```bash
cd ~/.hermes

# Reset everything first
git reset HEAD

# Add only the files you actually changed
git add config.yaml cron/jobs.json skills/.usage.json
# ... specific files only

# Verify before commit
git status --short
```

Or selectively add while excluding known noise:

```bash
git add -A -- ':!lsp/' ':!bin/' ':!hermes-agent/' ':!webui/' ':!pastes/' ':!processes.json'
```
