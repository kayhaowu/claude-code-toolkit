#!/bin/sh
# Claude Code hook: Notification when Claude finishes a task.
# Event: Stop  Command: sh ~/.claude/hooks/notify-on-stop.sh $PPID
# Triggers only when working time > 30 seconds.
# Notification chain: tmux ✅ → terminal bell → macOS/Linux notification

_pid="${1:?Usage: notify-on-stop.sh <claude_pid>}"
SESSIONS_DIR="$HOME/.claude/sessions"
STATUS_FILE="$SESSIONS_DIR/$_pid.status"
SESSION_FILE="$SESSIONS_DIR/$_pid.json"

# ── Stop-loop prevention ────────────────────────────────────────────────────
# If this Stop was triggered by a previous hook's systemMessage, skip
# to avoid double-notification
_input=$(cat)
_active=$(printf '%s' "$_input" | jq -r '.stop_hook_active // false')
[ "$_active" = "true" ] && exit 0

# ── Calculate elapsed working time ───────────────────────────────────────────
# status-hook.sh writes "idle <preserved_working_epoch>" (preserves the epoch
# from when "working" was written). So _status_epoch = when work started.
_status="" _status_epoch=""
read -r _status _status_epoch < "$STATUS_FILE" 2>/dev/null || exit 0

_now=$(date +%s)

if [ -z "$_status_epoch" ] || ! [ "$_status_epoch" -gt 0 ] 2>/dev/null; then
    exit 0
fi

_elapsed=$(( _now - _status_epoch ))

# Skip notification for short responses (< 30 seconds)
[ "$_elapsed" -lt 30 ] && exit 0

# ── Get project name (best effort) ──────────────────────────────────────────
_project=""
if [ -f "$SESSION_FILE" ]; then
    _project=$(jq -r '.project_name // ""' "$SESSION_FILE" 2>/dev/null)
fi
_project="${_project:-unknown}"

_msg="Task complete (${_elapsed}s) — $_project"

# ── Notification 1: tmux ✅ status ───────────────────────────────────────────
# Write "done" to .status — overrides "idle" written by status-hook.sh earlier
# tmux-sessions.sh displays ✅ when done + age < 30s
if [ -n "${TMUX:-}" ] && [ -f "$HOME/.claude/statusline-command.sh" ]; then
    printf '%s %s\n' "done" "$_now" > "$STATUS_FILE" 2>/dev/null || true
fi

# ── Notification 2: Terminal bell ────────────────────────────────────────────
printf '\a'

# ── Notification 3: macOS Notification Center ────────────────────────────────
if [ "$(uname)" = "Darwin" ] && [ -z "${SSH_TTY:-}" ]; then
    osascript -e "display notification \"$_msg\" with title \"Claude Code\"" 2>/dev/null || true
fi

# ── Notification 4: Linux desktop notification ───────────────────────────────
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Claude Code" "$_msg" 2>/dev/null || true
    fi
fi

exit 0
