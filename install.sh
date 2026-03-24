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

# ── Step 1c: Install Ghostty terminfo if needed ─────────────────────────────
if [ "${TERM:-}" = "xterm-ghostty" ] || [ -n "${GHOSTTY_RESOURCES_DIR:-}" ]; then
    if ! infocmp xterm-ghostty >/dev/null 2>&1; then
        info "Installing Ghostty terminfo..."
        _ghostty_tmpdir=$(mktemp -d)
        cat > "$_ghostty_tmpdir/ghostty.terminfo" << 'TERMINFO'
xterm-ghostty|ghostty terminal emulator,
    am, bce, ccc, km, mc5i, mir, msgr, npc, xenl,
    colors#0x100, cols#80, it#8, lines#24, pairs#0x7fff,
    acsc=``aaffggiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz{{||}}~~,
    bel=^G, bold=\E[1m, cbt=\E[Z, civis=\E[?25l,
    clear=\E[H\E[2J, cnorm=\E[?12l\E[?25h, cr=\r,
    csr=\E[%i%p1%d;%p2%dr, cub=\E[%p1%dD, cub1=^H,
    cud=\E[%p1%dB, cud1=\n, cuf=\E[%p1%dC, cuf1=\E[C,
    cup=\E[%i%p1%d;%p2%dH, cuu=\E[%p1%dA, cuu1=\E[A,
    cvvis=\E[?12;25h, dch=\E[%p1%dP, dch1=\E[P,
    dim=\E[2m, dl=\E[%p1%dM, dl1=\E[M, ech=\E[%p1%dX,
    ed=\E[J, el=\E[K, el1=\E[1K, flash=\E[?5h$<100/>\E[?5l,
    home=\E[H, hpa=\E[%i%p1%dG, ht=^I, hts=\EH,
    ich=\E[%p1%d@, il=\E[%p1%dL, il1=\E[L, ind=\n,
    indn=\E[%p1%dS,
    initc=\E]4;%p1%d;rgb\:%p2%{255}%*%{1000}%/%2.2X/%p3%{255}%*%{1000}%/%2.2X/%p4%{255}%*%{1000}%/%2.2X\E\\,
    invis=\E[8m, is2=\E[!p\E[?3;4l\E[4l\E>,
    kDC=\E[3;2~, kEND=\E[1;2F, kHOM=\E[1;2H,
    kIC=\E[2;2~, kLFT=\E[1;2D, kNXT=\E[6;2~,
    kPRV=\E[5;2~, kRIT=\E[1;2C, kbs=^?,
    kcbt=\E[Z, kcub1=\EOD, kcud1=\EOB,
    kcuf1=\EOC, kcuu1=\EOA, kdch1=\E[3~,
    kend=\EOF, kf1=\EOP, kf10=\E[21~,
    kf11=\E[23~, kf12=\E[24~, kf2=\EOQ,
    kf3=\EOR, kf4=\EOS, kf5=\E[15~,
    kf6=\E[17~, kf7=\E[18~, kf8=\E[19~,
    kf9=\E[20~, khome=\EOH, kich1=\E[2~,
    kmous=\E[<, knp=\E[6~, kpp=\E[5~,
    mc0=\E[i, mc4=\E[4i, mc5=\E[5i, meml=\El, memu=\Em,
    nel=\EE, oc=\E]104\E\\, op=\E[39;49m,
    rc=\E8, rep=%p1%c\E[%p2%{1}%-%db,
    rev=\E[7m, ri=\EM, rin=\E[%p1%dT, ritm=\E[23m,
    rmacs=\E(B, rmam=\E[?7l, rmcup=\E[?1049l\E[23;0;0t,
    rmir=\E[4l, rmkx=\E[?1l\E>, rmso=\E[27m,
    rmul=\E[24m, rs1=\Ec\E]104\E\\,
    sc=\E7, setab=\E[%?%p1%{8}%<%t4%p1%d%e48;5;%p1%d%;m,
    setaf=\E[%?%p1%{8}%<%t3%p1%d%e38;5;%p1%d%;m,
    setb=\E[4%p1%dm, setf=\E[3%p1%dm,
    sgr=\E[0%?%p1%p6%|%t;1%;%?%p2%t;4%;%?%p3%t;7%;%?%p4%t;5%;%?%p5%t;2%;%?%p7%t;8%;%?%p9%t;3%;m%?%p9%t\E(0%e\E(B%;,
    sgr0=\E(B\E[m, sitm=\E[3m, smacs=\E(0,
    smam=\E[?7h, smcup=\E[?1049h\E[22;0;0t,
    smir=\E[4h, smkx=\E[?1h\E=, smso=\E[7m,
    smul=\E[4m, tbc=\E[3g, u6=\E[%i%d;%dR,
    u7=\E[6n, u8=\E[?%[;0123456789]c, u9=\E[c,
    vpa=\E[%i%p1%dd,
TERMINFO
        tic -x "$_ghostty_tmpdir/ghostty.terminfo" 2>/dev/null && \
            success "Ghostty terminfo installed." || \
            warn "Ghostty terminfo install failed (non-critical, run: TERM=xterm-256color tmux)"
        rm -rf "$_ghostty_tmpdir"
    else
        info "Ghostty terminfo already installed."
    fi
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
