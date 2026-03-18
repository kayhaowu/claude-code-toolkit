#!/bin/sh
# Uninstaller for claude-code-toolkit
# Usage: bash ~/.claude-code-toolkit/uninstall.sh [--yes]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Color output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1" >&2; }
success() { printf "${GREEN}[DONE]${NC}  %s\n" "$1"; }

# ── Step 1: Run sub-module uninstallers ───────────────────────────────────────
info "Removing installed modules..."

if [ -f "$SCRIPT_DIR/statusline/uninstall.sh" ]; then
    info "Running statusline uninstaller..."
    if ! sh "$SCRIPT_DIR/statusline/uninstall.sh"; then
        warn "Statusline uninstaller exited with errors. Check ~/.claude/settings.json manually."
    fi
fi

if [ -f "$SCRIPT_DIR/hooks/uninstall.sh" ]; then
    info "Running hooks uninstaller..."
    if ! sh "$SCRIPT_DIR/hooks/uninstall.sh"; then
        warn "Hooks uninstaller exited with errors. Check ~/.claude/settings.json manually."
    fi
fi

# ── Step 2: Remove toolkit directory ──────────────────────────────────────────
# Safety: verify SCRIPT_DIR looks like our install path
case "$SCRIPT_DIR" in
    */claude-code-toolkit|*/.claude-code-toolkit) ;;
    *)
        warn "SCRIPT_DIR ($SCRIPT_DIR) does not look like a toolkit directory. Skipping removal."
        exit 0
        ;;
esac

if [ -t 0 ]; then
    printf '\n'
    printf "Remove $SCRIPT_DIR? [Y/n] "
    read -r _answer
    case "$_answer" in
        [Nn]*) info "Kept $SCRIPT_DIR. You can remove it manually later."; exit 0 ;;
    esac
elif [ "$1" != "--yes" ]; then
    warn "Non-interactive mode: pass --yes to confirm removal of $SCRIPT_DIR"
    info "Modules were uninstalled. Directory kept."
    exit 0
fi

rm -rf "$SCRIPT_DIR"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "claude-code-toolkit fully uninstalled."
info "Restart Claude Code to apply changes."
