#!/bin/bash
# hermes-config-watcher.sh
# Watches tracked files in ~/.hermes for changes and auto-commits + pushes.
# Designed to run in the background as a daemon.

set -euo pipefail

HERMES_DIR="$HOME/.hermes"
PID_FILE="$HERMES_DIR/.config-watcher.pid"
LOG_FILE="$HERMES_DIR/logs/config-watcher.log"
LOCK_FILE="$HERMES_DIR/.config-watcher.lock"
DEBOUNCE_SECONDS=3

# Logging helper
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
}

# Cleanup
cleanup() {
    log "Shutting down (PID $$)"
    rm -f "$PID_FILE" "$LOCK_FILE"
    exit 0
}

trap cleanup EXIT INT TERM

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    existing_pid=$(cat "$LOCK_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        log "Already running (PID $existing_pid). Exiting."
        exit 0
    else
        log "Stale lock file found. Overwriting."
    fi
fi

echo $$ > "$LOCK_FILE"
echo $$ > "$PID_FILE"
log "Config watcher started (PID $$)"

# Collect changed files during debounce window
collect_changes() {
    sleep "$DEBOUNCE_SECONDS"
    cd "$HERMES_DIR"
    
    # Get list of modified tracked files
    local changed_files
    changed_files=$(git status --porcelain 2>/dev/null | grep -E '^ M|^M ' | awk '{print $2}')
    
    if [ -z "$changed_files" ]; then
        log "No tracked file changes detected"
        return
    fi
    
    local file_count
    file_count=$(echo "$changed_files" | wc -l)
    
    # Stage and commit
    git add -u 2>/dev/null || true
    local commit_msg="Auto-commit: ${file_count} file(s) changed"
    
    if git commit -m "$commit_msg" 2>/dev/null; then
        log "Committed $file_count file(s): $commit_msg"
        
        # Push to origin
        if git push origin main 2>/dev/null; then
            log "Pushed to origin/main successfully"
        else
            local push_err=$?
            log "Push failed (exit code $push_err): $(git push origin main 2>&1 | tail -1)"
        fi
    else
        log "No changes to commit (git commit said 'nothing to commit')"
    fi
    
    rm -f "$LOCK_FILE"
}

# Watch for changes
# We watch specific files and directories that are tracked
cd "$HERMES_DIR"

# Build list of tracked files to watch (limit to avoid inotify limits)
# Watch the directory itself which catches most changes
log "Starting inotifywait on $HERMES_DIR"

inotifywait -m -r \
    --exclude '(node_modules|\.git|cache|logs|\.hermes_history|\.env|state\.db|gateway|kanban|sessions)' \
    -e modify,create,delete,close_write,moved_to \
    "$HERMES_DIR" \
    2>/dev/null \
    | while read -r directory event file; do
        log "Change detected: $event $file"
        collect_changes &
    done
