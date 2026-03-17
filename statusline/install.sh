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

# ── Quick relink mode ─────────────────────────────────────────────────────────
# Usage: bash statusline/install.sh --relink
# Repairs broken symlinks after moving the toolkit folder.
if [ "$1" = "--relink" ]; then
    info "Relinking statusline scripts to $SCRIPT_DIR..."
    _fixed=0
    _ok=0
    for script in statusline-command.sh dashboard.sh heartbeat.sh \
                  tmux-sessions.sh status-hook.sh configure.sh; do
        _target="$CLAUDE_DIR/$script"
        if [ -L "$_target" ]; then
            if [ -e "$_target" ]; then
                _ok=$((_ok + 1))
            else
                ln -sf "$SCRIPT_DIR/$script" "$_target"
                _fixed=$((_fixed + 1))
            fi
        fi
    done
    # Also fix the statusline.sh alias
    _alias="$CLAUDE_DIR/statusline.sh"
    if [ -L "$_alias" ]; then
        if [ -e "$_alias" ]; then
            _ok=$((_ok + 1))
        else
            ln -sf "$SCRIPT_DIR/statusline-command.sh" "$_alias"
            _fixed=$((_fixed + 1))
        fi
    fi
    if [ "$_fixed" -gt 0 ]; then
        success "Fixed $_fixed broken symlink(s). $_ok already OK."
    elif [ "$_ok" -gt 0 ]; then
        info "All $_ok symlink(s) already point to correct location."
    else
        warn "No symlinks found. Run a full install first: bash $SCRIPT_DIR/install.sh"
        exit 1
    fi
    exit 0
fi

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
# If a regular file exists (from a previous copy-based install), back it up
# and replace with a symlink.
info "Creating symlinks in $CLAUDE_DIR..."

for _script in statusline-command.sh dashboard.sh heartbeat.sh tmux-sessions.sh status-hook.sh configure.sh; do
    _target="$CLAUDE_DIR/$_script"
    if [ -e "$_target" ] && [ ! -L "$_target" ]; then
        mv "$_target" "$_target.bak"
        warn "Backed up existing file: $_target -> $_target.bak"
    fi
    ln -sf "$SCRIPT_DIR/$_script" "$_target"
    success "Linked: $_target -> $SCRIPT_DIR/$_script"
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

# ── Step 6: Configure tmux ──────────────────────────────────────────────────
# Detect if repo contains tmux/tmux.conf for full tmux environment setup
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_TMUX_CONF="$REPO_DIR/tmux/tmux.conf"

if [ -f "$REPO_TMUX_CONF" ] && command -v tmux >/dev/null 2>&1; then
    info "Found tmux.conf in repo: $REPO_TMUX_CONF"

    # Compare existing tmux.conf with repo version
    _tmux_installed="$HOME/.config/tmux/tmux.conf"
    if [ -f "$_tmux_installed" ]; then
        if diff -q "$_tmux_installed" "$REPO_TMUX_CONF" >/dev/null 2>&1; then
            info "tmux.conf is already up-to-date. Skipping tmux setup."
            _tmux_answer="skip"
        else
            warn "tmux.conf differs from repo version."
            info "Run 'diff ~/.config/tmux/tmux.conf $REPO_TMUX_CONF' to see changes."
            printf '  Overwrite with repo version? (existing will be backed up) [Y/n] '
            read -r _tmux_answer
            case "$_tmux_answer" in
                [Nn]*) _tmux_answer="skip"; info "Kept existing tmux.conf." ;;
                *)     _tmux_answer="install" ;;
            esac
        fi
    else
        printf '  Install full tmux environment (tmux.conf + TPM + plugins)? [Y/n] '
        read -r _tmux_answer
        case "$_tmux_answer" in
            [Nn]*) _tmux_answer="skip" ;;
            *)     _tmux_answer="install" ;;
        esac
    fi

    case "$_tmux_answer" in
        skip) info "Skipped tmux environment setup." ;;
        install)
            # 6a. Deploy tmux.conf
            mkdir -p "$HOME/.config/tmux"
            if [ -f "$HOME/.config/tmux/tmux.conf" ]; then
                _backup="$HOME/.config/tmux/tmux.conf.bak.$(date +%Y%m%d_%H%M%S)"
                cp "$HOME/.config/tmux/tmux.conf" "$_backup"
                warn "Existing tmux.conf backed up to $_backup"
            fi
            cp "$REPO_TMUX_CONF" "$HOME/.config/tmux/tmux.conf"
            success "tmux.conf deployed to ~/.config/tmux/tmux.conf"

            # 6b. Symlink ~/.tmux -> ~/.config/tmux (for TPM compatibility)
            if [ -L "$HOME/.tmux" ]; then
                rm "$HOME/.tmux"
            elif [ -d "$HOME/.tmux" ]; then
                if [ -d "$HOME/.tmux/plugins/tpm" ]; then
                    warn "Backing up existing ~/.tmux ..."
                    mv "$HOME/.tmux" "$HOME/.tmux.bak.$(date +%Y%m%d_%H%M%S)"
                else
                    rm -rf "$HOME/.tmux"
                fi
            fi
            ln -sf "$HOME/.config/tmux" "$HOME/.tmux"
            success "symlink: ~/.tmux -> ~/.config/tmux"

            # 6c. Install TPM
            TPM_DIR="$HOME/.config/tmux/plugins/tpm"
            if [ ! -d "$TPM_DIR" ]; then
                info "Installing TPM (Tmux Plugin Manager) ..."
                git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
                success "TPM installed"
            else
                info "TPM already installed."
            fi

            # 6d. Install plugins
            info "Installing tmux plugins ..."
            "$TPM_DIR/bin/install_plugins"

            # 6e. Fix catppuccin/dracula repo name collision
            CATPPUCCIN_DIR="$HOME/.config/tmux/plugins/tmux"
            if [ -f "$CATPPUCCIN_DIR/dracula.tmux" ]; then
                warn "Detected Dracula instead of Catppuccin, fixing ..."
                rm -rf "$CATPPUCCIN_DIR"
                git clone https://github.com/catppuccin/tmux.git "$CATPPUCCIN_DIR"
            fi
            success "tmux plugins installed"

            # 6f. Set up Claude monitor in live tmux session
            if [ -n "${TMUX:-}" ]; then
                tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
                success "tmux config reloaded in current session."
            else
                info "Not inside tmux. Start tmux to see the new config."
            fi
            ;;
    esac
elif command -v tmux >/dev/null 2>&1 && [ -n "${TMUX:-}" ]; then
    # Fallback: no repo tmux.conf, but inside tmux — set minimal Claude monitor
    _has_tmux_conf_monitor=$(tmux show -g status-format[1] 2>/dev/null | grep -c "tmux-sessions.sh" || echo "0")
    if [ "$_has_tmux_conf_monitor" -gt 0 ]; then
        info "Claude monitor already configured in tmux.conf. Skipping."
    else
        _tmux_theme=$(tmux show -gv @catppuccin_flavor 2>/dev/null || echo "")
        if [ -n "$_tmux_theme" ]; then
            info "Catppuccin theme detected ($_tmux_theme). Using themed colors..."
            tmux set-option -g status 2
            tmux set-option -g status-format[1] "#[align=left,fg=#{@thm_mauve},bg=#{@thm_crust}] Claude: #(sh ~/.claude/tmux-sessions.sh)"
        else
            info "Setting up Claude monitor on tmux status bar..."
            tmux set-option -g status 2
            tmux set-option -g status-format[1] "#[align=left,fg=#bd93f9,bg=#282a36] Claude: #(sh ~/.claude/tmux-sessions.sh)"
        fi
        tmux set-option -g status-interval 2
        success "tmux session monitor enabled."
    fi
else
    info "tmux not detected or not inside a tmux session."
    info "To enable tmux monitor, start tmux and re-run this script."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "Installation complete!"
_installed_ver=$(sh "$TARGET_SCRIPT" --version 2>/dev/null || echo "unknown")
info "Version: $_installed_ver"
info "Restart Claude Code to activate the status line."
echo ""
info "Configure widgets: bash ~/.claude/configure.sh"
info "Multi-instance dashboard: sh ~/.claude/dashboard.sh"
info "Real-time tmux monitor: automatic if inside tmux, or run commands above"
info "To uninstall, see: $SCRIPT_DIR/README.md"
