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
    _frame=$(
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    now=$(date +%s)

    printf '%b' "${C_TITLE}Claude Code Dashboard${R}  ${ts}  ${DIM}(every ${INTERVAL}s)${R}"
    printf '\n\n'

    # Column headers
    printf '%b%-8s %-18s %-14s %-9s %-26s %-6s %-8s %s%b\n' \
        "$C_HEAD" \
        'PID' 'PROJECT' 'MODEL' 'STATUS' 'CONTEXT' 'CTX%' 'OUTPUT' 'BRANCH' \
        "$R"
    printf '%b%s%b\n' "$C_SEP" \
        "------  ----------------  ------------  -------  ------------------------  ----  ------  ----------" \
        "$R"

    count=0; total_in=0; total_out=0; total_mem=0
    _US=$(printf '\037')   # ASCII Unit Separator — POSIX-safe, non-whitespace

    for f in "$SESSIONS_DIR"/*.json; do
        [ -f "$f" ] || continue

        # Read all fields in one jq call using \u001f (unit separator) to avoid
        # IFS whitespace collapsing of consecutive empty fields (e.g. git_branch + last_activity).
        # Use octal \037 (not $'\x1f') for POSIX sh / dash compatibility.
        _row=$(jq -r '[
            .pid//0, .epoch//0,
            .project_name//"unknown", .project_dir//"",
            .model//"Unknown", .status//"",
            (.used_pct//0|tostring), (.tokens_in//0|tostring), (.tokens_out//0|tostring),
            .git_branch//"", .last_activity//"",
            (.mem_kb//0|tostring)
        ] | join("\u001f")' "$f" 2>/dev/null) || continue
        IFS="$_US" read -r pid epoch project project_dir model_r status_r \
            used_pct tokens_in tokens_out branch activity mem_kb <<EOF
$_row
EOF
        [ "$pid" -gt 0 ] 2>/dev/null || continue

        # Remove stale sessions for dead processes
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$f" "$SESSIONS_DIR/${pid}.status"
            continue
        fi

        # Shorten model name: "Claude Opus 4.6" → "Opus 4.6"
        model=$(printf '%s' "$model_r" | sed 's/^Claude //')

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

        bar=$(make_bar "$used_pct" 24)
        out_str=$(fmt_k "$tokens_out")

        # Row
        printf '%b%-8s%b ' "$C_PID"   "$pid"    "$R"
        printf '%b%-18s%b ' "$C_PROJ" "$project" "$R"
        printf '%b%-14s%b ' "$C_MODEL" "$model"  "$R"
        printf '%b%-9s%b '  "$sc"     "$sl"      "$R"
        printf '%s '        "$bar"
        printf '%b%-5s%b '  "$C_PCT"  "${used_pct}%" "$R"
        printf '%b%-8s%b '  "$C_OUT"  "$out_str"     "$R"
        printf '%b%s%b\n'   "$C_BRANCH" "$branch"    "$R"

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
    ) # end _frame
    printf '\033[2J\033[H%s' "$_frame"
}

# ── Entry point ───────────────────────────────────────────────────────────────
mkdir -p "$SESSIONS_DIR"
trap 'printf "\n"; exit 0' INT TERM

while true; do
    render
    sleep "$INTERVAL"
done
