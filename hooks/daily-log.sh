#!/bin/sh
# Claude Code hook: Append session summary to daily draft
# Event: Stop
# Accumulates session summaries in ~/.claude/daily-draft.md throughout the day.
# Run daily-log-publish.sh via cron to consolidate and store the log.

INPUT=$(cat)
DRAFT="$HOME/.claude/daily-draft.md"
NOW=$(date '+%H:%M')

SUMMARY=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' | cut -c1-300)
[ -z "$SUMMARY" ] && exit 0

cat >> "$DRAFT" << EOF

## Session @ ${NOW}
${SUMMARY}
EOF

exit 0
