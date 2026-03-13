#!/bin/sh
# Uninstaller for Claude Code hooks collection
# Usage: bash hooks/uninstall.sh
set -e

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# ── Color output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
removed() { printf "${GREEN}[REMOVED]${NC}  %s\n" "$1"; }
skipped() { printf "${YELLOW}[SKIPPED]${NC}  %s\n" "$1"; }

# ── Step 1: Clean settings.json ──────────────────────────────────────────────
if [ -f "$SETTINGS_FILE" ]; then
    info "Cleaning hooks from settings.json..."
    SETTINGS_TMP="${SETTINGS_FILE}.tmp"

    # Remove all entries with commands matching "hooks/" path
    # Does NOT touch statusline hooks (status-hook.sh, heartbeat.sh, etc.)
    jq '
        .hooks.PreToolUse       |= [(.// [])[] | select((.hooks // []) | all(.command // "" | test("hooks/") | not))]
        | .hooks.PostToolUse    |= [(.// [])[] | select((.hooks // []) | all(.command // "" | test("hooks/") | not))]
        | .hooks.Stop           |= [(.// [])[] | select((.hooks // []) | all(.command // "" | test("hooks/") | not))]
        | .hooks.SessionStart   |= [(.// [])[] | select((.hooks // []) | all(.command // "" | test("hooks/") | not))]
        | .hooks.SessionEnd     |= [(.// [])[] | select((.hooks // []) | all(.command // "" | test("hooks/") | not))]
        | if (.hooks.PreToolUse     // [] | length) == 0 then del(.hooks.PreToolUse)     else . end
        | if (.hooks.PostToolUse    // [] | length) == 0 then del(.hooks.PostToolUse)    else . end
        | if (.hooks.Stop           // [] | length) == 0 then del(.hooks.Stop)           else . end
        | if (.hooks.SessionStart   // [] | length) == 0 then del(.hooks.SessionStart)   else . end
        | if (.hooks.SessionEnd     // [] | length) == 0 then del(.hooks.SessionEnd)     else . end
        | if (.hooks // {} | length) == 0                then del(.hooks)                else . end
    ' "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
    removed "Hook entries from settings.json"
else
    skipped "settings.json (not found)"
fi

# ── Step 2: Delete hooks directory ───────────────────────────────────────────
if [ -d "$HOOKS_DIR" ]; then
    rm -rf "$HOOKS_DIR"
    removed "$HOOKS_DIR"
else
    skipped "$HOOKS_DIR (not found)"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
info "Uninstall complete. Statusline hooks are untouched."
info "Restart Claude Code to apply changes."
