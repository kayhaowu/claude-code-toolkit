#!/bin/sh
# Uninstaller for claude-code-toolkit
# Usage: bash ~/.claude-code-toolkit/uninstall.sh
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
    sh "$SCRIPT_DIR/statusline/uninstall.sh" || warn "Statusline uninstall had warnings (continuing)"
fi

if [ -f "$SCRIPT_DIR/hooks/uninstall.sh" ]; then
    info "Running hooks uninstaller..."
    sh "$SCRIPT_DIR/hooks/uninstall.sh" || warn "Hooks uninstall had warnings (continuing)"
fi

# ── Step 2: Remove toolkit directory ──────────────────────────────────────────
if [ -t 0 ]; then
    printf '\n'
    printf "Remove $SCRIPT_DIR? [Y/n] "
    read -r _answer
    case "$_answer" in
        [Nn]*) info "Kept $SCRIPT_DIR. You can remove it manually later."; exit 0 ;;
    esac
fi

rm -rf "$SCRIPT_DIR"
success "Removed $SCRIPT_DIR"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "claude-code-toolkit fully uninstalled."
info "Restart Claude Code to apply changes."
