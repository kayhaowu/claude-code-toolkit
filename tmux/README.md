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
