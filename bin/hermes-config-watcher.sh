#!/bin/bash
# hermes-config-watcher.sh
# Watches tracked files in ~/.hermes for changes and auto-commits + pushes.
# Designed to run in the background as a daemon.

set -euo pipefail

HERMES_DIR="$HOME/.hermes"
PID_FILE="$HERMES_DIR/.config-watcher.pid"
LOG_FILE="$HERMES_DIR/logs/config-watcher.log"
LOCK_FILE="$HERMES_DIR/.config-watcher.lock"
WATCH_DIR="$HERMES_DIR"

# Debounce state
CHANGES_PENDING=0
COMMIT_TIMER=""

# Logging helper
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
}

# Cleanup
cleanup() {
    log "Shutting down (PID $$)"
    # Kill any pending commit timer
    if [ -n "${COMMIT_TIMER:-}" ]; then
        kill "$COMMIT_TIMER" 2>/dev/null || true
    fi
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

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    existing_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
        log "Already running (PID $existing_pid). Exiting."
        exit 0
    else
        log "Stale lock file found (PID $existing_pid). Overwriting."
    fi
fi

echo $$ > "$LOCK_FILE"
echo $$ > "$PID_FILE"
log "Config watcher started (PID $$)"

# Commit and push collected changes
do_commit() {
    cd "$HERMES_DIR"
    
    # Get list of modified tracked files
    local changed_lines
    changed_lines=$(git status --porcelain 2>/dev/null | grep -E '^M ' || true)
    
    if [ -z "$changed_lines" ]; then
        log "No tracked file changes to commit"
        return
    fi
    
    local file_count
    file_count=$(echo "$changed_lines" | wc -l)
    
    # Stage modified tracked files only
    git add -u 2>/dev/null || true
    
    local commit_msg="Auto-commit: ${file_count} file(s) changed"
    
    if git commit -m "$commit_msg" 2>/dev/null; then
        log "Committed $file_count file(s): $commit_msg"
        
        # Push to origin
        if git push origin main 2>/dev/null; then
            log "Pushed to origin/main"
        else
            log "Push failed (exit code $?): $(git push origin main 2>&1 | tail -1)"
        fi
    else
        log "No changes to commit (git commit said 'nothing to commit')"
    fi
}

# Schedule commit after debounce window
debounce_commit() {
    # Kill any existing timer
    if [ -n "${COMMIT_TIMER:-}" ]; then
        kill "$COMMIT_TIMER" 2>/dev/null || true
    fi
    
    # Spawn timer that fires after 3 seconds
    (
        sleep 3
        do_commit
    ) &
    COMMIT_TIMER=$!
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
        debounce_commit
    done
