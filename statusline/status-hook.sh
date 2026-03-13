#!/bin/sh
# Event-driven status update for Claude Code sessions.
# Called by hooks: sh status-hook.sh <claude_pid> <working|idle>
# Writes a lightweight plain-text status file (~5ms, no jq).
#
# Epoch semantics:
#   working → writes current time (when work started)
#   idle    → preserves the previous epoch (so notify-on-stop.sh can calculate elapsed time)
_pid="${1:?}" _status="${2:?}"
_status_file="$HOME/.claude/sessions/$_pid.status"
mkdir -p "$HOME/.claude/sessions"

if [ "$_status" = "idle" ]; then
    # Preserve the previous epoch so downstream hooks can measure working duration
    _prev_epoch=""
    read -r _ _prev_epoch < "$_status_file" 2>/dev/null || _prev_epoch=""
    printf '%s %s\n' "$_status" "${_prev_epoch:-$(date +%s)}" > "$_status_file" 2>/dev/null || true
else
    printf '%s %s\n' "$_status" "$(date +%s)" > "$_status_file" 2>/dev/null || true
fi
