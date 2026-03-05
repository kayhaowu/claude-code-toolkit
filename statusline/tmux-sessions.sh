#!/bin/sh
# Lightweight tmux status bar segment showing Claude Code session status.
# Reads pre-computed session JSON files — runs in ~10ms.
# Usage: Add #(/path/to/tmux-sessions.sh) to tmux status-right.

SESSIONS_DIR="$HOME/.claude/sessions"
[ -d "$SESSIONS_DIR" ] || exit 0

_now=$(date +%s)
_out=""
_count=0
for _sf in "$SESSIONS_DIR"/*.json; do
    [ -f "$_sf" ] || continue
    case "$(basename "$_sf" .json)" in *[!0-9]*) continue ;; esac
    _pid=$(jq -r '.pid // 0' "$_sf" 2>/dev/null)
    kill -0 "$_pid" 2>/dev/null || { rm -f "$_sf"; continue; }
    _name=$(jq -r '.project_name // "?"' "$_sf" 2>/dev/null | cut -c1-12)
    _status=$(jq -r '.status // ""' "$_sf" 2>/dev/null)
    _pct=$(jq -r '.used_pct // 0' "$_sf" 2>/dev/null)
    _epoch=$(jq -r '.epoch // 0' "$_sf" 2>/dev/null)
    _age=$(( _now - _epoch ))
    # Override status: if no statusline render for >10s, session is idle
    # (statusline only renders when Claude is actively working)
    if [ "$_age" -gt 10 ]; then
        _status="idle"
    fi
    # Status icon
    case "$_status" in
        working*|WORKING*) _icon="⚡" ;;
        idle*|IDLE*)        _icon="💤" ;;
        *)                  _icon="·" ;;
    esac
    if [ -n "$_out" ]; then
        _out="${_out} │ "
    fi
    _out="${_out}${_icon}${_name} ${_pct}%"
    _count=$(( _count + 1 ))
done

[ "$_count" -eq 0 ] && exit 0
printf '%s' "$_out"
