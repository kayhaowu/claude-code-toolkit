#!/bin/sh
# Claude Code hook: Warn when context usage is high.
# Event: Stop  Command: sh ~/.claude/hooks/context-alert.sh $PPID
# Reads session JSON for used_pct, outputs systemMessage if > 80%.
# Requires statusline installed.

_pid="${1:?Usage: context-alert.sh <claude_pid>}"
SESSION_FILE="$HOME/.claude/sessions/$_pid.json"

# ── Stop-loop prevention ────────────────────────────────────────────────────
# If this Stop was triggered by a previous hook's systemMessage, skip to avoid loop
_input=$(cat)
_active=$(printf '%s' "$_input" | jq -r '.stop_hook_active // false')
[ "$_active" = "true" ] && exit 0

# ── Read context usage ──────────────────────────────────────────────────────
[ -f "$SESSION_FILE" ] || exit 0
_pct=$(jq -r '.used_pct // 0' "$SESSION_FILE" 2>/dev/null)
[ -z "$_pct" ] && exit 0

# Convert to integer for comparison
_pct_int=$(printf '%.0f' "$_pct" 2>/dev/null) || exit 0

if [ "$_pct_int" -ge 95 ]; then
    printf '{"systemMessage":"⚠ Context nearly full (%s%%). Recommend /compact now to avoid auto-compaction."}\n' "$_pct_int"
elif [ "$_pct_int" -ge 80 ]; then
    printf '{"systemMessage":"⚠ Context usage at %s%%. Consider using /compact to free up space."}\n' "$_pct_int"
fi

exit 0
