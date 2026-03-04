#!/bin/sh
# Heartbeat daemon for Claude Code session status tracking.
# Keeps session JSON epoch fresh so other sessions/dashboard see WORKING, not IDLE.
#
# Usage: nohup sh heartbeat.sh <claude_code_pid> &
# Started by SessionStart hook, stopped by SessionEnd hook or parent death.

set -e

TARGET_PID="${1:?Usage: heartbeat.sh <pid>}"
SESSIONS_DIR="$HOME/.claude/sessions"
SESSION_FILE="$SESSIONS_DIR/$TARGET_PID.json"
PIDFILE="$SESSIONS_DIR/$TARGET_PID.hb.pid"
INTERVAL=2

# ── Startup guard: prevent duplicate heartbeats ──────────────────────────────
if [ -f "$PIDFILE" ]; then
    existing=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$existing" ] && kill -0 "$existing" 2>/dev/null; then
        exit 0
    fi
    rm -f "$PIDFILE"
fi

# ── Write our PID ────────────────────────────────────────────────────────────
mkdir -p "$SESSIONS_DIR"
echo $$ > "$PIDFILE"

# ── Cleanup on exit ──────────────────────────────────────────────────────────
cleanup() {
    rm -f "$PIDFILE"
    # If parent is dead, remove stale session file too
    if ! kill -0 "$TARGET_PID" 2>/dev/null; then
        rm -f "$SESSION_FILE"
    fi
}
trap cleanup EXIT INT TERM

# ── Main heartbeat loop ─────────────────────────────────────────────────────
while true; do
    # Exit if parent process is gone
    if ! kill -0 "$TARGET_PID" 2>/dev/null; then
        exit 0
    fi

    # Update session JSON if it exists
    if [ -f "$SESSION_FILE" ]; then
        _epoch=$(date +%s)
        _mem=$(ps -o rss= -p "$TARGET_PID" 2>/dev/null | awk '{printf "%d",$1+0}') || _mem=0
        _tmp="$SESSION_FILE.hb.tmp"
        jq --arg epoch "$_epoch" --arg mem "$_mem" \
            '.epoch = ($epoch | tonumber) | .mem_kb = ($mem | tonumber)' \
            "$SESSION_FILE" > "$_tmp" 2>/dev/null && mv "$_tmp" "$SESSION_FILE" \
            || rm -f "$_tmp"
    fi

    sleep "$INTERVAL"
done
