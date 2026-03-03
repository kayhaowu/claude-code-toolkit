#!/bin/sh
# One-click installer for Claude Code status line
# Supports: macOS, Debian/Ubuntu, CentOS/RHEL
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET_SCRIPT="$CLAUDE_DIR/statusline-command.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SETTINGS_BACKUP="$CLAUDE_DIR/settings.json.backup"

# ── Color output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1" >&2; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; exit 1; }
success() { printf "${GREEN}[DONE]${NC}  %s\n" "$1"; }

# ── Step 1: Detect OS ─────────────────────────────────────────────────────────
info "Detecting operating system..."
OS=""
if [ "$(uname)" = "Darwin" ]; then
    OS="macos"
elif [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
    OS="rhel"
else
    warn "Unrecognized OS. Please install 'jq' manually and re-run this script."
    error "Unsupported OS"
fi
info "Detected: $OS"

# ── Step 2: Ensure jq is installed ───────────────────────────────────────────
info "Checking for jq..."
if ! command -v jq >/dev/null 2>&1; then
    info "jq not found. Installing..."
    case "$OS" in
        macos)
            if ! command -v brew >/dev/null 2>&1; then
                error "Homebrew not found. Please install Homebrew first: https://brew.sh"
            fi
            brew install jq
            ;;
        debian)
            sudo apt-get update -qq && sudo apt-get install -y jq
            ;;
        rhel)
            sudo yum install -y jq
            ;;
    esac
    success "jq installed."
else
    info "jq already installed: $(jq --version)"
fi

# ── Step 3: Create ~/.claude directory ───────────────────────────────────────
info "Creating $CLAUDE_DIR if needed..."
mkdir -p "$CLAUDE_DIR"

# ── Step 4: Copy statusline-command.sh ───────────────────────────────────────
info "Installing statusline-command.sh to $CLAUDE_DIR..."
cp "$SCRIPT_DIR/statusline-command.sh" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
success "Copied to $TARGET_SCRIPT"

# ── Step 5: Merge settings.json ──────────────────────────────────────────────
STATUS_LINE_CONFIG='{"statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"}}'

if [ -f "$SETTINGS_FILE" ]; then
    info "Backing up existing settings.json to $SETTINGS_BACKUP..."
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"
    info "Merging statusLine into existing settings.json..."
    SETTINGS_TMP="${SETTINGS_FILE}.tmp"
    jq '. * {"statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"}}' \
        "$SETTINGS_BACKUP" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
    success "Settings merged. Original backed up to $SETTINGS_BACKUP"
else
    info "Creating $SETTINGS_FILE..."
    printf '%s\n' "$STATUS_LINE_CONFIG" | jq '.' > "$SETTINGS_FILE"
    success "Settings file created."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "Installation complete!"
info "Restart Claude Code to activate the status line."
echo ""
info "To customize colors, edit: $TARGET_SCRIPT"
info "To uninstall, see: $SCRIPT_DIR/README.md"
