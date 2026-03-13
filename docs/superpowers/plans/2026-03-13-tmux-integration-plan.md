# tmux Configuration Integration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate tmux catppuccin-mocha configuration into the repo as a standalone component, with conditional Claude session monitor and remote deployment support.

**Architecture:** New `tmux/` directory with `tmux.conf` (catppuccin-mocha + `if-shell` Claude monitor) and `deploy.sh` (remote SSH deployment with optional statusline install). Existing `statusline/install.sh` gains catppuccin auto-detection with dracula fallback.

**Tech Stack:** tmux 3.3+, TPM, catppuccin/tmux, POSIX shell

**Spec:** `docs/superpowers/specs/2026-03-13-tmux-integration-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `tmux/tmux.conf` | Catppuccin-mocha tmux config + conditional Claude monitor |
| Create | `tmux/deploy.sh` | Remote tmux+statusline deployment via SSH |
| Create | `tmux/README.md` | English documentation for tmux component |
| Create | `tmux/README.zh-TW.md` | Traditional Chinese documentation |
| Modify | `statusline/install.sh:150-164` | Catppuccin auto-detection + precedence rule |
| Modify | `.gitignore` | Add `tmux/plugins/` |
| Modify | `README.md` | Add tmux component section |
| Modify | `README.zh-TW.md` | Add tmux component section (Chinese) |

---

## Chunk 0: Prerequisites

### Task 0: Verify prerequisites

- [ ] **Step 1: Confirm status-hook.sh is tracked in git**

```bash
git ls-files --error-unmatch statusline/status-hook.sh
# Expected: statusline/status-hook.sh
# If error: run `git add statusline/status-hook.sh && git commit -m "feat: add status-hook.sh"`
```

---

## Chunk 1: Core tmux Config

### Task 1: Create tmux/tmux.conf

**Files:**
- Create: `tmux/tmux.conf`

- [ ] **Step 1: Create tmux directory**

```bash
mkdir -p tmux
```

- [ ] **Step 2: Write tmux.conf**

Copy from `~/.config/tmux/tmux.conf` with these modifications:
1. Add `set -g status-interval 2` globally
2. Add `if-shell` block at the end for conditional Claude monitor
3. Keep all existing content (plugins, keybindings, theme, status bar)

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'catppuccin/tmux'
set -g @plugin 'tmux-plugins/tmux-cpu'
set -g @plugin 'tmux-plugins/tmux-battery'
set -g @plugin 'tmux-plugins/tmux-open'
set -g history-limit 102400

# catppuccin customizations
set -g @catppuccin_flavor "mocha"
set -g @catppuccin_window_status_style "rounded"
set -g @catppuccin_window_text "#W"
set -g @catppuccin_window_current_text "#W"
set -g @catppuccin_window_flags "icon"
set -g @catppuccin_date_time_text " %Y/%m/%d %H:%M"
set -g @catppuccin_cpu_icon " CPU "

# Synchronous multi-terminal input
bind-key s setw synchronize-panes

set -g mouse on
# Keep selection highlighted on mouse drag release (press o to open URL / y to copy)
bind -Tcopy-mode MouseDragEnd1Pane send -X copy-selection-no-clear

# Enable terminal passthrough (URL clicks, clipboard integration, tmux 3.3+)
if-shell 'test "$(tmux -V | cut -d" " -f2 | tr -d a-z)" \> "3.2"' \
  'set -g allow-passthrough on'
set -gs set-clipboard on

# True color and terminal fixes
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

bind-key C-l send-keys C-l \; clear-history

set -g prefix C-a
unbind C-b
bind-key C-a send-prefix

bind c new-window -c "#{pane_current_path}"

unbind %
bind | split-window -h -c "#{pane_current_path}"

unbind '"'
bind - split-window -v -c "#{pane_current_path}"

unbind r
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

bind -r j resize-pane -D 5
bind -r k resize-pane -U 5
bind -r l resize-pane -R 5
bind -r h resize-pane -L 5

bind -r m resize-pane -Z

# load catppuccin before status line config
run ~/.config/tmux/plugins/tmux/catppuccin.tmux

# status line
set -g status-interval 2
set -g status-right-length 200
set -g status-left-length 100
set -g status-left "#{E:@catppuccin_status_session}"
set -gF status-right "#{E:@catppuccin_status_cpu}"
set -ag status-right "#[bg=#{@thm_teal},fg=#{@thm_crust}]#[reverse]#[noreverse] RAM "
set -ag status-right "#[fg=#{@thm_fg},bg=#{@thm_mantle}] #{ram_percentage} "
set -agF status-right "#{E:@catppuccin_status_battery}"
set -ag status-right "#{E:@catppuccin_status_date_time}"
set -ag status-right "#[fg=#{@thm_mauve},bg=default]  #(cd #{pane_current_path} && git branch --show-current) "

run '~/.tmux/plugins/tpm/tpm'

# copy mode selection highlight color (placed last to avoid being overridden)
set -gF mode-style "fg=#{@thm_crust},bg=#{@thm_peach}"

# ── Claude Code session monitor (conditional) ────────────────────────────────
# Only activates when Claude Code statusline is installed (~/.claude/tmux-sessions.sh exists).
# Uses catppuccin semantic colors for consistent theming.
if-shell '[ -f ~/.claude/tmux-sessions.sh ]' {
    set -g status 2
    set -g status-format[1] "#[align=left,fg=#{@thm_mauve},bg=#{@thm_crust}] Claude: #(sh ~/.claude/tmux-sessions.sh)"
}
```

- [ ] **Step 3: Verify file is valid**

```bash
# Quick syntax sanity: no shell errors in the non-run lines
grep -c 'set -g' tmux/tmux.conf
# Expected: ~20+ lines
```

- [ ] **Step 4: Commit**

```bash
git add tmux/tmux.conf
git commit -m "feat(tmux): add catppuccin-mocha config with conditional Claude monitor"
```

---

### Task 2: Update .gitignore

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Add tmux/plugins/ entry**

Append to `.gitignore`:
```
tmux/plugins/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore tmux/plugins/ directory"
```

---

### Task 3: Modify statusline/install.sh — catppuccin auto-detection

**Files:**
- Modify: `statusline/install.sh:150-164`

- [ ] **Step 1: Replace Step 6 (tmux configuration block)**

Replace the entire `# ── Step 6: Configure tmux (optional)` section (lines 150-164) with:

```sh
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
```

- [ ] **Step 2: Test locally — run install.sh inside tmux with catppuccin**

```bash
bash statusline/install.sh
# Expected: "Catppuccin theme detected (mocha). Using themed colors..."
# Verify: tmux show -g status-format[1] should contain @thm_mauve
tmux show -g status-format[1]
```

- [ ] **Step 3: Commit**

```bash
git add statusline/install.sh
git commit -m "feat(statusline): auto-detect catppuccin theme for tmux monitor colors"
```

---

## Chunk 2: Remote Deployment

### Task 4: Create tmux/deploy.sh

**Files:**
- Create: `tmux/deploy.sh`

- [ ] **Step 1: Write deploy.sh**

Based on `~/.config/tmux/deploy.sh` with these additions:
1. Back up existing remote tmux.conf before overwriting
2. After tmux deployment, prompt "Also install Claude Code statusline? [y/N]"
3. If yes, scp `statusline/` to remote and run `install.sh`

```bash
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
    if [[ "$_answer" =~ ^[Yy] ]]; then
        info "Deploying Claude Code statusline ..."
        scp -r "${SSH_OPTS[@]}" "$STATUSLINE_DIR" "$REMOTE_HOST:/tmp/statusline-deploy"
        ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" 'bash /tmp/statusline-deploy/install.sh && rm -rf /tmp/statusline-deploy'
        success "Claude Code statusline installed on $REMOTE_HOST"
    else
        info "Skipped statusline install. tmux.conf will gracefully handle missing scripts."
    fi
fi

success "Deployment complete!"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tmux/deploy.sh
```

- [ ] **Step 3: Commit**

```bash
git add tmux/deploy.sh
git commit -m "feat(tmux): add remote deployment script with optional statusline install"
```

---

## Chunk 3: Documentation

### Task 5: Create tmux/README.md

**Files:**
- Create: `tmux/README.md`

- [ ] **Step 1: Write English README**

```markdown
[English](README.md) | [繁體中文](README.zh-TW.md)

# tmux Configuration

Catppuccin Mocha themed tmux configuration with integrated Claude Code session monitor.

## Features

- **Catppuccin Mocha theme** — soft pastel colors with rounded window status
- **Status bar** — CPU, RAM, battery, date/time, git branch
- **Claude Code monitor** — automatically shows active Claude sessions when statusline is installed
- **Vim-tmux navigation** — seamless pane switching with Ctrl-h/j/k/l
- **Mouse support** — click, scroll, drag-select with persistent highlight
- **Remote deployment** — one-command setup for Linux servers

## Requirements

- tmux **3.3+**
- git (for TPM plugin installation)
- [TPM](https://github.com/tmux-plugins/tpm) (installed automatically by deploy.sh)

## Quick Start

### Local Setup

```bash
# 1. Copy config
mkdir -p ~/.config/tmux
cp tmux/tmux.conf ~/.config/tmux/tmux.conf

# 2. Symlink for TPM compatibility
ln -sf ~/.config/tmux ~/.tmux

# 3. Install TPM (if not installed)
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# 4. Start tmux and install plugins
tmux
# Press prefix (Ctrl-a) + I to install plugins
```

### Remote Deployment

```bash
bash tmux/deploy.sh user@host [ssh-options]
```

Installs tmux, git, TPM, all plugins, and Ghostty terminfo on the remote host. Optionally installs Claude Code statusline.

## Claude Code Integration

When [Claude Code statusline](../statusline/README.md) is installed, a second status bar line automatically appears:

```
⚡my-project 42% │ 💤other-proj 14%
```

This is controlled by an `if-shell` guard — no empty line when statusline is not installed.

## Keybindings

| Key | Action |
|-----|--------|
| `C-a` | Prefix (replaces C-b) |
| `C-a \|` | Split horizontal |
| `C-a -` | Split vertical |
| `C-a c` | New window |
| `C-a s` | Toggle synchronize-panes |
| `C-a r` | Reload config |
| `C-a h/j/k/l` | Resize pane |
| `C-a m` | Zoom pane |
| `C-a C-l` | Clear history |
| `C-h/j/k/l` | Navigate panes (vim-tmux-navigator) |

## Plugins

| Plugin | Purpose |
|--------|---------|
| [tpm](https://github.com/tmux-plugins/tpm) | Plugin manager |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | Sensible defaults |
| [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | Vim-style pane navigation |
| [catppuccin/tmux](https://github.com/catppuccin/tmux) | Catppuccin Mocha theme |
| [tmux-cpu](https://github.com/tmux-plugins/tmux-cpu) | CPU & RAM display |
| [tmux-battery](https://github.com/tmux-plugins/tmux-battery) | Battery display |
| [tmux-open](https://github.com/tmux-plugins/tmux-open) | Open URLs and files from copy mode |
```

- [ ] **Step 2: Commit**

```bash
git add tmux/README.md
git commit -m "docs(tmux): add English README"
```

---

### Task 6: Create tmux/README.zh-TW.md

**Files:**
- Create: `tmux/README.zh-TW.md`

- [ ] **Step 1: Write Chinese README**

```markdown
[English](README.md) | [繁體中文](README.zh-TW.md)

# tmux 設定

Catppuccin Mocha 主題的 tmux 設定，整合 Claude Code session 監控。

## 功能

- **Catppuccin Mocha 主題** — 柔和粉彩色，圓角視窗狀態
- **狀態列** — CPU、RAM、電池、日期時間、git 分支
- **Claude Code 監控** — 安裝 statusline 後自動顯示活躍的 Claude session
- **Vim-tmux 導航** — Ctrl-h/j/k/l 無縫切換窗格
- **滑鼠支援** — 點擊、捲動、拖曳選取並保持高亮
- **遠端部署** — 一鍵設定 Linux 伺服器

## 需求

- tmux **3.3+**
- git（用於 TPM 插件安裝）
- [TPM](https://github.com/tmux-plugins/tpm)（deploy.sh 會自動安裝）

## 快速開始

### 本地設定

```bash
# 1. 複製設定檔
mkdir -p ~/.config/tmux
cp tmux/tmux.conf ~/.config/tmux/tmux.conf

# 2. 建立 TPM 相容的 symlink
ln -sf ~/.config/tmux ~/.tmux

# 3. 安裝 TPM（若尚未安裝）
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# 4. 啟動 tmux 並安裝插件
tmux
# 按 prefix (Ctrl-a) + I 安裝插件
```

### 遠端部署

```bash
bash tmux/deploy.sh user@host [ssh-options]
```

自動安裝 tmux、git、TPM、所有插件、Ghostty terminfo。可選安裝 Claude Code statusline。

## Claude Code 整合

安裝 [Claude Code statusline](../statusline/README.zh-TW.md) 後，會自動出現第二行狀態列：

```
⚡my-project 42% │ 💤other-proj 14%
```

透過 `if-shell` 條件控制 — 未安裝 statusline 時不會顯示空行。

## 快捷鍵

| 按鍵 | 功能 |
|------|------|
| `C-a` | Prefix（取代 C-b）|
| `C-a \|` | 水平分割 |
| `C-a -` | 垂直分割 |
| `C-a c` | 新視窗 |
| `C-a s` | 切換同步輸入 |
| `C-a r` | 重載設定 |
| `C-a h/j/k/l` | 調整窗格大小 |
| `C-a m` | 縮放窗格 |
| `C-a C-l` | 清除歷史 |
| `C-h/j/k/l` | 切換窗格（vim-tmux-navigator）|

## 插件

| 插件 | 用途 |
|------|------|
| [tpm](https://github.com/tmux-plugins/tpm) | 插件管理器 |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | 合理預設值 |
| [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | Vim 風格窗格導航 |
| [catppuccin/tmux](https://github.com/catppuccin/tmux) | Catppuccin Mocha 主題 |
| [tmux-cpu](https://github.com/tmux-plugins/tmux-cpu) | CPU 與 RAM 顯示 |
| [tmux-battery](https://github.com/tmux-plugins/tmux-battery) | 電池顯示 |
| [tmux-open](https://github.com/tmux-plugins/tmux-open) | 從 copy mode 開啟 URL 與檔案 |
```

- [ ] **Step 2: Commit**

```bash
git add tmux/README.zh-TW.md
git commit -m "docs(tmux): add Traditional Chinese README"
```

---

### Task 7: Update root READMEs

**Files:**
- Modify: `README.md`
- Modify: `README.zh-TW.md`

- [ ] **Step 1: Replace existing tmux section in README.md**

Replace the existing `## tmux Integration` section (lines 89-97, from `## tmux Integration` through the end of the manual `tmux set-option` code block) with the new `## tmux Configuration` section:

```markdown
## tmux Configuration

A complete Catppuccin Mocha tmux setup with Claude Code integration. See [`tmux/README.md`](tmux/README.md) for details.

### Local Setup

```bash
cp tmux/tmux.conf ~/.config/tmux/tmux.conf
ln -sf ~/.config/tmux ~/.tmux
# Install TPM, then press prefix + I inside tmux
```

### Remote Deployment

```bash
bash tmux/deploy.sh user@host
```

Deploys tmux + Catppuccin theme + plugins. Optionally installs Claude Code statusline.
```

- [ ] **Step 2: Replace existing tmux section in README.zh-TW.md**

Replace the existing `## tmux 整合` section (same position as English) with:

```markdown
## tmux 設定

完整的 Catppuccin Mocha tmux 設定，整合 Claude Code。詳見 [`tmux/README.zh-TW.md`](tmux/README.zh-TW.md)。

### 本地設定

```bash
cp tmux/tmux.conf ~/.config/tmux/tmux.conf
ln -sf ~/.config/tmux ~/.tmux
# 安裝 TPM，然後在 tmux 內按 prefix + I
```

### 遠端部署

```bash
bash tmux/deploy.sh user@host
```

部署 tmux + Catppuccin 主題 + 插件。可選安裝 Claude Code statusline。
```

- [ ] **Step 3: Commit**

```bash
git add README.md README.zh-TW.md
git commit -m "docs: add tmux component section to root READMEs"
```

---

## Chunk 4: Local Verification

### Task 8: End-to-end verification

- [ ] **Step 1: Verify tmux.conf loads correctly**

```bash
# Copy to local config
cp tmux/tmux.conf ~/.config/tmux/tmux.conf
# Reload inside tmux
tmux source-file ~/.config/tmux/tmux.conf
# Verify catppuccin loaded
tmux show -gv @catppuccin_flavor
# Expected: mocha
```

- [ ] **Step 2: Verify Claude monitor conditional**

```bash
# With statusline installed, verify second status line
tmux show -g status
# Expected: 2
tmux show -g status-format[1]
# Expected: contains @thm_mauve and tmux-sessions.sh
```

- [ ] **Step 3: Verify install.sh catppuccin detection**

```bash
bash statusline/install.sh
# Expected output includes: "Catppuccin theme detected (mocha). Using themed colors..."
# OR: "Claude monitor already configured in tmux.conf. Skipping tmux setup."
```

- [ ] **Step 4: Verify dracula fallback (without catppuccin)**

```bash
# Temporarily unset catppuccin to test fallback
tmux set -gu @catppuccin_flavor
bash statusline/install.sh
# Expected output: "tmux detected. Setting up real-time session monitor on status bar line 2..."
# Verify: status-format[1] should contain #bd93f9 (dracula purple)
tmux show -g status-format[1]
# Restore catppuccin
tmux source-file ~/.config/tmux/tmux.conf
```

- [ ] **Step 5: Verify deploy.sh syntax**

```bash
bash -n tmux/deploy.sh
# Expected: no output (no syntax errors)
```

- [ ] **Step 6: Final status check**

```bash
git status
# Verify no unexpected changes
```

**Manual-only tests** (require specific environments, not automatable here):
- Test 5 (spec): Remote deploy to Linux host
- Test 6 (spec): Upgrade from dracula → catppuccin for existing users
- Test 8 (spec): tmux < 3.3 `allow-passthrough` guard
