# Statusline Theme System — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite statusline-command.sh with 5 color themes, semantic tokens, cost/alert segments, git cache, and NO_COLOR support while preserving progress bar, multi-session, and session state features.

**Architecture:** Single-file rewrite of statusline-command.sh. Theme selection via environment variables (NO_COLOR, CLAUDE_STATUSLINE_THEME). 12 semantic color tokens mapped per theme. Git branch cached with 5-second TTL.

**Tech Stack:** POSIX sh, jq, git, awk

---

### Task 1: Rewrite statusline-command.sh

**Files:**
- Modify: `statusline/statusline-command.sh` (full rewrite)

**Step 1: Write the complete new script**

Replace the entire contents of `statusline/statusline-command.sh` with:

```sh
#!/bin/sh
# Statusline with theme support
# Segments: model | [progress bar] | ctx% | tokens | cost | alert | git | project
# Themes: ansi-default, catppuccin-mocha, dracula, nord, none
# Set CLAUDE_STATUSLINE_THEME to choose theme. Set NO_COLOR=1 to disable colors.

input=$(cat)

# ── Theme Selection ──────────────────────────────────────────────────────────
# Priority: NO_COLOR > CLAUDE_STATUSLINE_THEME > ansi-default

if [ -n "${NO_COLOR:-}" ]; then
    _theme="none"
else
    _theme="${CLAUDE_STATUSLINE_THEME:-ansi-default}"
fi

# ── Theme Definitions (12 semantic color tokens) ─────────────────────────────

case "$_theme" in
    catppuccin-mocha)
        C_MODEL='\033[38;2;203;166;247m'    # Mauve
        C_BAR_FILL='\033[38;2;166;227;161m' # Green
        C_BAR_EMPTY='\033[38;2;88;91;112m'  # Overlay0
        C_CTX_OK='\033[38;2;166;227;161m'   # Green
        C_CTX_WARN='\033[38;2;249;226;175m' # Yellow
        C_CTX_BAD='\033[38;2;243;139;168m'  # Red
        C_TOKENS='\033[38;2;137;220;235m'   # Teal
        C_COST='\033[38;2;250;179;135m'     # Peach
        C_ALERT='\033[1;38;2;243;139;168m'  # Bold Red
        C_BRANCH='\033[38;2;116;199;236m'   # Blue
        C_PROJECT='\033[38;2;166;227;161m'  # Green
        C_SEP='\033[38;2;88;91;112m'        # Overlay0
        ;;
    dracula)
        C_MODEL='\033[38;2;189;147;249m'    # Purple
        C_BAR_FILL='\033[38;2;80;250;123m'  # Green
        C_BAR_EMPTY='\033[38;2;98;114;164m' # Comment
        C_CTX_OK='\033[38;2;80;250;123m'    # Green
        C_CTX_WARN='\033[38;2;241;250;140m' # Yellow
        C_CTX_BAD='\033[38;2;255;85;85m'    # Red
        C_TOKENS='\033[38;2;139;233;253m'   # Cyan
        C_COST='\033[38;2;255;184;108m'     # Orange
        C_ALERT='\033[1;38;2;255;85;85m'    # Bold Red
        C_BRANCH='\033[38;2;139;233;253m'   # Cyan
        C_PROJECT='\033[38;2;80;250;123m'   # Green
        C_SEP='\033[38;2;98;114;164m'       # Comment
        ;;
    nord)
        C_MODEL='\033[38;2;180;142;173m'    # Nord15 purple
        C_BAR_FILL='\033[38;2;163;190;140m' # Nord14 green
        C_BAR_EMPTY='\033[38;2;76;86;106m'  # Nord3
        C_CTX_OK='\033[38;2;163;190;140m'   # Nord14 green
        C_CTX_WARN='\033[38;2;235;203;139m' # Nord13 yellow
        C_CTX_BAD='\033[38;2;191;97;106m'   # Nord11 red
        C_TOKENS='\033[38;2;136;192;208m'   # Nord8 cyan
        C_COST='\033[38;2;208;135;112m'     # Nord12 orange
        C_ALERT='\033[1;38;2;191;97;106m'   # Bold Nord11
        C_BRANCH='\033[38;2;129;161;193m'   # Nord9 blue
        C_PROJECT='\033[38;2;163;190;140m'  # Nord14 green
        C_SEP='\033[38;2;76;86;106m'        # Nord3
        ;;
    none)
        C_MODEL='' C_BAR_FILL='' C_BAR_EMPTY=''
        C_CTX_OK='' C_CTX_WARN='' C_CTX_BAD=''
        C_TOKENS='' C_COST='' C_ALERT=''
        C_BRANCH='' C_PROJECT='' C_SEP=''
        ;;
    *) # ansi-default
        C_MODEL='\033[35m'      # Purple
        C_BAR_FILL='\033[32m'   # Green
        C_BAR_EMPTY='\033[90m'  # Dark gray
        C_CTX_OK='\033[33m'     # Yellow
        C_CTX_WARN='\033[33m'   # Yellow
        C_CTX_BAD='\033[31m'    # Red
        C_TOKENS='\033[36m'     # Cyan
        C_COST='\033[33m'       # Yellow
        C_ALERT='\033[1;31m'    # Bold red
        C_BRANCH='\033[34m'     # Blue
        C_PROJECT='\033[32m'    # Green
        C_SEP='\033[2;37m'      # Dim gray
        ;;
esac

C_RESET='\033[0m'

# Separator: plain pipe for none, styled │ for colored themes
if [ "$_theme" = "none" ]; then
    SEP=' | '
else
    SEP=" ${C_SEP}│${C_RESET} "
fi

# ── Parse JSON input ─────────────────────────────────────────────────────────

model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
tokens_used=$(( total_input + total_output ))
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
exceeds_200k=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // ""')

# ── Git branch with 5-second cache ──────────────────────────────────────────

_git_cache="/tmp/claude-sl-git-$(id -u)"
git_branch=""
if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
    _now=$(date +%s)
    _cache_hit=0
    if [ -f "$_git_cache" ]; then
        _c_epoch=$(sed -n '1p' "$_git_cache")
        _c_dir=$(sed -n '2p' "$_git_cache")
        _c_branch=$(sed -n '3p' "$_git_cache")
        if [ "$(( _now - _c_epoch ))" -lt 5 ] && [ "$_c_dir" = "$project_dir" ]; then
            git_branch="$_c_branch"
            _cache_hit=1
        fi
    fi
    if [ "$_cache_hit" -eq 0 ]; then
        git_branch=$(git -C "$project_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
        printf '%s\n%s\n%s\n' "$_now" "$project_dir" "$git_branch" > "$_git_cache" 2>/dev/null
    fi
fi

# ── Project name ─────────────────────────────────────────────────────────────

if [ -n "$project_dir" ]; then
    project_name=$(basename "$project_dir")
else
    project_name=$(basename "$(pwd)")
fi

# ── Build progress bar (20 chars wide) ───────────────────────────────────────

if [ -n "$used_pct" ]; then
    pct_int=$(printf "%.0f" "$used_pct")
    filled=$(( pct_int * 20 / 100 ))
    empty=$(( 20 - filled ))

    filled_bar="" ; i=0
    while [ $i -lt $filled ]; do
        if [ "$_theme" = "none" ]; then filled_bar="${filled_bar}="; else filled_bar="${filled_bar}█"; fi
        i=$(( i + 1 ))
    done

    empty_bar="" ; i=0
    while [ $i -lt $empty ]; do
        if [ "$_theme" = "none" ]; then empty_bar="${empty_bar}."; else empty_bar="${empty_bar}░"; fi
        i=$(( i + 1 ))
    done

    # Context % color based on usage thresholds
    if [ "$pct_int" -le 60 ]; then
        C_CTX="$C_CTX_OK"
    elif [ "$pct_int" -le 80 ]; then
        C_CTX="$C_CTX_WARN"
    else
        C_CTX="$C_CTX_BAD"
    fi
    pct_str="${pct_int}%"
else
    pct_int=0
    if [ "$_theme" = "none" ]; then
        filled_bar="" ; empty_bar="...................."
    else
        filled_bar="" ; empty_bar="░░░░░░░░░░░░░░░░░░░░"
    fi
    C_CTX="$C_CTX_OK"
    pct_str="0%"
fi

# ── Format tokens ────────────────────────────────────────────────────────────

if [ "$tokens_used" -ge 1000 ] 2>/dev/null; then
    tokens_str=$(awk "BEGIN { printf \"%.1fk\", $tokens_used/1000 }")
else
    tokens_str="${tokens_used}"
fi

# ── Format cost (only shown when >= $0.005) ──────────────────────────────────

cost_str=""
if [ -n "$cost_usd" ] && [ "$cost_usd" != "0" ] && [ "$cost_usd" != "null" ]; then
    _show_cost=$(awk "BEGIN { print ($cost_usd >= 0.005) ? 1 : 0 }")
    if [ "$_show_cost" -eq 1 ]; then
        cost_str=$(awk "BEGIN { printf \"est \$%.2f\", $cost_usd }")
    fi
fi

# ── Assemble first line ─────────────────────────────────────────────────────

printf '%b' "${C_MODEL}${model}${C_RESET}"
printf '%b' "${SEP}"
printf '%b' "[${C_BAR_FILL}${filled_bar}${C_BAR_EMPTY}${empty_bar}${C_RESET}]"
printf '%b' "${SEP}"
printf '%b' "${C_CTX}${pct_str}${C_RESET}"
printf '%b' "${SEP}"
printf '%b' "${C_TOKENS}${tokens_str} tokens${C_RESET}"

if [ -n "$cost_str" ]; then
    printf '%b' "${SEP}"
    printf '%b' "${C_COST}${cost_str}${C_RESET}"
fi

if [ "$exceeds_200k" = "true" ]; then
    printf '%b' "${SEP}"
    printf '%b' "${C_ALERT}⚠ 200k${C_RESET}"
fi

if [ -n "$git_branch" ]; then
    printf '%b' "${SEP}"
    printf '%b' "${C_BRANCH} ${git_branch}${C_RESET}"
fi

printf '%b' "${SEP}"
printf '%b' "${C_PROJECT}${project_name}${C_RESET}"
printf '\n'

# ── Second line: other active sessions ───────────────────────────────────────

SESSIONS_DIR="$HOME/.claude/sessions"
if [ -d "$SESSIONS_DIR" ]; then
    _now=$(date +%s)
    _first=1
    for _sf in "$SESSIONS_DIR"/*.json; do
        [ -f "$_sf" ] || continue
        _spid=$(jq -r '.pid // 0' "$_sf" 2>/dev/null)
        # Skip current session
        [ "$(( _spid + 0 ))" -eq "$(( PPID + 0 ))" ] 2>/dev/null && continue
        # Skip dead processes and clean up stale file
        kill -0 "$_spid" 2>/dev/null || { rm -f "$_sf"; continue; }
        _oname=$(jq -r '.project_name // "?"' "$_sf" 2>/dev/null)
        _opct=$(jq  -r '.used_pct     // 0'   "$_sf" 2>/dev/null)
        _oout=$(jq  -r '.tokens_out   // 0'   "$_sf" 2>/dev/null)
        _ostt=$(jq  -r '.status       // ""'  "$_sf" 2>/dev/null)
        _oepoch=$(jq -r '.epoch       // 0'   "$_sf" 2>/dev/null)
        _oage=$(( _now - _oepoch ))
        # Determine display status
        if [ -n "$_ostt" ] && [ "$_ostt" != "null" ] && [ "$_ostt" != "" ]; then
            _ol=$(printf '%s' "$_ostt" | tr '[:lower:]' '[:upper:]')
        elif [ "$_oage" -lt 6 ]; then
            _ol="WORKING"
        else
            _ol="IDLE"
        fi
        # Format output tokens
        if [ "$_oout" -ge 1000 ] 2>/dev/null; then
            _oout_str=$(awk "BEGIN{printf \"%.1fk\",$_oout/1000}")
        else
            _oout_str="$_oout"
        fi
        # Status color using theme tokens
        case "$_ol" in
            WORKING*|THINKING*) _oc="$C_CTX_WARN" ;;
            WAITING*)           _oc="$C_SEP" ;;
            QUEUED*)            _oc="$C_MODEL" ;;
            *)                  _oc="$C_CTX_OK" ;;
        esac
        # Truncate long project names
        _oname=$(printf '%s' "$_oname" | cut -c1-14)
        # Print prefix (first session) or separator
        if [ "$_first" -eq 1 ]; then
            printf '%b' "${C_SEP}↳ ${C_RESET}"
            _first=0
        else
            printf '%b' "${SEP}"
        fi
        printf '%b' "${C_PROJECT}${_oname}${C_RESET} ${C_SEP}[${C_RESET}${_oc}${_ol}${C_RESET} ${C_CTX_WARN}${_opct}%${C_RESET} ${C_TOKENS}${_oout_str}${C_RESET}${C_SEP}]${C_RESET}"
    done
    [ "$_first" -eq 0 ] && printf '\n'
fi

# ── Write session state for dashboard ────────────────────────────────────────

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
        --arg cost   "${cost_usd:-0}" \
        '{pid:($pid|tonumber),epoch:($epoch|tonumber),model:$model,
          project_dir:$pdir,project_name:$pname,git_branch:$branch,
          status:$status,last_activity:$act,
          used_pct:($pct|tonumber),tokens_in:($tin|tonumber),
          tokens_out:($tout|tonumber),mem_kb:($mem|tonumber),
          cost_usd:($cost|tonumber)}' \
        > "$SESSIONS_DIR/$PPID.json" 2>/dev/null || true
fi
```

**Step 2: Verify with ansi-default theme (sample JSON)**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":45.2,"total_input_tokens":30000,"total_output_tokens":15200},"cost":{"total_cost_usd":0.12},"exceeds_200k_tokens":false,"workspace":{"project_dir":"'$(pwd)'"}}' | sh statusline/statusline-command.sh
```

Expected: colored output with model, progress bar, 45%, 45.2k tokens, est $0.12, git branch, project name.

**Step 3: Verify catppuccin-mocha theme**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":75,"total_input_tokens":50000,"total_output_tokens":25000},"cost":{"total_cost_usd":0.42},"exceeds_200k_tokens":false,"workspace":{"project_dir":"'$(pwd)'"}}' | CLAUDE_STATUSLINE_THEME=catppuccin-mocha sh statusline/statusline-command.sh
```

Expected: TrueColor pastel output, context % in yellow (warn threshold 60-80%).

**Step 4: Verify dracula theme**

Run:
```bash
echo '{"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":85,"total_input_tokens":80000,"total_output_tokens":40000},"cost":{"total_cost_usd":1.05},"exceeds_200k_tokens":true,"workspace":{"project_dir":"'$(pwd)'"}}' | CLAUDE_STATUSLINE_THEME=dracula sh statusline/statusline-command.sh
```

Expected: Dracula colors, context % in red (>80%), 200k alert visible.

**Step 5: Verify nord theme**

Run:
```bash
echo '{"model":{"display_name":"Haiku 4.5"},"context_window":{"used_percentage":20,"total_input_tokens":5000,"total_output_tokens":2000},"cost":{"total_cost_usd":0.003},"exceeds_200k_tokens":false,"workspace":{"project_dir":"'$(pwd)'"}}' | CLAUDE_STATUSLINE_THEME=nord sh statusline/statusline-command.sh
```

Expected: Nord arctic blue theme, no cost (below $0.005 threshold), no alert.

**Step 6: Verify NO_COLOR mode**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":50,"total_input_tokens":30000,"total_output_tokens":15000},"cost":{"total_cost_usd":0.25},"exceeds_200k_tokens":false,"workspace":{"project_dir":"'$(pwd)'"}}' | NO_COLOR=1 sh statusline/statusline-command.sh
```

Expected: plain text with `|` separators, `=` and `.` for bar, no ANSI escape codes.

**Step 7: Commit**

```bash
git add statusline/statusline-command.sh
git commit -m "feat: add theme system with 5 color themes and semantic tokens

Rewrite statusline-command.sh with:
- 5 themes: ansi-default, catppuccin-mocha, dracula, nord, none
- 12 semantic color tokens (C_MODEL, C_BAR_FILL, etc.)
- NO_COLOR environment variable support
- Cost display segment (est \$X.XX, shown when >= \$0.005)
- 200k token alert segment
- Git branch 5-second cache
- Context % color thresholds (OK ≤60%, WARN 60-80%, BAD >80%)
- Preserved: progress bar, multi-session second line, session state write"
```

---

### Task 2: Update README documentation

**Files:**
- Modify: `statusline/README.md`

**Step 1: Add theme documentation section**

Add a "Themes" section documenting:
- Available themes and how to set them
- CLAUDE_STATUSLINE_THEME environment variable
- NO_COLOR support
- New segments (cost, 200k alert)

**Step 2: Commit**

```bash
git add statusline/README.md
git commit -m "docs: add theme system documentation to statusline README"
```
