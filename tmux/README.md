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

On Windows, see [Windows (psmux)](#windows-psmux).

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

## Windows (psmux)

`psmux.conf` is a port of `tmux.conf` for [psmux](https://github.com/psmux/psmux), a native Windows tmux (no WSL or Cygwin). It keeps the same prefix, keybindings, Catppuccin Mocha theme and status bar. Tested with psmux 3.4.0.

### Requirements

- [psmux](https://github.com/psmux/psmux): `winget install marlocarlo.psmux`
- PowerShell 7: `winget install Microsoft.PowerShell` (the config sets `default-shell pwsh`)
- Git for Windows: `winget install Git.Git` (git branch in the status bar; Git Bash for the Claude monitor)
- A Nerd Font: `winget install DEVCOM.JetBrainsMonoNerdFont`, then select it in your terminal

### Install

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File tmux\install.ps1
```

The installer:

- Checks for psmux, PowerShell 7 and a Nerd Font. If psmux or PowerShell 7 is missing it prints the `winget` command and exits; a missing Nerd Font is only a warning. Nothing is installed unless you pass `-InstallDeps`, which installs the missing ones with winget (`-FontPackage <winget id>` picks another font).
- Copies the config and scripts (table below). An existing file with different content is backed up to `<name>.bak-<yyyyMMdd-HHmmss>` first; identical files are skipped, so re-running is safe.
- Warns about other config files that psmux will ignore (see below).

Then open a new terminal and run `tmux` (or `psmux`). In sessions that were already running, press `C-a r` to reload.

### Config locations

| Repo file | Installed to | Purpose |
|-----------|--------------|---------|
| `tmux/psmux.conf` | `~/.psmux.conf` | Main config |
| `tmux/scripts/sysinfo.ps1` | `~/.config/psmux/scripts/` | CPU / RAM / battery collector |
| `tmux/scripts/git-branch.cmd` | `~/.config/psmux/scripts/` | Git branch of the active pane |
| `tmux/scripts/open.ps1` | `~/.config/psmux/scripts/` | Copy-mode `o` (open) and `S` (search) |
| (generated) | `~/.config/psmux/cache/sysinfo.txt` | Collector output read by the status bar |

psmux loads only the first config file it finds, in this order: `~/.psmux.conf`, `~/.psmuxrc`, `~/.tmux.conf`, `~/.config/psmux/psmux.conf`. `psmux -f <file>` or the `PSMUX_CONFIG_FILE` environment variable overrides the search. With `~/.psmux.conf` installed, the other three are ignored.

### Notes

Differences and caveats compared with the Linux/macOS config:

- **No TPM or plugins.** catppuccin, tmux-sensible, vim-tmux-navigator, tmux-cpu, tmux-battery and tmux-open are reimplemented inline in `psmux.conf` or in `tmux/scripts/`. `C-a I` does nothing.
- `if-shell` conditions run in **PowerShell**; `#(...)` in the status line runs in **cmd.exe**.
- psmux does not expand `#{...}` inside `#(...)`. `git-branch.cmd` asks the server for the active pane's path itself.
- psmux quoting bug: a `"` inside a config string is stored as `\"`, which breaks the cmd.exe command. Do not put double quotes inside `#(...)`.
- `default-terminal` is `xterm-256color`, because Git for Windows' ncurses has no `tmux-256color` entry (vim and less from Git Bash need it).
- `escape-time` is 50 ms instead of tmux-sensible's 0, as psmux recommends on Windows.
- The `MouseDragEnd1Pane` binding is dropped: psmux copies a mouse drag to the Windows clipboard by itself.
- tmux-open's `C-o` (open in `$EDITOR`) is dropped. `o` (open with the default Windows handler) and `S` (Google search) work in copy mode.
- The Claude monitor line appears only when `~/.claude/tmux-sessions.sh` exists, and it needs Git Bash and jq (`winget install jqlang.jq`). It runs `%LOCALAPPDATA%\Programs\Git\bin\bash.exe`, the per-user Git for Windows path. With a machine-wide Git install, edit the `status-format[1]` line in `~/.psmux.conf`. The path cannot be quoted (see the quoting bug above), so use one without spaces, such as the short name `C:\PROGRA~1\Git\bin\bash.exe`.
- The sysinfo collector (`sysinfo.ps1`) starts from the config with `run-shell -b`. A named mutex keeps one instance per user, and it exits (deleting its cache file) within about 30 seconds after the last psmux session ends.
- A Nerd Font is required for the status bar icons and rounded separators.

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

## VS Code Terminal

tmux mouse mode is **automatically disabled** when running inside VS Code's integrated terminal (`$TERM_PROGRAM=vscode`), so native copy/paste works normally.

If you're in a non-VS Code terminal and need to bypass tmux mouse capture:
- **macOS**: Hold `Option` while selecting text
- **Linux/Windows**: Hold `Shift` while selecting text

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
