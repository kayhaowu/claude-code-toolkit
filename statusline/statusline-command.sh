#!/bin/sh
# Status line: model | progress bar | % used | tokens used | git branch | project name

input=$(cat)

# ANSI color codes
RESET='\033[0m'

# Segment colors
COLOR_MODEL='\033[35m'       # Purple/violet  (model name)
COLOR_BAR_FILL='\033[32m'    # Green          (filled bar blocks)
COLOR_BAR_EMPTY='\033[90m'   # Dark gray      (empty bar blocks)
COLOR_PCT='\033[33m'         # Yellow/amber   (percentage)
COLOR_TOKENS='\033[36m'      # Cyan           (tokens)
COLOR_BRANCH='\033[34m'      # Blue           (git branch)
COLOR_PROJECT='\033[32m'     # Green          (project name)

SEP=' \033[2;37m│\033[0m '

# 1. Model name
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')

# 2. Context window data for progress bar and percentage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
tokens_used=$(( total_input + total_output ))

# Build two-tone progress bar (20 chars wide) and percentage string
if [ -n "$used_pct" ]; then
    pct_int=$(printf "%.0f" "$used_pct")
    filled=$(( pct_int * 20 / 100 ))
    empty=$(( 20 - filled ))

    filled_bar=""
    i=0
    while [ $i -lt $filled ]; do
        filled_bar="${filled_bar}█"
        i=$(( i + 1 ))
    done

    empty_bar=""
    i=0
    while [ $i -lt $empty ]; do
        empty_bar="${empty_bar}░"
        i=$(( i + 1 ))
    done

    pct_str="${pct_int}%"
else
    filled_bar=""
    empty_bar="░░░░░░░░░░░░░░░░░░░░"
    pct_str="0%"
fi

# 4. Tokens used (formatted with k suffix if >= 1000)
if [ "$tokens_used" -ge 1000 ] 2>/dev/null; then
    tokens_str=$(awk "BEGIN { printf \"%.1fk\", $tokens_used/1000 }")
else
    tokens_str="${tokens_used}"
fi

# 5. Git branch (from project_dir, skip optional locks)
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // ""')
git_branch=""
if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
    git_branch=$(git -C "$project_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# 6. Project name (basename of project_dir)
if [ -n "$project_dir" ]; then
    project_name=$(basename "$project_dir")
else
    project_name=$(basename "$(pwd)")
fi

# Assemble the status line with colors
# printf '%b' interprets \033 escape sequences (needed for ANSI colors) while
# treating % in arguments as literal characters (safe from format injection).
printf '%b' "${COLOR_MODEL}${model}${RESET}"
printf '%b' "${SEP}"
printf '%b' "[${COLOR_BAR_FILL}${filled_bar}${COLOR_BAR_EMPTY}${empty_bar}${RESET}]"
printf '%b' "${SEP}"
printf '%b' "${COLOR_PCT}${pct_str}${RESET}"
printf '%b' "${SEP}"
printf '%b' "${COLOR_TOKENS}${tokens_str} tokens${RESET}"
if [ -n "$git_branch" ]; then
    printf '%b' "${SEP}"
    printf '%b' "${COLOR_BRANCH} ${git_branch}${RESET}"
fi
printf '%b' "${SEP}"
printf '%b' "${COLOR_PROJECT}${project_name}${RESET}"
printf '\n'

# ── Write session state for dashboard ─────────────────────────────────────────
SESSIONS_DIR="$HOME/.claude/sessions"
if [ -d "$SESSIONS_DIR" ]; then
    _epoch=$(date +%s)
    _status=$(echo "$input" | jq -r '.session.status // .status // ""' 2>/dev/null) || _status=""
    _activity=$(echo "$input" | jq -r '.last_message // .session.last_message // ""' 2>/dev/null) || _activity=""
    _mem=$(ps -o rss= -p "$PPID" 2>/dev/null | awk '{printf "%d",$1+0}') || _mem=0
    jq -n \
        --arg pid    "$PPID" \
        --arg epoch  "$_epoch" \
        --arg model  "${model:-}" \
        --arg pdir   "${project_dir:-}" \
        --arg pname  "${project_name:-}" \
        --arg branch "${git_branch:-}" \
        --arg status "${_status:-}" \
        --arg act    "${_activity:-}" \
        --arg pct    "${pct_int:-0}" \
        --arg tin    "${total_input:-0}" \
        --arg tout   "${total_output:-0}" \
        --arg mem    "${_mem:-0}" \
        '{pid:($pid|tonumber),epoch:($epoch|tonumber),model:$model,
          project_dir:$pdir,project_name:$pname,git_branch:$branch,
          status:$status,last_activity:$act,
          used_pct:($pct|tonumber),tokens_in:($tin|tonumber),
          tokens_out:($tout|tonumber),mem_kb:($mem|tonumber)}' \
        > "$SESSIONS_DIR/$PPID.json" 2>/dev/null || true
fi
