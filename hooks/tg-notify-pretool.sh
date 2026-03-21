#!/bin/sh
# Claude Code hook: Telegram notification on Bash tool use
# Event: PreToolUse (Bash)
# Sends ⚙️ for normal commands, ⚠️ for high-risk operations

. "$HOME/.claude/hooks/telegram.sh"

INPUT=$(cat)

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
[ "$TOOL" != "Bash" ] && exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' | cut -c1-200)

HIGH_RISK='ssh |docker |rm |reboot|shutdown|mkfs|dd if=|DROP TABLE|DROP DATABASE'

if printf '%s' "$CMD" | grep -qE "$HIGH_RISK"; then
    send_tg "⚠️ <b>High-risk command</b> — check your terminal

<code>${CMD}</code>"
else
    send_tg "⚙️ <b>Claude is running a command</b>

<code>${CMD}</code>"
fi

exit 0
