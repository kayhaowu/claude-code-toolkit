#!/bin/sh
# Claude Code hook: Log session usage to JSONL.
# Events: SessionStart + SessionEnd
# Command: sh ~/.claude/hooks/usage-logger.sh start|end $PPID
# Writes to ~/.claude/hooks/usage.jsonl

_action="${1:?Usage: usage-logger.sh start|end <pid>}"
_pid="${2:?Usage: usage-logger.sh start|end <pid>}"
HOOKS_DIR="$HOME/.claude/hooks"
SESSIONS_TMP="$HOOKS_DIR/sessions"
TMP_FILE="$SESSIONS_TMP/$_pid.tmp.json"
USAGE_LOG="$HOOKS_DIR/usage.jsonl"
SESSION_FILE="$HOME/.claude/sessions/$_pid.json"

_input=$(cat)

case "$_action" in
    start)
        mkdir -p "$SESSIONS_TMP"
        _tsv=$(printf '%s' "$_input" | jq -r '[.session_id // "", .cwd // "", .model // ""] | @tsv')
        IFS='	' read -r _session_id _cwd _model <<EOF
$_tsv
EOF
        _project=$(basename "${_cwd:-unknown}")
        _start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        jq -n \
            --arg sid "$_session_id" \
            --arg proj "$_project" \
            --arg model "$_model" \
            --arg start "$_start" \
            '{session_id:$sid,project:$proj,model:$model,start:$start}' \
            > "$TMP_FILE" 2>/dev/null || true
        ;;

    end)
        [ -f "$TMP_FILE" ] || exit 0

        _end=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Read start data from temp file (single jq call)
        _tmp_data=$(jq -r '[.start, .session_id, .project, .model] | @tsv' "$TMP_FILE" 2>/dev/null) || exit 0
        IFS='	' read -r _start _session_id _project _model <<EOF
$_tmp_data
EOF

        # Calculate duration
        _start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$_start" +%s 2>/dev/null) \
            || _start_epoch=$(date -d "$_start" +%s 2>/dev/null) \
            || _start_epoch=0
        _end_epoch=$(date +%s)
        _duration=$(( _end_epoch - _start_epoch ))

        # Try to get token count from statusline session JSON
        _tokens=""
        if [ -f "$SESSION_FILE" ]; then
            _tokens=$(jq -r '(.tokens_in // 0) + (.tokens_out // 0)' "$SESSION_FILE" 2>/dev/null)
        fi

        # Build and append JSONL entry
        if [ -n "$_tokens" ] && [ "$_tokens" != "0" ]; then
            jq -n -c \
                --arg sid "$_session_id" \
                --arg proj "$_project" \
                --arg model "$_model" \
                --arg start "$_start" \
                --arg end "$_end" \
                --argjson dur "$_duration" \
                --argjson tok "$_tokens" \
                '{session_id:$sid,project:$proj,model:$model,start:$start,end:$end,duration_s:$dur,tokens:$tok}' \
                >> "$USAGE_LOG" 2>/dev/null || true
        else
            jq -n -c \
                --arg sid "$_session_id" \
                --arg proj "$_project" \
                --arg model "$_model" \
                --arg start "$_start" \
                --arg end "$_end" \
                --argjson dur "$_duration" \
                '{session_id:$sid,project:$proj,model:$model,start:$start,end:$end,duration_s:$dur}' \
                >> "$USAGE_LOG" 2>/dev/null || true
        fi

        # Cleanup temp file
        rm -f "$TMP_FILE"
        ;;

    *)
        printf 'usage-logger.sh: unknown action: %s\n' "$_action" >&2
        exit 1
        ;;
esac

exit 0
