#!/bin/bash
# hermes-config-watcher.sh
# Watches tracked files in ~/.hermes for changes and auto-commits + pushes.
# Designed to run in the background as a systemd service.
#
# Logic: on any file change, fires a commit. A lock file ensures
# only one commit runs at a time, naturally coalescing rapid changes.
# Lock files are placed outside the watched tree to avoid self-triggering.

set -euo pipefail

HERMES_DIR="$HOME/.hermes"
PID_FILE="$HERMES_DIR/.config-watcher.pid"
LOG_FILE="$HERMES_DIR/logs/config-watcher.log"
LOCK_FILE="$HERMES_DIR/.config-watcher.lock"
WATCH_DIR="$HERMES_DIR"
# Lock file for commit coordination — placed outside watched tree
COMMIT_LOCK="/tmp/.hermes-config-writer.lock"

# Logging helper
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
}

# Cleanup
cleanup() {
    log "Shutting down (PID $$)"
    rm -f "$PID_FILE" "$LOCK_FILE"
    # Also try to kill any leftover commit subshells
    pkill -P $$ 2>/dev/null || true
}

# Only run cleanup once
cleanup_done=0
cleanup_once() {
    if [ "$cleanup_done" -eq 1 ]; then
        return
    fi
    cleanup_done=1
    cleanup
    exit 0
}

trap cleanup_once EXIT INT TERM

# Prevent multiple watcher instances
if [ -f "$LOCK_FILE" ]; then
    existing_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
        log "Another instance running (PID $existing_pid). Exiting."
        exit 0
    else
        log "Stale lock file found (PID $existing_pid). Overwriting."
    fi
fi

echo $$ > "$LOCK_FILE"
echo $$ > "$PID_FILE"
log "Config watcher started (PID $$)"

# Commit and push collected changes.
# Uses a lock file in /tmp to avoid concurrent commits.
# Lock files in /tmp won't trigger inotify events on WATCH_DIR.
do_commit() {
    # Check for concurrent commit (debounce)
    if [ -f "$COMMIT_LOCK" ]; then
        log "Commit already in progress, skipping"
        return
    fi

    cd "$HERMES_DIR"

    # Acquire lock
    echo $$ > "$COMMIT_LOCK"
    local locked=1

    # Get all tracked changes (modified + staged, exclude untracked ??)
    local changed_lines
    changed_lines=$(git status --porcelain 2>/dev/null | grep -v '^??' || true)

    if [ -z "$changed_lines" ]; then
        log "No tracked file changes to commit"
    else
        local file_count
        file_count=$(echo "$changed_lines" | wc -l)

        log "Staging $file_count file(s)"

        git add -u 2>/dev/null || true

        local commit_msg="Auto-commit: ${file_count} file(s) changed"

        if git commit -m "$commit_msg" 2>/dev/null; then
            log "Committed $file_count file(s)"

            # Push to origin (best-effort)
            if git push origin main 2>/dev/null; then
                log "Pushed to origin/main"
            else
                log "Push failed (exit code $?): $(git push origin main 2>&1 | tail -1)"
            fi
        else
            log "Nothing to commit (already up to date)"
        fi
    fi

    # Release lock
    rm -f "$COMMIT_LOCK"
}

# Start watching
mkdir -p "$HERMES_DIR/logs"
log "Starting inotifywait on $WATCH_DIR"

inotifywait -m -r \
    --exclude '(node_modules|\.git|cache|logs|\.hermes_history|\.env|state\.db|gateway|kanban|sessions)' \
    -e modify,create,delete,close_write,moved_to \
    "$WATCH_DIR" \
    2>/dev/null \
    | while IFS=' ' read -r directory event file; do
        log "Change detected: $event $file"
        do_commit &
    done
