#!/bin/sh
# Claude Code hook: Telegram notification on session stop
# Event: Stop
# Sends ✅ with a brief summary of what Claude just did

. "$HOME/.claude/hooks/telegram.sh"

INPUT=$(cat)

SUMMARY=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' | cut -c1-300)
[ -z "$SUMMARY" ] && exit 0

send_tg "✅ <b>Claude finished</b>

${SUMMARY}"

exit 0
