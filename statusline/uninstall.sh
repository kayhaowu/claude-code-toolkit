#!/bin/sh
# Uninstaller for Claude Code status line toolkit
# Usage: bash statusline/uninstall.sh
set -e

CLAUDE_DIR="$HOME/.claude"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# ── Color output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
removed() { printf "${GREEN}[REMOVED]${NC}  %s\n" "$1"; }
skipped() { printf "${YELLOW}[SKIPPED]${NC}  %s\n" "$1"; }

# ── Step 1: Kill running heartbeat daemons ────────────────────────────────────
info "Stopping heartbeat daemons..."
_killed=0
for pidfile in "$SESSIONS_DIR"/*.hb.pid; do
    [ -f "$pidfile" ] || continue
    _hb_pid=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$_hb_pid" ] && kill -0 "$_hb_pid" 2>/dev/null; then
        kill "$_hb_pid" 2>/dev/null && removed "heartbeat process $_hb_pid"
        _killed=$(( _killed + 1 ))
    fi
    rm -f "$pidfile"
done
[ "$_killed" -eq 0 ] && skipped "No running heartbeat daemons found"

# ── Step 2: Clean session files ───────────────────────────────────────────────
info "Cleaning session files..."
_cleaned=0
for pattern in "$SESSIONS_DIR"/*.json "$SESSIONS_DIR"/*.hb.dat "$SESSIONS_DIR"/*.hb.pid; do
    for f in $pattern; do
        [ -f "$f" ] || continue
        rm -f "$f"
        _cleaned=$(( _cleaned + 1 ))
    done
done
if [ "$_cleaned" -gt 0 ]; then
    removed "$_cleaned session file(s)"
else
    skipped "No session files found"
fi

# ── Step 3: Remove installed scripts ──────────────────────────────────────────
info "Removing installed scripts..."
for script in statusline-command.sh statusline.sh dashboard.sh heartbeat.sh tmux-sessions.sh; do
    target="$CLAUDE_DIR/$script"
    if [ -f "$target" ] || [ -L "$target" ]; then
        rm -f "$target"
        removed "$target"
    else
        skipped "$target (not found)"
    fi
done

# ── Step 4: Clean settings.json ───────────────────────────────────────────────
if [ -f "$SETTINGS_FILE" ]; then
    info "Cleaning settings.json..."
    SETTINGS_TMP="${SETTINGS_FILE}.tmp"

    # Single jq pass: remove statusLine, filter our hooks, prune empty objects
    jq '
        del(.statusLine)
        | .hooks.SessionStart |= [(.// [])[] | select((.hooks // []) | all(.command // "" | test("heartbeat\\.sh") | not))]
        | .hooks.SessionEnd   |= [(.// [])[] | select((.hooks // []) | all(.command // "" | test("sessions/\\$PPID") | not))]
        | if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end
        | if (.hooks.SessionEnd   | length) == 0 then del(.hooks.SessionEnd)   else . end
        | if (.hooks // {} | length) == 0        then del(.hooks)              else . end
    ' "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
    removed "statusLine config and hooks"
else
    skipped "settings.json (not found)"
fi

# ── Step 5: tmux suggestion ──────────────────────────────────────────────────
echo ""
info "If you were using tmux integration, run:"
info "  tmux set-option -g status 1"
info "  tmux set-option -gu status-format[1]"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "Uninstall complete."
