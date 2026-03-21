#!/usr/bin/env bash
# Interactive widget configurator for Claude Code statusline
# Usage: bash statusline/configure.sh
# Saves to: ~/.claude/statusline-widgets.conf
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$HOME/.claude/statusline-widgets.conf"

# ── Color helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Widget definitions ───────────────────────────────────────────────────────
ALL_WIDGETS=(model bar ctx tokens cost duration lines alert git project version vim rate5h rate7d rate)
declare -A WIDGET_DESC=(
    [model]="Model name"
    [bar]="Progress bar"
    [ctx]="Context %"
    [tokens]="Token count"
    [cost]="Session cost"
    [duration]="Session duration"
    [lines]="Lines changed"
    [alert]="200k alert"
    [git]="Git branch"
    [project]="Project name"
    [version]="CC version"
    [vim]="Vim mode"
    [rate5h]="5h rate limit"
    [rate7d]="7d rate limit"
    [rate]="5h+7d combined"
)
declare -A WIDGET_EXAMPLE=(
    [model]="Opus 4.6"
    [bar]="[████████░░░░░░░░░░░░]"
    [ctx]="42%"
    [tokens]="85.2k tokens"
    [cost]="\$11.01"
    [duration]="4h47m"
    [lines]="+538/-47"
    [alert]="⚠ 200k"
    [git]=" main"
    [project]="my-project"
    [version]="v2.1.76"
    [vim]="[NORMAL]"
    [rate5h]="5h ●●○○○ 42% 2h31m"
    [rate7d]="7d ●●●●○ 85% 1d3h"
    [rate]="5h ●●○○○ 42% 2h31m  7d ●●●●○ 85% 1d3h"
)

# ── State: active widgets and their line assignments ─────────────────────────
ACTIVE=()
ACTIVE_LINE=()

# ── Load existing config or defaults ─────────────────────────────────────────
load_config() {
    ACTIVE=()
    ACTIVE_LINE=()
    if [[ -f "$CONF_FILE" ]]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^#|^$ ]] && continue
            local wname="${line%% *}"
            local wline="${line##* }"
            [[ "$wline" =~ ^[12]$ ]] || wline=1
            ACTIVE+=("$wname")
            ACTIVE_LINE+=("$wline")
        done < "$CONF_FILE"
    else
        # Defaults
        ACTIVE=(model bar ctx tokens git project)
        ACTIVE_LINE=(1 1 1 1 1 1)
    fi
}

# ── Check if widget is active ────────────────────────────────────────────────
is_active() {
    local w="$1"
    for i in "${!ACTIVE[@]}"; do
        [[ "${ACTIVE[$i]}" == "$w" ]] && return 0
    done
    return 1
}

# ── Get index of active widget ───────────────────────────────────────────────
active_index() {
    local w="$1"
    for i in "${!ACTIVE[@]}"; do
        [[ "${ACTIVE[$i]}" == "$w" ]] && echo "$i" && return 0
    done
    return 1
}

# ── Get disabled widgets ─────────────────────────────────────────────────────
get_disabled() {
    local disabled=()
    for w in "${ALL_WIDGETS[@]}"; do
        is_active "$w" || disabled+=("$w")
    done
    echo "${disabled[@]}"
}

# ── Draw the UI ──────────────────────────────────────────────────────────────
draw_ui() {
    printf '\033[2J\033[H'
    echo ""
    printf "  ${BOLD}${CYAN}Claude Code Statusline Configurator${NC}\n"
    printf "  ${DIM}────────────────────────────────────────────${NC}\n"
    echo ""

    # Line 1
    printf "  ${BOLD}Line 1:${NC}\n"
    local num=1
    for i in "${!ACTIVE[@]}"; do
        if [[ "${ACTIVE_LINE[$i]}" == "1" ]]; then
            local w="${ACTIVE[$i]}"
            printf "   ${GREEN}%2d.${NC} %-10s ${DIM}%s${NC}\n" "$num" "$w" "${WIDGET_EXAMPLE[$w]}"
            num=$((num + 1))
        fi
    done
    [[ $num -eq 1 ]] && printf "   ${DIM}(empty)${NC}\n"

    # Line 2
    local has_l2=0
    for i in "${!ACTIVE[@]}"; do
        [[ "${ACTIVE_LINE[$i]}" == "2" ]] && has_l2=1 && break
    done
    echo ""
    printf "  ${BOLD}Line 2:${NC}\n"
    if [[ $has_l2 -eq 1 ]]; then
        for i in "${!ACTIVE[@]}"; do
            if [[ "${ACTIVE_LINE[$i]}" == "2" ]]; then
                local w="${ACTIVE[$i]}"
                printf "   ${GREEN}%2d.${NC} %-10s ${DIM}%s${NC}\n" "$num" "$w" "${WIDGET_EXAMPLE[$w]}"
                num=$((num + 1))
            fi
        done
    else
        printf "   ${DIM}(empty — use 'l' to move widgets here)${NC}\n"
    fi

    # Disabled
    local disabled
    disabled=$(get_disabled)
    echo ""
    printf "  ${BOLD}Disabled:${NC}\n"
    if [[ -n "$disabled" ]]; then
        for w in $disabled; do
            printf "       %-10s ${DIM}%s${NC}\n" "$w" "${WIDGET_DESC[$w]}"
        done
    else
        printf "   ${DIM}(none)${NC}\n"
    fi

    # Preview
    echo ""
    printf "  ${BOLD}Preview:${NC}\n"
    show_preview "  "

    # Commands
    echo ""
    printf "  ${DIM}────────────────────────────────────────────${NC}\n"
    printf "  ${BOLD}Commands:${NC}\n"
    printf "   ${CYAN}a${NC} ${DIM}widget${NC}  Add widget      ${CYAN}d${NC} ${DIM}widget${NC}  Remove widget\n"
    printf "   ${CYAN}l${NC} ${DIM}widget${NC}  Switch line     ${CYAN}u${NC} ${DIM}widget${NC}  Move up\n"
    printf "   ${CYAN}r${NC}         Reset defaults  ${CYAN}s${NC}         Save & exit\n"
    printf "   ${CYAN}q${NC}         Quit (no save)\n"
    printf "  ${DIM}────────────────────────────────────────────${NC}\n"
}

# ── Preview using actual statusline-command.sh ───────────────────────────────
show_preview() {
    local prefix="${1:-}"
    local mock_json='{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":42,"total_input_tokens":2000,"total_output_tokens":83200,"context_window_size":200000},"cost":{"total_cost_usd":3.52,"total_duration_ms":7263000,"total_lines_added":538,"total_lines_removed":47},"exceeds_200k_tokens":false,"workspace":{"project_dir":"/home/user/my-project"},"version":"2.1.76","vim":{"mode":"NORMAL"},"rate_limits":{"five_hour":{"used_percentage":42.3,"resets_at":"2099-01-01T00:00:00Z"},"seven_day":{"used_percentage":85.7,"resets_at":"2099-01-01T00:00:00Z"}}}'

    # Write temp config
    local tmp_conf
    tmp_conf=$(mktemp)
    for i in "${!ACTIVE[@]}"; do
        echo "${ACTIVE[$i]} ${ACTIVE_LINE[$i]}" >> "$tmp_conf"
    done

    local output _preview_err
    _preview_err=$(mktemp)
    output=$(echo "$mock_json" | CLAUDE_STATUSLINE_WIDGETS_CONF="$tmp_conf" CLAUDE_STATUSLINE_SHOW_COST=1 sh "$SCRIPT_DIR/statusline-command.sh" 2>"$_preview_err") || true
    rm -f "$tmp_conf"

    if [[ -n "$output" ]]; then
        while IFS= read -r line; do
            printf '%s%b\n' "$prefix" "$line"
        done <<< "$output"
    elif [[ -s "$_preview_err" ]]; then
        printf '%s%b%s%b\n' "$prefix" "${RED}" "Preview error: $(cat "$_preview_err")" "${NC}"
    else
        printf '%s%s\n' "$prefix" "${DIM}(no output — add some widgets)${NC}"
    fi
    rm -f "$_preview_err"
}

# ── Save config ──────────────────────────────────────────────────────────────
save_config() {
    mkdir -p "$(dirname "$CONF_FILE")"
    {
        echo "# Claude Code statusline widget configuration"
        echo "# Generated by configure.sh — $(date '+%Y-%m-%d %H:%M')"
        echo "# Format: widget_name line_number"
        echo "# Widgets: model bar ctx tokens cost duration lines alert git project version vim rate5h rate7d rate"
        echo "# Re-run: bash statusline/configure.sh"
        echo ""
        for i in "${!ACTIVE[@]}"; do
            echo "${ACTIVE[$i]} ${ACTIVE_LINE[$i]}"
        done
    } > "$CONF_FILE"
}

# ── Main loop ────────────────────────────────────────────────────────────────
load_config
draw_ui

while true; do
    printf "\n  ${CYAN}>${NC} "
    read -r cmd arg

    _valid=0
    _idx=""

    case "$cmd" in
        a|add)
            if [[ -z "$arg" ]]; then
                printf "  ${RED}Usage: a widget_name${NC}\n"
                continue
            fi
            _valid=0
            for w in "${ALL_WIDGETS[@]}"; do
                [[ "$w" == "$arg" ]] && _valid=1 && break
            done
            if [[ $_valid -eq 0 ]]; then
                printf "  ${RED}Unknown widget: %s${NC}\n" "$arg"
                printf "  ${DIM}Available: %s${NC}\n" "${ALL_WIDGETS[*]}"
                continue
            fi
            if is_active "$arg"; then
                printf "  ${YELLOW}%s is already active${NC}\n" "$arg"
                continue
            fi
            ACTIVE+=("$arg")
            ACTIVE_LINE+=(1)
            draw_ui
            ;;

        d|del|rm)
            if [[ -z "$arg" ]]; then
                printf "  ${RED}Usage: d widget_name${NC}\n"
                continue
            fi
            if ! is_active "$arg"; then
                printf "  ${YELLOW}%s is not active${NC}\n" "$arg"
                continue
            fi
            _idx=$(active_index "$arg")
            unset 'ACTIVE[$_idx]'
            unset 'ACTIVE_LINE[$_idx]'
            ACTIVE=("${ACTIVE[@]}")
            ACTIVE_LINE=("${ACTIVE_LINE[@]}")
            draw_ui
            ;;

        l|line)
            if [[ -z "$arg" ]]; then
                printf "  ${RED}Usage: l widget_name${NC}\n"
                continue
            fi
            if ! is_active "$arg"; then
                printf "  ${YELLOW}%s is not active${NC}\n" "$arg"
                continue
            fi
            _idx=$(active_index "$arg")
            if [[ "${ACTIVE_LINE[$_idx]}" == "1" ]]; then
                ACTIVE_LINE[$_idx]=2
            else
                ACTIVE_LINE[$_idx]=1
            fi
            draw_ui
            ;;

        u|up)
            if [[ -z "$arg" ]]; then
                printf "  ${RED}Usage: u widget_name${NC}\n"
                continue
            fi
            if ! is_active "$arg"; then
                printf "  ${YELLOW}%s is not active${NC}\n" "$arg"
                continue
            fi
            _idx=$(active_index "$arg")
            if [[ $_idx -gt 0 ]]; then
                _tmp_w="${ACTIVE[$_idx]}"
                _tmp_l="${ACTIVE_LINE[$_idx]}"
                _prev=$((_idx - 1))
                ACTIVE[$_idx]="${ACTIVE[$_prev]}"
                ACTIVE_LINE[$_idx]="${ACTIVE_LINE[$_prev]}"
                ACTIVE[$_prev]="$_tmp_w"
                ACTIVE_LINE[$_prev]="$_tmp_l"
            fi
            draw_ui
            ;;

        r|reset)
            ACTIVE=(model bar ctx tokens git project)
            ACTIVE_LINE=(1 1 1 1 1 1)
            draw_ui
            ;;

        s|save)
            save_config
            printf "\n  ${GREEN}Saved to %s${NC}\n" "$CONF_FILE"
            printf "  ${DIM}Restart Claude Code or wait for next statusline update.${NC}\n\n"
            exit 0
            ;;

        q|quit)
            printf "\n  ${DIM}Exited without saving.${NC}\n\n"
            exit 0
            ;;

        *)
            printf "  ${DIM}Unknown command. Use: a, d, l, u, r, s, q${NC}\n"
            ;;
    esac
done
