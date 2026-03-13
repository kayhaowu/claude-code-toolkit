# tmux Configuration Integration

## Problem

The claude-code-toolkit repo provides a Claude Code statusline and tmux session monitor, but the tmux setup (catppuccin-mocha theme, plugins, keybindings, remote deployment) lives separately in `~/.config/tmux/`. This causes two issues:

1. **Color mismatch** — `install.sh` hardcodes dracula hex colors (`#bd93f9`, `#282a36`) for the tmux second status line, but the user's tmux uses catppuccin-mocha with semantic color variables (`@thm_mauve`, `@thm_crust`)
2. **Fragmented deployment** — deploying tmux config and Claude Code toolkit to remote hosts requires two separate manual processes

## Goals

- Add tmux configuration as a standalone component in the repo (`tmux/` directory)
- Claude session monitor integrates with catppuccin theme colors
- Remote deployment script optionally installs Claude Code statusline alongside tmux
- Existing `statusline/install.sh` auto-detects catppuccin and uses matching colors

## Non-Goals

- Replacing or deprecating the standalone `statusline/install.sh` — it must continue to work independently
- Bundling tmux plugins in the repo — TPM handles plugin installation
- Supporting tmux themes other than catppuccin-mocha (future work)
- tmux component uninstall script — removal is manual (delete `~/.config/tmux/tmux.conf`, run `~/.tmux/plugins/tpm/bin/clean_plugins`)
- macOS remote deployment — `deploy.sh` targets Linux remotes only (apt/yum/dnf)

## Prerequisites

- Minimum tmux version: **3.3+** (required for `allow-passthrough`, catppuccin semantic color variables `#{@thm_*}` require 3.2+ user options)
- `statusline/status-hook.sh` must be committed to version control before implementation begins

## Design

### Directory Structure

```
claude-code-toolkit/
├── statusline/           # existing, unchanged API
│   ├── install.sh
│   ├── uninstall.sh
│   ├── statusline-command.sh
│   ├── dashboard.sh
│   ├── heartbeat.sh
│   ├── tmux-sessions.sh
│   ├── status-hook.sh
│   ├── README.md
│   └── README.zh-TW.md
├── tmux/                 # NEW
│   ├── tmux.conf
│   ├── deploy.sh
│   ├── README.md
│   └── README.zh-TW.md
├── .gitignore            # updated: add tmux/plugins/
├── README.md             # updated: add tmux component section
└── README.zh-TW.md       # updated: same
```

### tmux/tmux.conf

Based on the user's existing `~/.config/tmux/tmux.conf`. Key contents:

**Plugins:**
- tpm, tmux-sensible, vim-tmux-navigator, catppuccin/tmux, tmux-cpu, tmux-battery, tmux-open

**Theme:** catppuccin-mocha with customizations:
- Rounded window status style
- Window text shows `#W` with icon flags
- Date format: `YYYY/MM/DD HH:MM`

**Keybindings:**
- Prefix: `C-a` (replaces default `C-b`)
- `|` / `-` for splits (preserving current path)
- `c` for new window (preserving current path)
- `s` for synchronize-panes
- `r` for config reload
- `h/j/k/l` for pane resize
- `m` for pane zoom
- `C-l` for clear history

**Terminal settings:**
- Mouse on, copy-mode drag keeps selection
- `allow-passthrough on` (tmux 3.3+, guarded by `if-shell` version check)
- `tmux-256color` with RGB override
- Clipboard integration

**Status bar (line 1):**
- Left: catppuccin session name
- Right: CPU, RAM, Battery, Date, git branch (all catppuccin-styled)
- `status-interval 2` — set globally for both status line refresh and Claude monitor refresh. This is more frequent than tmux's default (15s), but tmux-cpu/battery plugins are designed for frequent polling and the overhead is negligible.

**Claude session monitor (line 2) — conditional:**
```tmux
if-shell '[ -f ~/.claude/tmux-sessions.sh ]' {
    set -g status 2
    set -g status-format[1] "#[align=left,fg=#{@thm_mauve},bg=#{@thm_crust}] Claude: #(sh ~/.claude/tmux-sessions.sh)"
}
```

Only activates when `tmux-sessions.sh` exists (i.e., Claude Code statusline is installed). Uses catppuccin semantic colors instead of hardcoded hex.

**Plugin path:** The `run` directives in tmux.conf reference `~/.config/tmux/plugins/`. This works in two scenarios:
- **Remote hosts:** `deploy.sh` creates a `~/.tmux` → `~/.config/tmux` symlink, so TPM installs plugins to `~/.config/tmux/plugins/` via the symlink
- **Local development:** Users must either (a) symlink `~/.tmux` → `~/.config/tmux`, or (b) have TPM installed at `~/.config/tmux/plugins/tpm`

The `.gitignore` entry `tmux/plugins/` prevents accidental commits if someone clones plugins into the repo directory.

### tmux/deploy.sh

Based on the user's existing `~/.config/tmux/deploy.sh`. Remote deployment via SSH. **Targets Linux remotes only** (apt/yum/dnf).

**Usage:**
```bash
bash tmux/deploy.sh user@host [ssh-options]
```

**Deployment steps:**
1. scp `tmux.conf` to remote `/tmp/tmux.conf.deploy`
2. SSH into remote and:
   - Install tmux and git (apt/yum/dnf)
   - Back up existing `~/.config/tmux/tmux.conf` if present (to `tmux.conf.bak.<timestamp>`)
   - Place `tmux.conf` at `~/.config/tmux/tmux.conf`
   - Symlink `~/.tmux` → `~/.config/tmux` (handles existing dir/symlink)
   - Install TPM and all plugins
   - Fix catppuccin/dracula repo name collision: TPM may clone the catppuccin plugin into a directory with the wrong origin (both repos are named `tmux`); the fix checks the remote URL and re-clones from `catppuccin/tmux` if needed
   - Install Ghostty terminfo (for SSH from Ghostty terminal)
3. **New:** Prompt user: "Also install Claude Code statusline? [y/N]"
   - If yes: scp the entire `statusline/` directory to remote `/tmp/statusline-deploy/`, then run `bash /tmp/statusline-deploy/install.sh` on the remote (reuses existing install logic, no reimplementation). Clean up temp dir after.
   - If no: skip — `tmux.conf`'s `if-shell` gracefully handles missing `tmux-sessions.sh`

**Idempotent:** Safe to re-run. Existing TPM/plugins are preserved. Remote `tmux.conf` is backed up before overwriting.

### statusline/install.sh Changes

**Precedence rule:** If `tmux.conf` already contains the Claude monitor `if-shell` block (i.e., the user is using the `tmux/` component), `install.sh` skips its own `status-format[1]` setup — `tmux.conf` is the canonical source.

```sh
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
            # Use catppuccin semantic color variables
            tmux set-option -g status 2
            tmux set-option -g status-format[1] \
                "#[align=left,fg=#{@thm_mauve},bg=#{@thm_crust}] Claude: #(sh ~/.claude/tmux-sessions.sh)"
        else
            # Fallback: dracula hardcoded colors (existing behavior)
            tmux set-option -g status 2
            tmux set-option -g status-format[1] \
                "#[align=left,fg=#bd93f9,bg=#282a36] Claude: #(sh ~/.claude/tmux-sessions.sh)"
        fi
        tmux set-option -g status-interval 2
    fi
fi
```

This is backward-compatible: users without catppuccin get the existing dracula colors.

### .gitignore Update

Add:
```
tmux/plugins/
```

Safety net in case TPM clones plugins into the repo directory. Standard TPM installs go to `~/.tmux/plugins/` via the symlink.

## Testing

1. **Fresh install:** Clone repo → `bash statusline/install.sh` inside tmux with catppuccin → verify second line uses `@thm_mauve`/`@thm_crust`
2. **Fresh install without catppuccin:** Same but plain tmux → verify dracula fallback colors
3. **tmux.conf deploy:** Copy `tmux/tmux.conf` to `~/.config/tmux/` → reload → verify catppuccin theme loads correctly
4. **Conditional monitor:** Without `~/.claude/tmux-sessions.sh` → verify only 1 status line; install statusline → verify second line appears
5. **Remote deploy (Linux):** `bash tmux/deploy.sh user@host` → verify tmux + plugins installed, optional Claude statusline prompt works
6. **Upgrade path:** Existing users with dracula colors → re-run `install.sh` → verify catppuccin detection updates colors
7. **Precedence:** User has both `tmux/tmux.conf` and runs `statusline/install.sh` → verify install.sh detects existing monitor and skips tmux setup
8. **tmux version:** On tmux < 3.3, verify `allow-passthrough` is skipped (existing `if-shell` guard), catppuccin still loads
