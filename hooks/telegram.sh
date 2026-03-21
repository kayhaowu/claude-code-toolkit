#!/bin/sh
# Telegram helper — sourced by tg-notify hooks
# Loads TG_TOKEN and TG_CHAT_ID from ~/.claude/.env

[ -f "$HOME/.claude/.env" ] && . "$HOME/.claude/.env"

send_tg() {
    [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ] && return 0
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "parse_mode=HTML" \
        --data-urlencode "text=$1" \
        > /dev/null 2>&1 &
}
