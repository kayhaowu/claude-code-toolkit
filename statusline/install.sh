#!/bin/sh
# One-click installer for Claude Code status line
# Supports: macOS, Debian/Ubuntu, CentOS/RHEL
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET_SCRIPT="$CLAUDE_DIR/statusline-command.sh"
TARGET_DASHBOARD="$CLAUDE_DIR/dashboard.sh"
TARGET_HEARTBEAT="$CLAUDE_DIR/heartbeat.sh"
TARGET_TMUX="$CLAUDE_DIR/tmux-sessions.sh"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
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

# ── Step 3: Create ~/.claude directories ─────────────────────────────────────
info "Creating $CLAUDE_DIR if needed..."
mkdir -p "$CLAUDE_DIR" "$SESSIONS_DIR"

# ── Step 4: Copy scripts ──────────────────────────────────────────────────────
info "Installing statusline-command.sh to $CLAUDE_DIR..."
cp "$SCRIPT_DIR/statusline-command.sh" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
success "Copied to $TARGET_SCRIPT"

info "Installing dashboard.sh to $CLAUDE_DIR..."
cp "$SCRIPT_DIR/dashboard.sh" "$TARGET_DASHBOARD"
chmod +x "$TARGET_DASHBOARD"
success "Copied to $TARGET_DASHBOARD"

info "Installing heartbeat.sh to $CLAUDE_DIR..."
cp "$SCRIPT_DIR/heartbeat.sh" "$TARGET_HEARTBEAT"
chmod +x "$TARGET_HEARTBEAT"
success "Copied to $TARGET_HEARTBEAT"

info "Installing tmux-sessions.sh to $CLAUDE_DIR..."
cp "$SCRIPT_DIR/tmux-sessions.sh" "$TARGET_TMUX"
chmod +x "$TARGET_TMUX"
success "Copied to $TARGET_TMUX"

# Create symlink so both statusline.sh and statusline-command.sh work.
# Claude Code may save settings.json with either filename; the symlink
# ensures the command resolves regardless of which name is configured.
ln -sf statusline-command.sh "$CLAUDE_DIR/statusline.sh"
info "Symlink: statusline.sh -> statusline-command.sh"

# ── Step 5: Merge settings.json ──────────────────────────────────────────────
STATUS_LINE_CONFIG='{"statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"}}'

if [ -f "$SETTINGS_FILE" ]; then
    info "Backing up existing settings.json to $SETTINGS_BACKUP..."
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"
    info "Merging statusLine into existing settings.json..."
    SETTINGS_TMP="${SETTINGS_FILE}.tmp"
    jq '. * {
        "statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"},
        "hooks": (.hooks // {} | . * {
            "SessionStart": [{"hooks":[{"type":"command","command":"nohup sh ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &"}]}],
            "SessionEnd": [{"hooks":[{"type":"command","command":"sh -c '\''kill $(cat ~/.claude/sessions/$PPID.hb.pid 2>/dev/null) 2>/dev/null; rm -f ~/.claude/sessions/$PPID.json ~/.claude/sessions/$PPID.hb.dat ~/.claude/sessions/$PPID.hb.pid'\''"}]}]
        })
    }' "$SETTINGS_BACKUP" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
    success "Settings merged. Original backed up to $SETTINGS_BACKUP"
else
    info "Creating $SETTINGS_FILE..."
    jq -n '{
        "statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"},
        "hooks":{
            "SessionStart":[{"hooks":[{"type":"command","command":"nohup sh ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &"}]}],
            "SessionEnd":[{"hooks":[{"type":"command","command":"sh -c '\''kill $(cat ~/.claude/sessions/$PPID.hb.pid 2>/dev/null) 2>/dev/null; rm -f ~/.claude/sessions/$PPID.json ~/.claude/sessions/$PPID.hb.dat ~/.claude/sessions/$PPID.hb.pid'\''"}]}]
        }
    }' > "$SETTINGS_FILE"
    success "Settings file created."
fi

# ── Step 6: Configure tmux (optional) ────────────────────────────────────────
if command -v tmux >/dev/null 2>&1 && [ -n "${TMUX:-}" ]; then
    info "tmux detected. Setting up real-time session monitor on status bar line 2..."
    tmux set-option -g status 2
    tmux set-option -g status-format[1] "#[align=left,fg=#bd93f9,bg=#282a36] Claude: #(sh ~/.claude/tmux-sessions.sh)"
    tmux set-option -g status-interval 2
    success "tmux session monitor enabled (updates every 2s)."
    info "To disable: tmux set-option -g status 1"
else
    info "tmux not detected or not inside a tmux session."
    info "To enable real-time session monitor, run inside tmux:"
    info "  tmux set-option -g status 2"
    info "  tmux set-option -g status-format[1] \"#[align=left,fg=#bd93f9,bg=#282a36] Claude: #(sh ~/.claude/tmux-sessions.sh)\""
    info "  tmux set-option -g status-interval 2"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "Installation complete!"
_installed_ver=$(sh "$TARGET_SCRIPT" --version 2>/dev/null || echo "unknown")
info "Version: $_installed_ver"
info "Restart Claude Code to activate the status line."
echo ""
info "Multi-instance dashboard: sh ~/.claude/dashboard.sh"
info "Real-time tmux monitor: automatic if inside tmux, or run commands above"
info "To customize colors, edit: $TARGET_SCRIPT"
info "To uninstall, see: $SCRIPT_DIR/README.md"
