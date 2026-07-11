#!/bin/bash
# hermes-config-watcher.sh
# Watches tracked files in ~/.hermes for changes and auto-commits + pushes.
# Designed to run in the background as a systemd service.
#
# Logic: on any file change, fires a background commit. A lock file ensures
# only one commit runs at a time, naturally coalescing rapid changes.

set -euo pipefail

HERMES_DIR="$HOME/.hermes"
PID_FILE="$HERMES_DIR/.config-watcher.pid"
LOG_FILE="$HERMES_DIR/logs/config-watcher.log"
LOCK_FILE="$HERMES_DIR/.config-watcher.lock"
WATCH_DIR="$HERMES_DIR"

# Logging helper
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
}

# Cleanup
cleanup() {
    log "Shutting down (PID $$)"
    rm -f "$PID_FILE" "$LOCK_FILE"
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

# Commit and push collected changes. Uses lock file to avoid concurrent commits.
do_commit() {
    # Check for concurrent commit (debounce)
    if [ -f "${HERMES_DIR}/.config-watcher.commit.lock" ]; then
        log "Commit already in progress, skipping"
        return
    fi

    cd "$HERMES_DIR"

    # Create lock to prevent other commits while we work
    echo $$ > "${HERMES_DIR}/.config-watcher.commit.lock"
    trap 'rm -f "${HERMES_DIR}/.config-watcher.commit.lock"' RETURN

    # Get all tracked changes (modified + staged)
    local changed_lines
    changed_lines=$(git status --porcelain 2>/dev/null | grep -v '^??' || true)

    if [ -z "$changed_lines" ]; then
        log "No tracked file changes to commit"
        return
    fi

    local file_count
    file_count=$(echo "$changed_lines" | wc -l)

    log "Staging $file_count file(s): $(echo "$changed_lines" | awk '{print $2}' | tr '\n' ' ')"

    git add -u 2>/dev/null || true

    local commit_msg="Auto-commit: ${file_count} file(s) changed"

    if git commit -m "$commit_msg" 2>/dev/null; then
        log "Committed $file_count file(s): $commit_msg"

        # Push to origin (non-blocking, don't block if push fails)
        git push origin main 2>/dev/null && \
            log "Pushed to origin/main" || \
            log "Push failed (exit code $?): $(git push origin main 2>&1 | tail -1)"
    else
        log "No changes to commit (git said 'nothing to commit')"
    fi
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
