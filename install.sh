#!/bin/sh
# One-line installer for claude-code-toolkit
# Usage: curl -fsSL https://raw.githubusercontent.com/kayhaowu/claude-code-toolkit/main/install.sh | bash
set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.claude-code-toolkit}"
REPO_URL="https://github.com/kayhaowu/claude-code-toolkit.git"

# ── Color output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1" >&2; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; exit 1; }
success() { printf "${GREEN}[DONE]${NC}  %s\n" "$1"; }

# ── Error trap ────────────────────────────────────────────────────────────────
_fresh_install=false
cleanup() {
    if [ $? -ne 0 ]; then
        echo ""
        warn "Installation failed. Check the error above and try again."
        if [ "$_fresh_install" = true ] && [ -d "$INSTALL_DIR" ]; then
            warn "Cleaning up partial installation..."
            rm -rf "$INSTALL_DIR"
        fi
    fi
}
trap cleanup EXIT

# ── Step 1: Check dependencies ────────────────────────────────────────────────
info "Checking dependencies..."
if ! command -v git >/dev/null 2>&1; then
    error "git is required but not installed. Install it first:
  macOS:  brew install git
  Ubuntu: sudo apt install git
  RHEL:   sudo yum install git"
fi

if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found. Module installers will handle this, but you can install it now:
  macOS:  brew install jq
  Ubuntu: sudo apt install jq
  RHEL:   sudo yum install jq"
fi

# ── Step 1b: Check and install tmux ───────────────────────────────────────────
SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

if ! command -v tmux >/dev/null 2>&1; then
    info "tmux not found. Installing..."
    if [ "$(uname)" = "Darwin" ]; then
        if command -v brew >/dev/null 2>&1; then
            brew install tmux
        else
            error "tmux is required. Install Homebrew first (https://brew.sh), then: brew install tmux"
        fi
    elif [ -f /etc/debian_version ]; then
        $SUDO apt-get update -qq && $SUDO apt-get install -y tmux
    elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
        $SUDO yum install -y tmux
    else
        error "tmux is required but could not be installed automatically. Install it manually and re-run."
    fi
    if ! command -v tmux >/dev/null 2>&1; then
        error "tmux installation failed. Install it manually and re-run."
    fi
    success "tmux installed: $(tmux -V)"
else
    info "tmux already installed: $(tmux -V)"
fi

# ── Step 2: Clone or update ───────────────────────────────────────────────────
if [ -d "$INSTALL_DIR" ]; then
    # Exists — check if valid git repo
    if ! git -C "$INSTALL_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        error "$INSTALL_DIR exists but is not a git repository.
Remove it manually and re-run:  rm -rf $INSTALL_DIR"
    fi

    info "Existing installation found. Updating..."
    if ! git -C "$INSTALL_DIR" pull origin main; then
        error "git pull failed. See the error above for details.
Common fixes:
  Local changes:  cd $INSTALL_DIR && git stash && git pull origin main
  Network issue:  check your connection and retry"
    fi
    success "Updated to latest version."
else
    info "Installing claude-code-toolkit..."
    _fresh_install=true
    git clone --depth 1 --single-branch "$REPO_URL" "$INSTALL_DIR"
    success "Cloned to $INSTALL_DIR"
fi

# ── Step 3: Setup tmux environment (TPM + plugins + tmux.conf) ────────────────
TMUX_CONF="$INSTALL_DIR/tmux/tmux.conf"
TMUX_CONF_DIR="$HOME/.config/tmux"
TPM_DIR="$TMUX_CONF_DIR/plugins/tpm"

if [ -f "$TMUX_CONF" ]; then
    # Deploy tmux.conf
    mkdir -p "$TMUX_CONF_DIR"
    if [ -f "$TMUX_CONF_DIR/tmux.conf" ]; then
        if diff -q "$TMUX_CONF_DIR/tmux.conf" "$TMUX_CONF" >/dev/null 2>&1; then
            info "tmux.conf is already up-to-date."
        else
            _backup="$TMUX_CONF_DIR/tmux.conf.bak.$(date +%Y%m%d_%H%M%S)"
            cp "$TMUX_CONF_DIR/tmux.conf" "$_backup"
            warn "Existing tmux.conf backed up to $_backup"
            cp "$TMUX_CONF" "$TMUX_CONF_DIR/tmux.conf"
            success "tmux.conf updated."
        fi
    else
        cp "$TMUX_CONF" "$TMUX_CONF_DIR/tmux.conf"
        success "tmux.conf deployed to $TMUX_CONF_DIR/tmux.conf"
    fi

    # Symlink ~/.tmux -> ~/.config/tmux (for TPM compatibility)
    if [ -L "$HOME/.tmux" ]; then
        rm "$HOME/.tmux"
    elif [ -d "$HOME/.tmux" ] && [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        rm -rf "$HOME/.tmux"
    fi
    ln -sf "$TMUX_CONF_DIR" "$HOME/.tmux"

    # Install TPM
    if [ ! -d "$TPM_DIR" ]; then
        info "Installing TPM (Tmux Plugin Manager)..."
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
        success "TPM installed."
    else
        info "TPM already installed."
    fi

    # Install plugins
    if [ -x "$TPM_DIR/bin/install_plugins" ]; then
        info "Installing tmux plugins..."
        "$TPM_DIR/bin/install_plugins" || warn "Plugin install had issues (continuing)"
        # Fix catppuccin/dracula repo name collision
        CATPPUCCIN_DIR="$TMUX_CONF_DIR/plugins/tmux"
        if [ -f "$CATPPUCCIN_DIR/dracula.tmux" ]; then
            warn "Detected Dracula instead of Catppuccin, fixing..."
            rm -rf "$CATPPUCCIN_DIR"
            git clone --depth 1 https://github.com/catppuccin/tmux.git "$CATPPUCCIN_DIR"
        fi
        success "tmux plugins installed."
    fi
fi

# ── Step 4: Print next steps ──────────────────────────────────────────────────
echo ""
success "claude-code-toolkit is ready!"
echo ""
info "Available modules:"
echo "  bash $INSTALL_DIR/statusline/install.sh   — Status line + tmux integration"
echo "  bash $INSTALL_DIR/hooks/install.sh         — Safety hooks collection"
echo ""
info "Update:     cd $INSTALL_DIR && git pull"
info "Uninstall:  bash $INSTALL_DIR/uninstall.sh"
