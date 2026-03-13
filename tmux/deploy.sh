#!/usr/bin/env bash

################################################################################
# deploy.sh
# One-click tmux environment deployment to remote Linux hosts
# Usage: ./deploy.sh user@host [ssh-options]
# Examples: ./deploy.sh root@192.168.1.100
#           ./deploy.sh user@host -p 2222
################################################################################

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    echo "tmux environment remote deployment script"
    echo ""
    echo "Usage: $0 user@host [ssh-options]"
    echo ""
    echo "Examples:"
    echo "  $0 root@192.168.1.100"
    echo "  $0 user@host -p 2222"
    echo "  $0 sonic@10.0.0.1 -i ~/.ssh/id_rsa"
    echo ""
    echo "Deploys:"
    echo "  - Installs tmux, git (if not installed)"
    echo "  - Copies tmux.conf to remote ~/.config/tmux/"
    echo "  - Installs TPM and all plugins (Catppuccin, tmux-cpu, tmux-battery, etc.)"
    echo "  - Optionally installs Claude Code statusline"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help"
    exit 0
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

if [[ -z "$1" ]]; then
    error "Usage: $0 user@host [ssh-options]"
    echo "Use $0 -h for help"
    exit 1
fi

REMOTE_HOST="$1"
shift
SSH_OPTS=("$@")

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMUX_CONF="$SCRIPT_DIR/tmux.conf"

if [[ ! -f "$TMUX_CONF" ]]; then
    error "tmux.conf not found: $TMUX_CONF"
    exit 1
fi

info "Deploying tmux environment to $REMOTE_HOST ..."

# 1. Copy tmux.conf to remote
info "Copying tmux.conf ..."
scp "${SSH_OPTS[@]}" "$TMUX_CONF" "$REMOTE_HOST:/tmp/tmux.conf.deploy"

# 2. Run remote installation
ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" 'bash -s' << 'REMOTE_SCRIPT'
set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Package manager detection
install_pkg() {
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq "$@"
    elif command -v yum &>/dev/null; then
        sudo yum install -y "$@"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "$@"
    else
        error "No supported package manager found (apt/yum/dnf)"
        exit 1
    fi
}

# Install tmux
if ! command -v tmux &>/dev/null; then
    info "Installing tmux ..."
    install_pkg tmux
    success "tmux installed: $(tmux -V)"
else
    success "tmux installed: $(tmux -V)"
fi

# Install git
if ! command -v git &>/dev/null; then
    info "Installing git ..."
    install_pkg git
    success "git installed"
else
    success "git installed"
fi

# Create directory structure
mkdir -p ~/.config/tmux

# Back up existing tmux.conf if present
if [[ -f "$HOME/.config/tmux/tmux.conf" ]]; then
    _backup="$HOME/.config/tmux/tmux.conf.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.config/tmux/tmux.conf" "$_backup"
    warn "Existing tmux.conf backed up to $_backup"
fi

# Place tmux.conf
mv /tmp/tmux.conf.deploy ~/.config/tmux/tmux.conf
success "tmux.conf deployed to ~/.config/tmux/tmux.conf"

# Create symlink: ~/.tmux -> ~/.config/tmux
if [[ -L "$HOME/.tmux" ]]; then
    rm "$HOME/.tmux"
elif [[ -d "$HOME/.tmux" ]]; then
    if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        warn "Backing up existing ~/.tmux ..."
        mv "$HOME/.tmux" "$HOME/.tmux.bak.$(date +%Y%m%d_%H%M%S)"
    else
        rm -rf "$HOME/.tmux"
    fi
fi
ln -sf "$HOME/.config/tmux" "$HOME/.tmux"
success "symlink: ~/.tmux -> ~/.config/tmux"

# Install TPM
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
    info "Installing TPM (Tmux Plugin Manager) ..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    success "TPM installed"
else
    success "TPM installed"
fi

# Install all tmux plugins
info "Installing tmux plugins ..."
"$TPM_DIR/bin/install_plugins"

# Fix catppuccin/dracula repo name collision
# TPM may clone the wrong repo since both catppuccin and dracula have repos named "tmux"
CATPPUCCIN_DIR="$HOME/.config/tmux/plugins/tmux"
if [[ -f "$CATPPUCCIN_DIR/dracula.tmux" ]]; then
    warn "Detected Dracula installed instead of Catppuccin, fixing ..."
    rm -rf "$CATPPUCCIN_DIR"
    git clone https://github.com/catppuccin/tmux.git "$CATPPUCCIN_DIR"
fi
success "tmux plugins installed"

# Install Ghostty terminfo (for SSH from Ghostty terminal)
if ! infocmp xterm-ghostty &>/dev/null 2>&1; then
    info "Installing Ghostty terminfo ..."
    TMPDIR=$(mktemp -d)
    cat > "$TMPDIR/ghostty.terminfo" << 'TERMINFO'
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
    tic -x "$TMPDIR/ghostty.terminfo" 2>/dev/null && \
        success "Ghostty terminfo installed" || \
        warn "Ghostty terminfo install failed (non-critical)"
    rm -rf "$TMPDIR"
else
    success "Ghostty terminfo exists"
fi

echo ""
success "========================================"
success "tmux environment deployed!"
success "========================================"
echo -e "  Connect and run ${GREEN}tmux${NC} to start"
echo -e "  If already in tmux, press ${GREEN}Ctrl-a + r${NC} to reload config"
REMOTE_SCRIPT

# 3. Optionally deploy Claude Code statusline
STATUSLINE_DIR="$REPO_DIR/statusline"
if [[ -d "$STATUSLINE_DIR" ]]; then
    echo ""
    printf "Also install Claude Code statusline on $REMOTE_HOST? [y/N] "
    read -r _answer
    _has_statusline=0
    if [[ "$_answer" =~ ^[Yy] ]]; then
        _has_statusline=1
        info "Deploying Claude Code statusline ..."
        scp -r "${SSH_OPTS[@]}" "$STATUSLINE_DIR" "$REMOTE_HOST:/tmp/statusline-deploy"
        ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" 'bash /tmp/statusline-deploy/install.sh && rm -rf /tmp/statusline-deploy'
        success "Claude Code statusline installed on $REMOTE_HOST"
    else
        info "Skipped statusline install. tmux.conf will gracefully handle missing scripts."
    fi
fi

# 4. Optionally deploy Claude Code hooks
HOOKS_DIR="$REPO_DIR/hooks"
if [[ -d "$HOOKS_DIR" ]]; then
    echo ""
    printf "Also install Claude Code hooks on $REMOTE_HOST? [y/N] "
    if [[ "$_has_statusline" = "0" ]]; then
        echo "(Note: usage-logger and context-alert require statusline)"
    fi
    read -r _answer
    if [[ "$_answer" =~ ^[Yy] ]]; then
        info "Deploying Claude Code hooks ..."
        scp -r "${SSH_OPTS[@]}" "$HOOKS_DIR" "$REMOTE_HOST:/tmp/hooks-deploy"
        ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" 'bash /tmp/hooks-deploy/install.sh && rm -rf /tmp/hooks-deploy'
        success "Claude Code hooks installed on $REMOTE_HOST"
    else
        info "Skipped hooks install."
    fi
fi

success "Deployment complete!"
