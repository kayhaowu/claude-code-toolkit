[English](README.md) | [繁體中文](README.zh-TW.md)

# Claude Code Status Line

Custom status line for the Claude Code CLI, displaying model name, context usage, token count, estimated cost, git branch, and project name. Supports 5 color themes.

**Status line** (inside Claude Code CLI):
```
Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │ est $0.12 │  main │ my-project
 purple         green/gray          yellow    cyan           yellow     blue      green
```

**After installation in tmux** — status line + session overview:
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ $ claude                                                                     │
│                                                                              │
│ > Help me refactor the auth module                                           │
│                                                                              │
│ Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │  main │ my-proj  │
├──────────────────────────────────────────────────────────────────────────────┤
│ [0] zsh           [1] claude*                                   13 Mar 10:30 │
│ Claude: ⚡my-proj 42% │ 💤api-server 18% │ 💤docs 7%                        │
└──────────────────────────────────────────────────────────────────────────────┘
 ↑ Claude Code status line (inside CLI)    ↑ tmux bar: all sessions at a glance
```

## System Requirements

| System | Requirement |
|--------|-------------|
| macOS | [Homebrew](https://brew.sh) |
| Ubuntu / Debian | sudo access |
| CentOS / RHEL | sudo access |

## Quick Install

Run from the project root:

```bash
bash statusline/install.sh
```

**Restart Claude Code** after installation to activate the status line.

### Install Process

The script automatically:

1. Detects operating system
2. Installs `jq` (if not already installed)
3. Creates symlinks in `~/.claude/` pointing to repo source (`statusline-command.sh`, `dashboard.sh`, `heartbeat.sh`, `tmux-sessions.sh`, `status-hook.sh`) — `git pull` auto-updates without re-install. Skips files that already exist as regular files to avoid overwriting user's own scripts
4. Updates `~/.claude/settings.json` — configures statusLine, session lifecycle hooks (SessionStart/SessionEnd), and event-driven status hooks (UserPromptSubmit/PostToolUse/Stop). Auto-backs up existing settings
5. If `tmux/tmux.conf` is found in the repo, compares with the installed version:
   - **Identical**: automatically skips tmux setup
   - **Differs**: shows a warning and asks whether to overwrite (existing config is backed up)
   - **Not installed**: asks whether to install the full tmux environment (tmux.conf + TPM + all plugins including Catppuccin theme)
6. If full tmux setup is skipped but running inside a tmux session, configures a minimal Claude session monitor

If `settings.json` already exists, the original is backed up to `~/.claude/settings.json.backup`.

## Themes

5 built-in color themes, selected via the `CLAUDE_STATUSLINE_THEME` environment variable:

| Theme | Description | Color Type |
|-------|-------------|------------|
| `ansi-default` | Default theme using standard ANSI colors | 4-bit ANSI |
| `catppuccin-mocha` | Catppuccin Mocha palette, soft pastel style | 24-bit TrueColor |
| `dracula` | Dracula theme, high-contrast dark style | 24-bit TrueColor |
| `nord` | Nord theme, arctic blue tones | 24-bit TrueColor |
| `none` | No colors, plain text output | None |

### Configuration

Add to your shell config (`~/.zshrc` or `~/.bashrc`):

```bash
export CLAUDE_STATUSLINE_THEME="catppuccin-mocha"
```

### NO_COLOR Support

Set `NO_COLOR=1` to disable all ANSI color output (compliant with [no-color.org](https://no-color.org)). `NO_COLOR` takes priority over `CLAUDE_STATUSLINE_THEME`.

```bash
export NO_COLOR=1
```

In no-color mode, the progress bar uses `=` and `.`, and separators use `|`.

### Available Widgets

Since v2.0.0, widgets are configurable via an interactive tool:

```bash
bash ~/.claude/configure.sh
```

| Widget | Description | Example |
|--------|-------------|---------|
| `model` | Model name | `Opus 4.6` |
| `bar` | Context progress bar | `[████████░░░░░░░░░░░░]` |
| `ctx` | Context usage percentage | `42%` |
| `tokens` | Token count | `85.2k tokens` |
| `cost` | Session cost | `$11.01` |
| `duration` | Session duration | `4h47m` |
| `lines` | Lines changed | `+538/-47` |
| `alert` | 200k token warning | `⚠ 200k` |
| `git` | Git branch name | ` main` |
| `project` | Project name | `my-project` |
| `version` | Claude Code version | `v2.1.76` |
| `vim` | Vim mode indicator | `[NORMAL]` |

Supports **two-line display**: widgets can be assigned to Line 1 or Line 2. Config saved to `~/.claude/statusline-widgets.conf`.

Without a config file, defaults to: `model | bar | ctx | tokens | git | project` (v1.x compatible).

### Icon Customization

Widget icons can be customized via the configure.sh TUI or by editing `~/.claude/statusline-icons.conf`:

```bash
# In the TUI:
> i              # Interactive picker — select by number
> i git          # Direct edit shortcut
> ir             # Reset all icons to defaults

# Or edit directly:
cat ~/.claude/statusline-icons.conf
```

| Key | Default | Description |
|-----|---------|-------------|
| `model` | (none) | Model name prefix |
| `ctx` | (none) | Context % prefix |
| `tokens` | (none) | Token count prefix |
| `cost` | (none) | Cost prefix |
| `duration` | (none) | Duration prefix |
| `lines` | (none) | Lines changed prefix |
| `alert` | `⚠` | Alert icon |
| `git` | `` | Git branch icon |
| `project` | (none) | Project name prefix |
| `version` | (none) | Version prefix |
| `rate_filled` | `●` | Rate limit filled dot |
| `rate_empty` | `○` | Rate limit empty dot |

Example config:

```
model=🤖
git=🔀
cost=💰
project=📁
rate_filled=🟢
rate_empty=⚪
```

Result: `🤖 Opus 4.6 │ 🔀 main │ 🟢🟢⚪⚪⚪ 42% 2h31m │ 💰 $3.52 │ 📁 my-project`

Only non-default values are saved. Changes take effect on the next statusline refresh (no restart needed).

### Additional Features

- **Context % Color**: Changes color by usage — ≤60% normal, 60-80% warning, >80% danger

### 12 Semantic Color Tokens

Each theme defines 12 semantic color tokens:

| Token | Purpose |
|-------|---------|
| `C_MODEL` | Model name |
| `C_BAR_FILL` | Progress bar filled |
| `C_BAR_EMPTY` | Progress bar empty |
| `C_CTX_OK` | Context % normal (≤60%) |
| `C_CTX_WARN` | Context % warning (60-80%) |
| `C_CTX_BAD` | Context % danger (>80%) |
| `C_TOKENS` | Token count |
| `C_COST` | Cost |
| `C_ALERT` | Alert message |
| `C_BRANCH` | Git branch |
| `C_PROJECT` | Project name |
| `C_SEP` | Separator |

## Manual Install

If you prefer manual installation:

```bash
# 1. Install jq
brew install jq          # macOS
sudo apt install -y jq   # Ubuntu/Debian
sudo yum install -y jq   # CentOS/RHEL

# 2. Create symlink (or copy)
mkdir -p ~/.claude
ln -sf "$(pwd)/statusline/statusline-command.sh" ~/.claude/statusline-command.sh

# 3. Configure Claude Code (merge statusLine block if settings.json already exists)
cat > ~/.claude/settings.json << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline-command.sh"
  }
}
EOF
```

## Dashboard (Multi-Instance Monitor)

Run in a separate terminal to monitor all active Claude Code sessions:

```bash
sh ~/.claude/dashboard.sh
```

```
Claude Code Dashboard  2026-03-03 17:58:58  (every 2s)

PID      PROJECT            MODEL         STATUS    CONTEXT                     CTX%  OUTPUT   BRANCH
------   ----------------   ------------  -------   ------------------------    ----  ------   ----------
730419   sonic_docs         Opus 4.6      WORKING   [████████░░░░░░░░░░░░░░░░]  21%   2.6k     master
  » Now I have everything I need. Let me write the final plan.
582572   laas_agent         Opus 4.6      WORKING   [████████░░░░░░░░░░░░░░░░]  34%   10.2k    main
26983    ubuntu             Opus 4.6      IDLE      [████░░░░░░░░░░░░░░░░░░░░]  14%   2.8k

────────────────────────────────────────────────────────────────────────────────
Instances: 3  Context: 128.4k  Output: 15.6k  Mem: 1.4G

Status:  WORKING  IDLE  WAITING  QUEUED   » text  → tool  « user
```

Updates every 2 seconds. Press `Ctrl+C` to exit.

**How it works:** Each time Claude Code invokes `statusline-command.sh`, session state is written to `~/.claude/sessions/<PID>.json`. The dashboard reads these files and aggregates the display.

## tmux Status Bar

The tmux integration shows a compact session overview on a second status bar line:

```
⚡my-project 42% │ 💤other-proj 14%
```

- `⚡` = WORKING (Claude is actively processing)
- `✅` = DONE (task just completed, auto-expires after 30s)
- `💤` = IDLE (Claude is waiting for input)

The ✅ DONE status requires the [hooks component](../hooks/README.md) (`notify-on-stop.sh`).

### How Real-Time Detection Works

Status detection uses **event-driven hooks** for instant updates:

| Event | Hook | Status Written |
|-------|------|---------------|
| User sends prompt | `UserPromptSubmit` | `working` |
| Tool call completes | `PostToolUse` | `working` |
| Claude finishes response | `Stop` | `idle` |

Hooks write a lightweight plain-text file (`~/.claude/sessions/<PID>.status`) — no JSON parsing needed, updates in ~5ms. tmux reads this file every 2 seconds for near-instant status display.

**File ownership model (no race conditions):**

| File | Sole Writer |
|------|-------------|
| `<PID>.json` | `statusline-command.sh` |
| `<PID>.status` | `status-hook.sh` (via hooks) |
| `<PID>.hb.dat` | `heartbeat.sh` |

For installations without hooks configured, the system falls back to token-based detection from the JSON file.

## Uninstall

```bash
bash statusline/uninstall.sh
```

Or manually:

```bash
# Remove scripts
rm ~/.claude/statusline-command.sh

# Remove statusLine config from settings.json
# Manually edit ~/.claude/settings.json and remove the statusLine block
# Or restore backup (if available):
cp ~/.claude/settings.json.backup ~/.claude/settings.json
```

## File Descriptions

| File | Description |
|------|-------------|
| `install.sh` | One-click installer (symlinks auto-update via `git pull`) |
| `uninstall.sh` | One-click uninstaller |
| `configure.sh` | Interactive widget & icon configurator (choose fields, lines, order, icons) |
| `statusline-command.sh` | Status line script (symlinked to `~/.claude/` after install) |
| `dashboard.sh` | Multi-instance dashboard (symlinked to `~/.claude/` after install) |
| `heartbeat.sh` | Heartbeat daemon, requires bash 4.2+ (symlinked to `~/.claude/` after install) |
| `tmux-sessions.sh` | tmux status bar segment (symlinked to `~/.claude/` after install) |
| `status-hook.sh` | Event-driven status hook (symlinked to `~/.claude/` after install) |
| `README.md` | This documentation (English) |
| `README.zh-TW.md` | Documentation (Traditional Chinese) |
