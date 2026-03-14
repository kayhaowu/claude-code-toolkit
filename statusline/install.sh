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
TARGET_STATUS_HOOK="$CLAUDE_DIR/status-hook.sh"
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

# ── Step 4: Create symlinks ──────────────────────────────────────────────────
# Use symbolic links so that `git pull` automatically updates installed scripts.
# Skip files that already exist and are NOT our symlinks (user's own scripts).
info "Creating symlinks in $CLAUDE_DIR..."

for _script in statusline-command.sh dashboard.sh heartbeat.sh tmux-sessions.sh status-hook.sh; do
    _target="$CLAUDE_DIR/$_script"
    if [ -e "$_target" ] && [ ! -L "$_target" ]; then
        warn "Skipped: $_target already exists (not a symlink). Backup and re-run to overwrite."
    else
        ln -sf "$SCRIPT_DIR/$_script" "$_target"
        success "Linked: $_target -> $SCRIPT_DIR/$_script"
    fi
done

# Create alias symlink so both statusline.sh and statusline-command.sh work.
# Claude Code may save settings.json with either filename; the symlink
# ensures the command resolves regardless of which name is configured.
ln -sf "$SCRIPT_DIR/statusline-command.sh" "$CLAUDE_DIR/statusline.sh"
info "Linked: statusline.sh -> statusline-command.sh"

# ── Step 5: Merge settings.json ──────────────────────────────────────────────
STATUSLINE_CONFIG='{"type":"command","command":"sh ~/.claude/statusline-command.sh"}'
HB_START_CMD='nohup bash ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &'
HB_STOP_CMD="sh -c 'kill \$(cat ~/.claude/sessions/\$PPID.hb.pid 2>/dev/null) 2>/dev/null; rm -f ~/.claude/sessions/\$PPID.json ~/.claude/sessions/\$PPID.hb.dat ~/.claude/sessions/\$PPID.hb.pid ~/.claude/sessions/\$PPID.status'"
HOOK_WORKING_CMD='sh ~/.claude/status-hook.sh $PPID working'
HOOK_IDLE_CMD='sh ~/.claude/status-hook.sh $PPID idle'

if [ -f "$SETTINGS_FILE" ]; then
    info "Backing up existing settings.json to $SETTINGS_BACKUP..."
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"
    info "Merging statusLine into existing settings.json..."
else
    info "Creating $SETTINGS_FILE..."
    echo '{}' > "$SETTINGS_FILE"
fi

# Merge statusLine + append hooks in a single jq pass (atomic, no TOCTOU)
SETTINGS_TMP="${SETTINGS_FILE}.tmp"
jq --argjson sl "$STATUSLINE_CONFIG" \
   --arg start_cmd "$HB_START_CMD" \
   --arg stop_cmd "$HB_STOP_CMD" \
   --arg hook_working "$HOOK_WORKING_CMD" \
   --arg hook_idle "$HOOK_IDLE_CMD" '
    .statusLine = $sl
    | if ([(.hooks.SessionStart // [])[] | .hooks[]? | .command // ""] | any(test("heartbeat\\.sh"))) then .
      else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$start_cmd}]}])
      end
    # SessionEnd: always replace our hook (remove old, add current) to pick up new cleanup targets
    | .hooks.SessionEnd = [(.hooks.SessionEnd // [])[] | select((.hooks // []) | all(.command // "" | test("sessions/\\$PPID") | not))]
    | .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"hooks":[{"type":"command","command":$stop_cmd}]}])
    | if ([(.hooks.UserPromptSubmit // [])[] | .hooks[]? | .command // ""] | any(test("status-hook\\.sh"))) then .
      else .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"hooks":[{"type":"command","command":$hook_working}]}])
      end
    | if ([(.hooks.PostToolUse // [])[] | .hooks[]? | .command // ""] | any(test("status-hook\\.sh"))) then .
      else .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{"hooks":[{"type":"command","command":$hook_working}]}])
      end
    | if ([(.hooks.Stop // [])[] | .hooks[]? | .command // ""] | any(test("status-hook\\.sh"))) then .
      else .hooks.Stop = ((.hooks.Stop // []) + [{"hooks":[{"type":"command","command":$hook_idle}]}])
      end
' "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
info "Settings updated (statusLine + hooks)."

if [ -f "$SETTINGS_BACKUP" ]; then
    success "Settings merged. Original backed up to $SETTINGS_BACKUP"
else
    success "Settings file created."
fi

# ── Step 6: Configure tmux (optional) ────────────────────────────────────────
if command -v tmux >/dev/null 2>&1 && [ -n "${TMUX:-}" ]; then
    # Check if tmux.conf already manages the Claude monitor.
    # Note: on first install before tmux.conf is sourced, this returns 0
    # and install.sh sets its own status-format[1]. When tmux.conf is later
    # sourced, if-shell overwrites it — the final state is correct either way.
    _has_tmux_conf_monitor=$(tmux show -g status-format[1] 2>/dev/null | grep -c "tmux-sessions.sh" || echo "0")

    if [ "$_has_tmux_conf_monitor" -gt 0 ]; then
        info "Claude monitor already configured in tmux.conf. Skipping tmux setup."
    else
        # Detect catppuccin theme
        _tmux_theme=$(tmux show -gv @catppuccin_flavor 2>/dev/null || echo "")

        if [ -n "$_tmux_theme" ]; then
            info "Catppuccin theme detected ($_tmux_theme). Using themed colors..."
            tmux set-option -g status 2
            tmux set-option -g status-format[1] "#[align=left,fg=#{@thm_mauve},bg=#{@thm_crust}] Claude: #(sh ~/.claude/tmux-sessions.sh)"
        else
            info "tmux detected. Setting up real-time session monitor on status bar line 2..."
            tmux set-option -g status 2
            tmux set-option -g status-format[1] "#[align=left,fg=#bd93f9,bg=#282a36] Claude: #(sh ~/.claude/tmux-sessions.sh)"
        fi
        tmux set-option -g status-interval 2
        success "tmux session monitor enabled (updates every 2s)."
        info "To disable: tmux set-option -g status 1"
    fi
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
