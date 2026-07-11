# Exclude Files from inotify Watcher + Git

When you have files that a config-watcher inotify daemon must NOT track (to avoid auto-commit loops) but that are currently tracked in git, you need a three-part fix:

## The Problem

Just adding a path to `.gitignore` or to the `inotifywait --exclude` regex is NOT enough if the files are already in the git index. `git` will still commit them; `.gitignore` only affects untracked files.

## The Pattern

### 1. inotifywait `--exclude` regex

Add the exact paths to the `--exclude` parameter with `$` anchors to prevent partial matches:

```bash
inotifywait -m -r \
    --exclude '(...existing patterns...|cron/ticker_heartbeat$|cron/ticker_last_success$)' \
    -e modify,create,delete,close_write,moved_to \
    "$WATCH_DIR"
```

The `$` anchor ensures `cron/ticker_heartbeat` matches but `cron/ticker_heartbeat_extra` does not.

### 2. `.gitignore`

Add the same paths to `.gitignore` so they stay untracked after being removed from the index:

```
# Ticker heartbeat files
cron/ticker_heartbeat
cron/ticker_last_success
```

### 3. `git rm --cached`

Force-remove from the index while keeping files on disk:

```bash
git rm --cached cron/ticker_heartbeat cron/ticker_last_success
git add -u
```

Then commit and push. The files remain on disk (so the services that write them keep working) but are no longer tracked.

## Verification Checklist

```bash
# 1. inotifywait regex test
EXCLUDE=$(grep -- --exclude bin/hermes-config-watcher.sh | head -1 | sed "s/.*--exclude '//;s/' .*//")
echo "cron/ticker_heartbeat" | grep -E "$EXCLUDE"
# Should output: cron/ticker_heartbeat (matched)

# 2. .gitignore
grep ticker_ .gitignore
# Should show both paths

# 3. Not in git index
git ls-files cron/ticker_heartbeat cron/ticker_last_success
# Should produce NO output

# 4. Git status clean
git status --porcelain cron/ticker_heartbeat cron/ticker_last_success
# Should produce NO output
```

## Pitfalls

- **Just `.gitignore` is insufficient** for already-tracked files — `git` ignores `.gitignore` for files already in the index. You MUST use `git rm --cached`.
- **Omit `$` anchors** and you'll block partial matches (e.g., `cron/ticker_heartbeat` would also block `cron/ticker_heartbeat.lock`).
- **Commit both changes together** — watcher script + .gitignore + `git rm --cached`. If you commit the watcher change first, the auto-commit loop will still fire on the untracked files until the second commit arrives.
- **The `inotifywait` exclude only prevents triggering** the debounce/commit loop. The files are still on disk and services continue writing to them.
