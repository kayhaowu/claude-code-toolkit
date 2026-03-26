#!/bin/sh
# Claude Code Dashboard - live view of all active Claude Code sessions
# Usage: sh ~/.claude/dashboard.sh
# Press Ctrl+C to exit.

SESSIONS_DIR="$HOME/.claude/sessions"
INTERVAL=2

# ── ANSI color variables (interpreted via printf '%b') ───────────────────────
R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
C_TITLE='\033[1;35m'   # Bold purple  — dashboard title
C_HEAD='\033[1;37m'    # Bold white   — column headers
C_SEP='\033[2;37m'     # Dim white    — separators / divider line
C_PID='\033[36m'       # Cyan         — PID
C_PROJ='\033[1;32m'    # Bold green   — project name
C_MODEL='\033[37m'     # White        — model
C_BAR_F='\033[32m'     # Green        — bar filled
C_BAR_E='\033[90m'     # Dark gray    — bar empty
C_PCT='\033[33m'       # Yellow       — percentage
C_OUT='\033[36m'       # Cyan         — output tokens
C_BRANCH='\033[94m'    # Bright blue  — git branch
C_NAME='\033[0;97m'    # Bright white  — session name/slug
C_ACT='\033[2;37m'     # Dim white    — last activity text
C_WORKING='\033[1;33m' # Bold yellow  — WORKING status
C_IDLE='\033[1;32m'    # Bold green   — IDLE status
C_WAITING='\033[2;37m' # Dim white    — WAITING status
C_QUEUED='\033[1;35m'  # Bold magenta — QUEUED status
C_DONE='\033[1;32m'    # Bold green   — DONE status

# ── Helpers ───────────────────────────────────────────────────────────────────
fmt_k() {
    n="$1"
    if [ "$n" -ge 1000000 ] 2>/dev/null; then
        awk -v v="$n" 'BEGIN{printf "%.1fM",v/1000000}'
    elif [ "$n" -ge 1000 ] 2>/dev/null; then
        awk -v v="$n" 'BEGIN{printf "%.1fk",v/1000}'
    else
        printf '%s' "$n"
    fi
}

fmt_mem() {
    kb="$1"
    if [ "$kb" -ge 1048576 ] 2>/dev/null; then
        awk -v v="$kb" 'BEGIN{printf "%.1fG",v/1048576}'
    elif [ "$kb" -ge 1024 ] 2>/dev/null; then
        awk -v v="$kb" 'BEGIN{printf "%.1fM",v/1024}'
    else
        printf '%s' "${kb}K"
    fi
}

# CJK-aware column padding: each CJK char is 2 display columns.
# Uses byte count vs char count difference to detect multi-byte chars.
pad_wide() {
    _pw_str="$1"; _pw_width="$2"
    _pw_bytes=$(printf '%s' "$_pw_str" | wc -c)
    _pw_chars=$(printf '%s' "$_pw_str" | wc -m)
    _pw_disp=$(( _pw_chars + (_pw_bytes - _pw_chars) / 2 ))
    _pw_pad=$(( _pw_width - _pw_disp ))
    [ "$_pw_pad" -lt 0 ] && _pw_pad=0
    printf '%s%*s' "$_pw_str" "$_pw_pad" ""
}

make_bar() {
    pct="$1"; width="${2:-24}"
    filled=$(( pct * width / 100 ))
    empty=$(( width - filled ))
    bar_f=""; i=0; while [ $i -lt $filled ]; do bar_f="${bar_f}█"; i=$((i+1)); done
    bar_e=""; i=0; while [ $i -lt $empty ]; do bar_e="${bar_e}░"; i=$((i+1)); done
    printf '%b[%b%s%b%s%b]' "$R" "$C_BAR_F" "$bar_f" "$C_BAR_E" "$bar_e" "$R"
}

# ── Main render ───────────────────────────────────────────────────────────────
render() {
    printf '\033[2J\033[H'
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    now=$(date +%s)

    printf '%b' "${C_TITLE}Claude Code Dashboard${R}  ${ts}  ${DIM}(every ${INTERVAL}s)${R}"
    printf '\n\n'

    # Column headers
    printf '%b%-8s %-22s %-14s %-12s %-8s %-24s %-6s %-7s %s%b\n' \
        "$C_HEAD" \
        'PID' 'NAME' 'PROJECT' 'MODEL' 'STATUS' 'CONTEXT' 'CTX%' 'OUTPUT' 'BRANCH' \
        "$R"
    printf '%b%s%b\n' "$C_SEP" \
        "-------- ---------------------- -------------- ------------ -------- ------------------------ ------ ------- ----------" \
        "$R"

    count=0; total_in=0; total_out=0; total_mem=0

    for f in "$SESSIONS_DIR"/*.json; do
        [ -f "$f" ] || continue

        pid=$(jq -r '.pid // 0' "$f" 2>/dev/null); [ "$pid" -gt 0 ] 2>/dev/null || continue

        # Remove stale sessions for dead processes
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$f" "$SESSIONS_DIR/${pid}.status"
            continue
        fi

        epoch=$(jq -r       '.epoch          // 0'  "$f" 2>/dev/null)
        project=$(jq -r    '.project_name   // "unknown"' "$f" 2>/dev/null)
        project_dir=$(jq -r '.project_dir   // ""'  "$f" 2>/dev/null)
        model_r=$(jq -r    '.model          // "Unknown"' "$f" 2>/dev/null)
        status_r=$(jq -r   '.status         // ""'  "$f" 2>/dev/null)
        used_pct=$(jq -r   '.used_pct       // 0'   "$f" 2>/dev/null)
        tokens_in=$(jq -r  '.tokens_in      // 0'   "$f" 2>/dev/null)
        tokens_out=$(jq -r '.tokens_out     // 0'   "$f" 2>/dev/null)
        branch=$(jq -r     '.git_branch     // ""'  "$f" 2>/dev/null)
        activity=$(jq -r   '.last_activity  // ""'  "$f" 2>/dev/null)
        mem_kb=$(jq -r     '.mem_kb         // 0'   "$f" 2>/dev/null)
        session_title=$(jq -r '.session_title // ""' "$f" 2>/dev/null)

        # Shorten model name: "Claude Opus 4.6" → "Opus 4.6"
        model=$(printf '%s' "$model_r" | sed 's/^Claude //')

        # Session name: prefer session_title from JSON (written by statusline),
        # fall back to epoch-mtime JSONL match for the slug field.
        slug="$session_title"
        if [ -z "$slug" ] && [ -n "$project_dir" ]; then
            _proj_key=$(printf '%s' "$project_dir" | tr '/' '-')
            _proj_jsonl_dir="$HOME/.claude/projects/${_proj_key}"
            if [ -d "$_proj_jsonl_dir" ]; then
                _best="" _best_diff=999999
                for _jf in "$_proj_jsonl_dir"/*.jsonl; do
                    [ -f "$_jf" ] || continue
                    _mtime=$(stat -c %Y "$_jf" 2>/dev/null || stat -f %m "$_jf" 2>/dev/null) || continue
                    _diff=$(( epoch - _mtime ))
                    [ "$_diff" -lt 0 ] && _diff=$(( -_diff ))
                    [ "$_diff" -lt "$_best_diff" ] && { _best="$_jf"; _best_diff="$_diff"; }
                done
                if [ -n "$_best" ]; then
                    # Prefer customTitle (/rename) over auto-generated slug
                    slug=$(grep '"type":"custom-title"' "$_best" 2>/dev/null | tail -1 | \
                        jq -r '.customTitle // ""' 2>/dev/null) || slug=""
                    [ -z "$slug" ] && \
                        slug=$(tail -1 "$_best" 2>/dev/null | jq -r '.slug // ""' 2>/dev/null) || true
                fi
            fi
        fi

        # Determine display status: prefer event-driven .status file
        disp_status="" _status_epoch=""
        read -r disp_status _status_epoch < "$SESSIONS_DIR/${pid}.status" 2>/dev/null || disp_status=""
        # Fallback: JSON field, then file age
        if [ -z "$disp_status" ]; then
            age=$(( now - epoch ))
            if [ -n "$status_r" ] && [ "$status_r" != "null" ] && [ "$status_r" != "" ]; then
                disp_status="$status_r"
            elif [ "$age" -lt 10 ]; then
                disp_status="working"
            else
                disp_status="idle"
            fi
        fi

        case "$(printf '%s' "$disp_status" | tr '[:upper:]' '[:lower:]')" in
            working|thinking|responding|streaming) sc="$C_WORKING"; sl="WORKING" ;;
            done)                                  sc="$C_DONE";    sl="DONE"    ;;
            idle|waiting_for_input)                sc="$C_IDLE";    sl="IDLE"    ;;
            waiting)                               sc="$C_WAITING"; sl="WAITING" ;;
            queued)                                sc="$C_QUEUED";  sl="QUEUED"  ;;
            *)                                     sc="$C_IDLE";    sl="IDLE"    ;;
        esac

        bar=$(make_bar "$used_pct" 22)
        out_str=$(fmt_k "$tokens_out")

        # Row
        printf '%b%-8s%b ' "$C_PID"    "$pid"    "$R"
        printf '%b' "$C_NAME"; pad_wide "$slug" 22; printf '%b ' "$R"
        printf '%b%-14s%b ' "$C_PROJ"  "$project" "$R"
        printf '%b%-12s%b ' "$C_MODEL" "$model"   "$R"
        printf '%b%-8s%b '  "$sc"      "$sl"      "$R"
        printf '%s '        "$bar"
        printf '%b%-6s%b '  "$C_PCT"   "${used_pct}%" "$R"
        printf '%b%-7s%b '  "$C_OUT"   "$out_str"     "$R"
        printf '%b%s%b\n'   "$C_BRANCH" "$branch"     "$R"

        # Last activity (truncated to 110 chars)
        if [ -n "$activity" ] && [ "$activity" != "null" ]; then
            short=$(printf '%s' "$activity" | cut -c1-110)
            printf '%b  » %s%b\n' "$C_ACT" "$short" "$R"
        fi

        count=$((count + 1))
        total_in=$((total_in + tokens_in))
        total_out=$((total_out + tokens_out))
        total_mem=$((total_mem + mem_kb))
    done

    if [ "$count" -eq 0 ]; then
        printf '\n%s  No active Claude Code sessions found.%s\n' "$DIM" "$R"
        printf '%s  Session data appears here automatically when Claude Code is running.%s\n' "$DIM" "$R"
    fi

    # Divider
    printf '\n%b────────────────────────────────────────────────────────────────────────────────%b\n' \
        "$C_SEP" "$R"

    # Summary
    ctx_str=$(fmt_k "$total_in")
    out_str=$(fmt_k "$total_out")
    mem_str=$(fmt_mem "$total_mem")

    printf '%bInstances:%b %b%s%b  ' "$BOLD" "$R" "$C_OUT" "$count"    "$R"
    printf '%bContext:%b %b%s%b  '   "$BOLD" "$R" "$C_OUT" "$ctx_str"  "$R"
    printf '%bOutput:%b %b%s%b  '    "$BOLD" "$R" "$C_OUT" "$out_str"  "$R"
    printf '%bMem:%b %b%s%b\n'       "$BOLD" "$R" "$C_OUT" "$mem_str"  "$R"

    # Status legend
    printf '\n%bStatus:%b  %bWORKING%b  %bDONE%b  %bIDLE%b  %bWAITING%b  %bQUEUED%b' \
        "$BOLD" "$R" "$C_WORKING" "$R" "$C_DONE" "$R" "$C_IDLE" "$R" "$C_WAITING" "$R" "$C_QUEUED" "$R"
    printf '   %b» text  → tool  « user%b\n' "$DIM" "$R"
}

# ── Entry point ───────────────────────────────────────────────────────────────
mkdir -p "$SESSIONS_DIR"
trap 'printf "\n"; exit 0' INT TERM

while true; do
    render
    sleep "$INTERVAL"
done
