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
cleanup() {
    if [ $? -ne 0 ]; then
        echo ""
        warn "Installation failed. Check the error above and try again."
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

# ── Step 2: Clone or update ───────────────────────────────────────────────────
if [ -d "$INSTALL_DIR" ]; then
    # Exists — check if valid git repo
    if ! git -C "$INSTALL_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        error "$INSTALL_DIR exists but is not a git repository.
Remove it manually and re-run:  rm -rf $INSTALL_DIR"
    fi

    info "Existing installation found. Updating..."
    if ! git -C "$INSTALL_DIR" pull origin main 2>&1; then
        error "git pull failed. You may have local changes.
Fix manually:  cd $INSTALL_DIR && git stash && git pull origin main"
    fi
    success "Updated to latest version."
else
    info "Installing claude-code-toolkit..."
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    success "Cloned to $INSTALL_DIR"
fi

# ── Step 3: Print next steps ──────────────────────────────────────────────────
echo ""
success "claude-code-toolkit is ready!"
echo ""
info "Available modules:"
echo "  bash $INSTALL_DIR/statusline/install.sh   — Status line + tmux integration"
echo "  bash $INSTALL_DIR/hooks/install.sh         — Safety hooks collection"
echo ""
info "Update:     cd $INSTALL_DIR && git pull"
info "Uninstall:  bash $INSTALL_DIR/uninstall.sh"
