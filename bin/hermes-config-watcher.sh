#!/bin/bash
# hermes-config-watcher.sh
# Watches ~/.hermes for file changes and auto-commits + pushes.
# Runs as a systemd service (User=hermes).
#
# Debounces: waits 1 minute after last change before committing.
# Stages both modified tracked files AND new untracked files in skills/ and cron/.

set -euo pipefail

HERMES_DIR="$HOME/.hermes"
PID_FILE="$HERMES_DIR/.config-watcher.pid"
LOG_FILE="$HERMES_DIR/logs/config-watcher.log"
LOCK_FILE="$HERMES_DIR/.config-watcher.lock"
COMMIT_LOCK="/tmp/.hermes-commit.lock"

# Explicit list of paths to watch. Anything outside these paths (state.db-wal,
# ticker_heartbeat, processes.json, sessions/, gateway/, etc.) is invisible to
# inotify entirely — no exclusion rules needed.
WATCH_PATHS=(
    "$HERMES_DIR/config.yaml"
    "$HERMES_DIR/SOUL.md"
    "$HERMES_DIR/.gitignore"
    "$HERMES_DIR/bin"
    "$HERMES_DIR/skills"
    "$HERMES_DIR/cron/jobs.json"
    "$HERMES_DIR/cron/output"
)
DEBOUNCE_TRIGGER="$HERMES_DIR/.config-watcher.debounce"
DEBOUNCE_SECONDS=60    # wait this long after last change before committing
MAX_DEBOUNCE_SECONDS=300  # force commit after this long even if changes keep arriving
FIRST_CHANGE_FILE="$HERMES_DIR/.config-watcher.first-change"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
}

cleanup() {
    log "Shutting down (PID $$)"
    rm -f "$PID_FILE" "$LOCK_FILE" "$FIRST_CHANGE_FILE"
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

# Mark that a change was detected — debounce loop polls this file
mark_change() {
    # Record time of first change (don't update if already exists)
    if [ ! -f "$FIRST_CHANGE_FILE" ]; then
        touch "$FIRST_CHANGE_FILE" 2>/dev/null || true
    fi
    touch "$DEBOUNCE_TRIGGER" 2>/dev/null || true
}

do_commit() {
    (
        if ! flock -w 10 200; then
            log "Could not acquire lock (another commit in progress)"
            return 1
        fi

        cd "$HERMES_DIR" || { log "CD FAILED: $HERMES_DIR"; return 1; }

        # Modified tracked files
        local changed_lines
        changed_lines=$(git status --porcelain 2>/dev/null | grep -v '^??' || true)

        # New untracked files in skills/ and cron/ only
        local new_files
        new_files=$(git status --porcelain 2>/dev/null | grep '^??' | grep -E '^?? (skills|cron)/' || true)

        local total_files=0
        if [ -n "$changed_lines" ]; then
            total_files=$(echo "$changed_lines" | wc -l)
        fi
        if [ -n "$new_files" ]; then
            local new_count
            new_count=$(echo "$new_files" | wc -l)
            total_files=$((total_files + new_count))
        fi

        if [ "$total_files" -eq 0 ]; then
            log "No file changes to commit"
            return 0
        fi

        local commit_msg="Auto-commit: ${total_files} file(s) changed"
        if [ -n "$new_files" ]; then
            log "Staging $total_files file(s) (${total_files}-$(echo "$new_files" | wc -l) new in skills/cron)"
        else
            log "Staging $total_files file(s)"
        fi

        # Stage modified tracked files
        git add -u 2>/dev/null || true
        # Stage new files in skills/ and cron/
        if [ -n "$new_files" ]; then
            echo "$new_files" | while IFS=' ' read -r _ filepath; do
                git add "$filepath" 2>/dev/null || true
            done
        fi

        if git commit -m "$commit_msg" 2>/dev/null; then
            log "Committed ${total_files} file(s)"
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

# Debounce loop: polls for DEBOUNCE_TRIGGER file.
# When found, waits DEBOUNCE_SECONDS before committing.
# If another change arrives during the wait, resets the timer.
debounce_loop() {
    while true; do
        if [ -f "$DEBOUNCE_TRIGGER" ]; then
            local last_change
            last_change=$(stat -c %Y "$DEBOUNCE_TRIGGER" 2>/dev/null || echo 0)
            local first_change
            first_change=$(stat -c %Y "$FIRST_CHANGE_FILE" 2>/dev/null || echo "$last_change")
            local now
            now=$(date +%s)
            local elapsed=$((now - last_change))
            local total_wait=$((now - first_change))
            if [ "$elapsed" -ge "$DEBOUNCE_SECONDS" ] || [ "$total_wait" -ge "$MAX_DEBOUNCE_SECONDS" ]; then
                if [ "$total_wait" -ge "$MAX_DEBOUNCE_SECONDS" ]; then
                    log "Max debounce cap reached: ${total_wait}s since first change (forced commit)"
                else
                    log "Debounce fired: ${elapsed}s since last change (threshold: ${DEBOUNCE_SECONDS}s)"
                fi
                rm -f "$DEBOUNCE_TRIGGER" "$FIRST_CHANGE_FILE" 2>/dev/null || true
                do_commit &
            else
                log "Debounce pending: ${elapsed}s / ${DEBOUNCE_SECONDS}s (total: ${total_wait}s / ${MAX_DEBOUNCE_SECONDS}s)"
                sleep 5
            fi
        else
            sleep 5
        fi
    done
}

mkdir -p "$HERMES_DIR/logs"

# Build list of watch paths that currently exist
existing_watch_paths=()
for p in "${WATCH_PATHS[@]}"; do
    [ -e "$p" ] && existing_watch_paths+=("$p")
done

log "Starting inotifywait on ${#existing_watch_paths[@]} path(s) (debounce=${DEBOUNCE_SECONDS}s, max=${MAX_DEBOUNCE_SECONDS}s)"

# Start debounce loop in background
debounce_loop &
DEBOUNCE_PID=$!

# inotifywait watches only the explicit config/skill paths; runtime noise
# (state.db-wal, ticker files, processes.json, etc.) is never in scope.
inotifywait -m -r \
    -e modify,create,delete,close_write,moved_to \
    "${existing_watch_paths[@]}" \
    2>/dev/null \
    | while IFS=' ' read -r directory event file; do
        # Minimal guard: skip SQLite auxiliary and temp files that could
        # appear inside skills/ if a skill uses a local database.
        case "$file" in
            *-shm|*-wal|*-journal|*.tmp*)
                continue
                ;;
        esac
        mark_change
    done
