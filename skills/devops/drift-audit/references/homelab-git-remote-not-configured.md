# Homelab Git Remote Not Configured

## Symptom

Both the `llm-digest` cron job and drift-audit cron jobs encounter the same git push failure:

```
fatal: No configured push destination.
Either specify the URL from the command-line or configure a remote repository using
    git remote add <name> <url>
and then push using the remote name
    git push <name>
```

The `git remote -v` command returns nothing, and `git remote | grep -q origin` fails.

## Affected Jobs

- `Scout LLM tools` (cron job `34c1ca0610de`) — writes to `~/homelab/docs/digests/`
- Drift audit (cron job `e7a6e0d7899f`) — writes to `~/homelab/docs/`

## Root Cause

The `~/homelab/` directory is a git repo (has `.git/`) but no remote has been configured. The user likely cloned or initialized it locally but never added a remote origin, or the remote was removed.

## Resolution

User needs to configure the remote:

```bash
cd ~/homelab
git remote add origin git@github.com:timchap/homelab.git
# or whatever the correct URL is
git push -u origin master
```

## Impact

- All writes to `~/homelab/` (digests, docs, etc.) persist locally but are NOT backed up
- No collaboration or remote tracking is possible
- Both cron jobs still commit locally successfully — only `git push` fails

## Mitigation

Cron jobs should always check for remote before pushing:

```bash
cd ~/homelab
git remote -v | grep -q 'origin' && git push || echo "No remote — commit locally only"
```

Both affected jobs now include this pattern after this issue was discovered.
