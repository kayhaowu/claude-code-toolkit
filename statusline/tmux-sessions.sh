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
    _base="${_sf##*/}"; _base="${_base%.json}"
    case "$_base" in *[!0-9]*) continue ;; esac

    # Single jq call: extract all needed fields in one pass
    _tsv=$(jq -r '[(.pid // 0), (.project_name // "?"), (.used_pct // 0), (.status // ""), (.epoch // 0)] | @tsv' "$_sf" 2>/dev/null) || continue
    IFS='	' read -r _pid _name _pct _json_status _epoch <<EOF
$_tsv
EOF
    _name=$(printf '%.12s' "$_name")

    kill -0 "$_pid" 2>/dev/null || { rm -f "$_sf" "$SESSIONS_DIR/$_base.status"; continue; }

    # Read status from event-driven .status file (authoritative source)
    _status="" _status_epoch=""
    { read -r _status _status_epoch < "$SESSIONS_DIR/$_base.status"; } 2>/dev/null || _status=""
    # Fallback: JSON status + age-based override (only when no .status file)
    if [ -z "$_status" ]; then
        if [ -n "$_json_status" ] && [ "$_json_status" != "null" ]; then
            _status="$_json_status"
        fi
        # Only apply age heuristic when JSON status is also absent
        if [ -z "$_status" ]; then
            _age=$(( _now - _epoch ))
            if [ "$_age" -gt 10 ]; then
                _status="idle"
            fi
        fi
    fi

    # Status icon
    case "$_status" in
        working*|WORKING*) _icon="⚡" ;;
        done*)
            # Auto-expire done → idle after 30 seconds
            if [ -n "$_status_epoch" ] && [ "$_status_epoch" -gt 0 ] 2>/dev/null; then
                _done_age=$(( _now - _status_epoch ))
                if [ "$_done_age" -lt 30 ]; then
                    _icon="✅"
                else
                    _icon="💤"
                fi
            else
                _icon="✅"
            fi
            ;;
        idle*|IDLE*)        _icon="💤" ;;
        *)                  _icon="·" ;;
    esac
    # Status color (Catppuccin Mocha)
    case "$_status" in
        working*|WORKING*) _color="#f9e2af" ;;  # yellow
        done*)              _color="#a6e3a1" ;;  # green
        idle*|IDLE*)        _color="#89b4fa" ;;  # blue
        *)                  _color="#6c7086" ;;  # overlay1
    esac
    if [ -n "$_out" ]; then
        _out="${_out}#[fg=#bd93f9] │ "
    fi
    _out="${_out}#[fg=${_color}]${_icon} ${_name} ${_pct}%"
    _count=$(( _count + 1 ))
done

[ "$_count" -eq 0 ] && exit 0
printf '%s' "$_out"
