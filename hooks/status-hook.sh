#!/bin/sh
# Claude Code hook: track session status in a .status file.
#
# Events (configure in settings.json):
#   UserPromptSubmit  → sh ~/.claude/hooks/status-hook.sh working
#   Stop              → sh ~/.claude/hooks/status-hook.sh idle
#   PermissionRequest → sh ~/.claude/hooks/status-hook.sh waiting
#
# Output format: "<status> <epoch>" in ~/.claude/sessions/<claude_pid>.status
#
# For "idle", the epoch written is the one saved when "working" was set —
# preserving the start of the working period so notify-on-stop.sh can
# compute elapsed time accurately.

STATUS="${1:?Usage: status-hook.sh <working|idle|waiting>}"
SESSIONS_DIR="$HOME/.claude/sessions"

# Find the Claude PID.  Hooks run as direct children of claude, so $PPID is
# usually the claude PID itself.  Walk up a few levels to be safe.
_claude_pid=""
_check="$PPID"
for _i in 1 2 3 4; do
    _comm=$(ps -o comm= -p "$_check" 2>/dev/null | tr -d ' ')
    if [ "$_comm" = "claude" ]; then
        _claude_pid="$_check"
        break
    fi
    _check=$(ps -o ppid= -p "$_check" 2>/dev/null | tr -d ' ')
    [ -z "$_check" ] || [ "$_check" = "0" ] || [ "$_check" = "1" ] && break
done

[ -z "$_claude_pid" ] && exit 0

_statusfile="$SESSIONS_DIR/${_claude_pid}.status"
_epoch=$(date +%s)

if [ "$STATUS" = "idle" ]; then
    # Preserve the epoch recorded when "working" was written so that
    # notify-on-stop.sh can compute how long the task actually took.
    _working_epoch=""
    if [ -f "$_statusfile" ]; then
        _prev_status="" _prev_epoch=""
        read -r _prev_status _prev_epoch < "$_statusfile" 2>/dev/null || true
        if [ "$_prev_status" = "working" ] && [ -n "$_prev_epoch" ]; then
            _working_epoch="$_prev_epoch"
        fi
    fi
    _epoch="${_working_epoch:-$_epoch}"
fi

printf '%s %s\n' "$STATUS" "$_epoch" > "$_statusfile" 2>/dev/null || true
