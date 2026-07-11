#!/bin/bash
# hermes-config-watcher.sh
# Watches tracked files in ~/.hermes for changes and auto-commits + pushes.
# Runs as a systemd service (User=hermes).
#
# Uses flock(1) for robust locking — the first commit gets exclusive access
# to /tmp/.hermes-commit.lock. Rapid-fire events are naturally coalesced.

set -euo pipefail

HERMES_DIR="$HOME/.hermes"
PID_FILE="$HERMES_DIR/.config-watcher.pid"
LOG_FILE="$HERMES_DIR/logs/config-watcher.log"
LOCK_FILE="$HERMES_DIR/.config-watcher.lock"
WATCH_DIR="$HERMES_DIR"
COMMIT_LOCK="/tmp/.hermes-commit.lock"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
}

cleanup() {
    log "Shutting down (PID $$)"
    rm -f "$PID_FILE" "$LOCK_FILE"
    pkill -P $$ 2>/dev/null || true
}

cleanup_done=0
cleanup_once() {
    [ "$cleanup_done" -eq 1 ] && return
    cleanup_done=1
    cleanup
    exit 0
}

trap cleanup_once EXIT INT TERM

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

do_commit() {
    (
        if ! flock -w 5 200; then
            log "Could not acquire lock (another commit in progress)"
            return 1
        fi

        cd "$HERMES_DIR" || { log "CD FAILED: $HERMES_DIR"; return 1; }

        local changed_lines
        changed_lines=$(git status --porcelain 2>/dev/null | grep -v '^??' || true)

        if [ -z "$changed_lines" ]; then
            log "No tracked file changes to commit"
            return 0
        fi

        local file_count
        file_count=$(echo "$changed_lines" | wc -l)
        log "Staging $file_count file(s)"

        git add -u 2>/dev/null || true

        if git commit -m "Auto-commit: ${file_count} file(s) changed" 2>/dev/null; then
            log "Committed ${file_count} file(s)"
            if git push origin main 2>/dev/null; then
                log "Pushed to origin/main"
            else
                log "Push failed: $(git push origin main 2>&1 | tail -1)"
            fi
        else
            log "Nothing to commit"
        fi
    ) 200>"$COMMIT_LOCK"
}

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
