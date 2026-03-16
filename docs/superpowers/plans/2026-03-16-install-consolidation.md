# Install Consolidation: Fix deploy.sh symlink bug + add tmux setup to statusline/install.sh

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix broken symlinks in remote deploys and let `statusline/install.sh` optionally set up tmux (conf + TPM + plugins), so colleagues can `git pull && bash statusline/install.sh` on a fresh machine and get everything working.

**Architecture:** Add a new Step 6.5 to `statusline/install.sh` that detects `../tmux/tmux.conf` in the repo and offers to install tmux environment locally (tmux.conf + TPM + plugins). Fix `tmux/deploy.sh` to copy statusline/hooks to a permanent path instead of `/tmp`. No new files — only modify existing scripts.

**Tech Stack:** Shell (POSIX sh + bash), jq, git, tmux TPM

---

## Chunk 1: Fix deploy.sh symlink bug

### Bug Summary

`tmux/deploy.sh` line 250-251:
```bash
scp -r "$STATUSLINE_DIR" "$REMOTE_HOST:/tmp/statusline-deploy"
ssh "$REMOTE_HOST" 'bash /tmp/statusline-deploy/install.sh && rm -rf /tmp/statusline-deploy'
```

`statusline/install.sh` creates symlinks pointing to `$SCRIPT_DIR` (= `/tmp/statusline-deploy/`), then deploy.sh deletes `/tmp/statusline-deploy/`. All symlinks become broken.

Same bug exists for hooks deployment (line 269-270).

### Task 1: Fix deploy.sh remote symlink bug

**Files:**
- Modify: `tmux/deploy.sh:240-275`

**Problem:** scp to `/tmp`, install.sh creates symlinks to `/tmp`, then `rm -rf /tmp/...` breaks all symlinks.

**Fix:** Copy to a permanent location (`~/.local/share/claude-code-toolkit/`) instead of `/tmp`, and don't delete after install.

- [ ] **Step 1: Write a test to verify the bug**

SSH into ubuntu-VM-R1 and check current symlink state:
```bash
ssh ubuntu-VM-R1 'ls -la ~/.claude/statusline-command.sh'
```
Confirm it currently points to a valid path (since this VM used `git clone` + local install, not deploy.sh). This establishes baseline.

- [ ] **Step 2: Modify deploy.sh statusline section (lines 240-255)**

Replace the statusline deployment block:

```bash
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
        # Copy to permanent path so symlinks survive (not /tmp)
        _remote_src="\$HOME/.local/share/claude-code-toolkit/statusline"
        ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "mkdir -p \$HOME/.local/share/claude-code-toolkit"
        scp -r "${SSH_OPTS[@]}" "$STATUSLINE_DIR" "$REMOTE_HOST:~/.local/share/claude-code-toolkit/statusline"
        ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "bash ~/.local/share/claude-code-toolkit/statusline/install.sh"
        success "Claude Code statusline installed on $REMOTE_HOST"
    else
        info "Skipped statusline install. tmux.conf will gracefully handle missing scripts."
    fi
fi
```

- [ ] **Step 3: Modify deploy.sh hooks section (lines 258-275)**

Apply same fix for hooks:

```bash
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
        ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "mkdir -p \$HOME/.local/share/claude-code-toolkit"
        scp -r "${SSH_OPTS[@]}" "$HOOKS_DIR" "$REMOTE_HOST:~/.local/share/claude-code-toolkit/hooks"
        ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "bash ~/.local/share/claude-code-toolkit/hooks/install.sh"
        success "Claude Code hooks installed on $REMOTE_HOST"
    else
        info "Skipped hooks install."
    fi
fi
```

- [ ] **Step 4: Verify fix**

```bash
# Simulate deploy.sh flow manually to verify
ssh ubuntu-VM-R1 'ls -la ~/.claude/statusline-command.sh && file ~/.claude/statusline-command.sh'
```
Expected: symlink points to a path that exists.

- [ ] **Step 5: Commit**

```bash
git add tmux/deploy.sh
git commit -m "fix(deploy): copy to permanent path instead of /tmp to prevent broken symlinks

deploy.sh was scp-ing statusline/hooks to /tmp, then install.sh created
symlinks pointing there, then rm -rf deleted the target. All symlinks
ended up broken on the remote host.

Now copies to ~/.local/share/claude-code-toolkit/ which persists.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

## Chunk 2: Add tmux setup to statusline/install.sh

### Task 2: Add optional tmux environment setup to statusline/install.sh

**Files:**
- Modify: `statusline/install.sh:140-173` (replace Step 6)

**Goal:** When `statusline/install.sh` detects `tmux/tmux.conf` in the same repo, offer to install:
1. tmux.conf → `~/.config/tmux/tmux.conf`
2. TPM (git clone)
3. All plugins (TPM install_plugins)
4. Catppuccin fix (dracula collision)
5. `~/.tmux` → `~/.config/tmux` symlink

This reuses the logic from `deploy.sh`'s REMOTE_SCRIPT heredoc, adapted for local execution.

- [ ] **Step 1: Replace Step 6 in statusline/install.sh**

Replace lines 140-173 (the old tmux section) with:

```sh
# ── Step 6: Configure tmux ──────────────────────────────────────────────────
# Detect if repo contains tmux/tmux.conf for full tmux environment setup
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_TMUX_CONF="$REPO_DIR/tmux/tmux.conf"

if [ -f "$REPO_TMUX_CONF" ] && command -v tmux >/dev/null 2>&1; then
    info "Found tmux.conf in repo: $REPO_TMUX_CONF"
    printf '  Install full tmux environment (tmux.conf + TPM + plugins)? [Y/n] '
    read -r _tmux_answer
    case "$_tmux_answer" in
        [Nn]*) info "Skipped tmux environment setup." ;;
        *)
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
```

- [ ] **Step 2: Test locally (macOS) — verify no regression**

```bash
# Dry run: the script should detect tmux.conf and prompt
bash statusline/install.sh
# Answer 'n' to tmux prompt → should skip gracefully
# Verify statusline still works
echo '{"model":{"display_name":"Test"}}' | sh ~/.claude/statusline-command.sh
```

- [ ] **Step 3: Test on ubuntu-VM-R1**

```bash
ssh ubuntu-VM-R1 'cd ~/claude-code-toolkit && git pull && bash statusline/install.sh'
# Answer 'Y' to tmux prompt
# Verify:
ssh ubuntu-VM-R1 'ls ~/.config/tmux/tmux.conf && ls ~/.config/tmux/plugins/tpm/tpm && ls ~/.config/tmux/plugins/tmux/catppuccin.tmux'
```

- [ ] **Step 4: Commit**

```bash
git add statusline/install.sh
git commit -m "feat(statusline): add optional tmux environment setup to install.sh

When install.sh detects tmux/tmux.conf in the repo, it now offers to
install the full tmux environment: tmux.conf, TPM, and all plugins
(including catppuccin). This means colleagues can git pull + run
statusline/install.sh and get everything working in one step.

Falls back to the original minimal tmux monitor setup when repo
tmux.conf is not available.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

## Chunk 3: Update deploy.sh to reuse statusline/install.sh tmux logic

### Task 3: Simplify deploy.sh REMOTE_SCRIPT since statusline/install.sh now handles tmux

**Files:**
- Modify: `tmux/deploy.sh`

Now that `statusline/install.sh` can install tmux environment, `deploy.sh` can be simplified. The statusline install step in deploy.sh will automatically offer tmux setup if the user says yes to statusline.

However, `deploy.sh` still needs to handle the case where users want tmux but NOT statusline, so the REMOTE_SCRIPT heredoc stays. No changes needed to REMOTE_SCRIPT itself — it's the standalone tmux-only path.

- [ ] **Step 1: Add a note in deploy.sh about the relationship**

Add a comment near the statusline section:

```bash
# Note: statusline/install.sh now includes optional tmux environment setup.
# If user installs statusline, they'll be prompted to set up tmux too.
# The REMOTE_SCRIPT above handles tmux-only deployment (without statusline).
```

- [ ] **Step 2: Commit**

```bash
git add tmux/deploy.sh
git commit -m "docs(deploy): add comment about statusline/install.sh tmux integration

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

## Chunk 4: Update README docs

### Task 4: Update statusline README to document tmux setup

**Files:**
- Modify: `statusline/README.md`
- Modify: `statusline/README.zh-TW.md`

- [ ] **Step 1: Add tmux section to README.zh-TW.md**

In the "安裝流程" section, update step 5 to mention tmux full setup:

```markdown
5. 若偵測到 repo 中有 `tmux/tmux.conf`，詢問是否安裝完整 tmux 環境（tmux.conf + TPM + 所有插件）
6. 若不安裝完整環境但在 tmux session 中，設定最小化的 Claude session monitor
```

- [ ] **Step 2: Add same to README.md (English)**

- [ ] **Step 3: Commit**

```bash
git add statusline/README.md statusline/README.zh-TW.md
git commit -m "docs(statusline): document tmux environment setup in install.sh

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

## Summary: What changes after this plan

**Before (broken flow):**
```
# On remote VM — need two separate steps from two places:
1. (from Mac) bash tmux/deploy.sh user@host     ← installs tmux
2. (from Mac) → prompts to install statusline   ← broken symlinks!
# OR
1. (on VM) git clone repo && bash statusline/install.sh  ← no tmux setup
2. (on VM) ??? manually copy tmux.conf ???
```

**After (one-step flow):**
```
# On remote VM:
git clone repo && bash statusline/install.sh
# → installs statusline
# → asks: "Install full tmux environment?" → Y
# → installs tmux.conf + TPM + plugins automatically
# Done!

# OR from Mac (also fixed):
bash tmux/deploy.sh user@host
# → statusline symlinks now point to ~/.local/share/... (permanent)
```
