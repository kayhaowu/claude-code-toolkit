[English](README.md) | [繁體中文](README.zh-TW.md)

# Claude Code Status Line

Custom status line for the Claude Code CLI, displaying model name, context usage, token count, estimated cost, git branch, and project name. Supports 5 color themes.

```
Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │ est $0.12 │  main │ my-project
 purple         green/gray          yellow    cyan           yellow     blue      green
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
3. Copies scripts to `~/.claude/`
4. Updates `~/.claude/settings.json` (auto-backs up existing settings)

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

### Additional Segments

- **Cost**: Shows estimated API cost `est $X.XX`, **off by default** (not needed for subscription users). API billing users can enable with `export CLAUDE_STATUSLINE_SHOW_COST=1`
- **200k Alert**: Displays `⚠ 200k` when token count exceeds 200k
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

# 2. Copy scripts
mkdir -p ~/.claude
cp statusline/statusline-command.sh ~/.claude/
chmod +x ~/.claude/statusline-command.sh

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
| `install.sh` | One-click installer (re-run to upgrade to latest version) |
| `uninstall.sh` | One-click uninstaller |
| `statusline-command.sh` | Status line script (copied to `~/.claude/` after install) |
| `dashboard.sh` | Multi-instance dashboard (copied to `~/.claude/` after install) |
| `heartbeat.sh` | Heartbeat daemon (copied to `~/.claude/` after install) |
| `tmux-sessions.sh` | tmux status bar segment (copied to `~/.claude/` after install) |
| `README.md` | This documentation (English) |
| `README.zh-TW.md` | Documentation (Traditional Chinese) |
