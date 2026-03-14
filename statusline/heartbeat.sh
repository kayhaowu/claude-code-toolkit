#!/usr/bin/env bash
# Heartbeat daemon for Claude Code session status tracking.
# Keeps session JSON epoch fresh so other sessions/dashboard see WORKING, not IDLE.
#
# Usage: nohup sh heartbeat.sh <claude_code_pid> &
# Started by SessionStart hook, stopped by SessionEnd hook or parent death.

set -e

TARGET_PID="${1:?Usage: heartbeat.sh <pid>}"
SESSIONS_DIR="$HOME/.claude/sessions"
SESSION_FILE="$SESSIONS_DIR/$TARGET_PID.json"
HB_FILE="$SESSIONS_DIR/$TARGET_PID.hb.dat"
STATUS_FILE="$SESSIONS_DIR/$TARGET_PID.status"
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

# ── Create initial .status file ──────────────────────────────────────────────
# Establish an initial idle status so tmux-sessions.sh has a source of truth
# even before any hook fires.
if [ ! -f "$STATUS_FILE" ]; then
    printf '%s %s\n' "idle" "$(date +%s)" > "$STATUS_FILE" 2>/dev/null || true
fi

# ── Create initial session JSON if it doesn't exist ──────────────────────────
# The statusline only renders when Claude is active, so new idle sessions
# won't have a JSON file until the first render. Create a minimal one so
# tmux-sessions.sh can discover the session immediately.
if [ ! -f "$SESSION_FILE" ]; then
    _cwd=$(readlink -f "/proc/$TARGET_PID/cwd" 2>/dev/null) \
        || _cwd=$(lsof -a -p "$TARGET_PID" -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-) \
        || _cwd=""
    _pname=$(basename "${_cwd:-unknown}")
    _epoch=$(date +%s)
    jq -n \
        --argjson pid "$TARGET_PID" \
        --argjson epoch "$_epoch" \
        --arg pdir "$_cwd" \
        --arg pname "$_pname" \
        '{pid:$pid,epoch:$epoch,model:"",project_dir:$pdir,project_name:$pname,git_branch:"",status:"idle",last_activity:"",used_pct:0,tokens_in:0,tokens_out:0,mem_kb:0,cost_usd:0}' \
        > "$SESSION_FILE" 2>/dev/null || true
fi

# ── Cleanup on exit ──────────────────────────────────────────────────────────
cleanup() {
    rm -f "$PIDFILE" "$HB_FILE" "$STATUS_FILE"
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

    # Write heartbeat to a SEPARATE file to avoid race conditions with statusline-command.sh.
    # statusline-command.sh owns the main .json; heartbeat owns .hb.dat.
    # Uses bash builtins to avoid forking date/awk (saves 2 forks per cycle).
    printf -v _hb '%(%s)T' -1
    _mem=$(ps -o rss= -p "$TARGET_PID" 2>/dev/null) || _mem=0
    _mem=$(( ${_mem:-0} + 0 ))  # force integer, strip whitespace (replaces awk)
    printf '{"heartbeat_at":%s,"mem_kb":%s}\n' "$_hb" "$_mem" > "$HB_FILE" 2>/dev/null || true

    sleep "$INTERVAL"
done
