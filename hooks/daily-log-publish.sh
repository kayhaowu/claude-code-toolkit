#!/bin/sh
# Cron script: consolidate daily draft, optionally summarize with LLM, store log
#
# Add to crontab:  0 0 * * * sh ~/.claude/hooks/daily-log-publish.sh
#
# Configure in ~/.claude/.env:
#   DAILY_LOG_MODE      "local" (default) or "git"
#   DAILY_LOG_DIR       Directory to store logs in local mode (default: ~/.claude/logs)
#   DAILY_LOG_GIT_REPO  Git repo path in git mode — logs stored in <repo>/logs/
#   DAILY_LOG_LLM_URL   OpenAI-compatible API endpoint (optional — skip AI if unset)
#   DAILY_LOG_LLM_KEY   API key (optional)
#   DAILY_LOG_LLM_MODEL Model name (optional, default: gpt-4o-mini)

[ -f "$HOME/.claude/.env" ] && . "$HOME/.claude/.env"

DRAFT="$HOME/.claude/daily-draft.md"
MODE="${DAILY_LOG_MODE:-local}"

# Cross-platform yesterday
if date -d yesterday '+%Y-%m-%d' >/dev/null 2>&1; then
    DATE=$(date -d yesterday '+%Y-%m-%d')
else
    DATE=$(date -v-1d '+%Y-%m-%d')
fi

# Determine log file path
if [ "$MODE" = "git" ]; then
    [ -z "$DAILY_LOG_GIT_REPO" ] && echo "DAILY_LOG_GIT_REPO not set" && exit 1
    LOG_FILE="$DAILY_LOG_GIT_REPO/logs/${DATE}.md"
else
    LOG_DIR="${DAILY_LOG_DIR:-$HOME/.claude/logs}"
    LOG_FILE="${LOG_DIR}/${DATE}.md"
fi

# No draft, nothing to do
[ ! -f "$DRAFT" ] || [ ! -s "$DRAFT" ] && exit 0

DRAFT_CONTENT=$(cat "$DRAFT")
EXISTING=""
[ -f "$LOG_FILE" ] && EXISTING=$(cat "$LOG_FILE")

if [ -n "$DAILY_LOG_LLM_URL" ]; then
    MODEL="${DAILY_LOG_LLM_MODEL:-gpt-4o-mini}"

    if [ -n "$EXISTING" ]; then
        USER_CONTENT="Here is today's existing log:

${EXISTING}

Here are new session summaries to merge in:

${DRAFT_CONTENT}

Merge them into one complete log, preserving existing details and integrating new content naturally."
    else
        USER_CONTENT="$DRAFT_CONTENT"
    fi

    PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg system "You are a technical work log assistant. Summarize into concise bullet points, remove duplicates, keep a natural tone. Do not add a date header, just write the content." \
        --arg user "$USER_CONTENT" \
        '{model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $user}]}')

    RESPONSE=$(curl -s "$DAILY_LOG_LLM_URL/chat/completions" \
        -H "Authorization: Bearer ${DAILY_LOG_LLM_KEY:-}" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    LOG_CONTENT=$(printf '%s' "$RESPONSE" | jq -r '.choices[0].message.content // ""')
    [ -z "$LOG_CONTENT" ] && echo "LLM returned empty response" && exit 1
else
    if [ -n "$EXISTING" ]; then
        LOG_CONTENT="${EXISTING}

${DRAFT_CONTENT}"
    else
        LOG_CONTENT="$DRAFT_CONTENT"
    fi
fi

# Write log file
if [ "$MODE" = "git" ]; then
    mkdir -p "$DAILY_LOG_GIT_REPO/logs"
else
    mkdir -p "$LOG_DIR"
fi

printf '# %s\n\n%s\n' "$DATE" "$LOG_CONTENT" > "$LOG_FILE"

# Git mode: commit and push
if [ "$MODE" = "git" ]; then
    cd "$DAILY_LOG_GIT_REPO" && \
        git add "logs/${DATE}.md" && \
        git commit -m "Add ${DATE} work log" && \
        git push
fi

rm -f "$DRAFT"
