#!/bin/sh
# Event-driven status update for Claude Code sessions.
# Called by hooks: sh status-hook.sh <claude_pid> <working|idle>
# Writes a lightweight plain-text status file (~5ms, no jq).
_pid="${1:?}" _status="${2:?}"
mkdir -p "$HOME/.claude/sessions"
printf '%s %s\n' "$_status" "$(date +%s)" > "$HOME/.claude/sessions/$_pid.status" 2>/dev/null || true
