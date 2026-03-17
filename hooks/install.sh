#!/bin/sh
# One-click installer for Claude Code hooks collection
# Supports: macOS, Debian/Ubuntu, CentOS/RHEL
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SETTINGS_BACKUP="$CLAUDE_DIR/settings.json.backup"

# ── Color output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1" >&2; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; exit 1; }
success() { printf "${GREEN}[DONE]${NC}  %s\n" "$1"; }

# ── Quick relink mode ─────────────────────────────────────────────────────────
# Usage: bash hooks/install.sh --relink
# Repairs broken symlinks after moving the toolkit folder.
if [ "$1" = "--relink" ]; then
    info "Relinking hooks to $SCRIPT_DIR..."
    _fixed=0
    _ok=0
    for script in safety-guard.sh sensitive-files.sh auto-format.sh \
                  notify-on-stop.sh context-alert.sh usage-logger.sh; do
        _target="$HOOKS_DIR/$script"
        if [ -L "$_target" ]; then
            if [ -e "$_target" ]; then
                _ok=$((_ok + 1))
            else
                ln -sf "$SCRIPT_DIR/$script" "$_target"
                _fixed=$((_fixed + 1))
            fi
        fi
    done
    if [ "$_fixed" -gt 0 ]; then
        success "Fixed $_fixed broken symlink(s). $_ok already OK."
    elif [ "$_ok" -gt 0 ]; then
        info "All $_ok symlink(s) already point to correct location."
    else
        warn "No symlinks found. Run a full install first: bash $SCRIPT_DIR/install.sh"
        exit 1
    fi
    exit 0
fi

# ── Step 1: Check statusline ─────────────────────────────────────────────────
_has_statusline=0
if [ -f "$CLAUDE_DIR/statusline-command.sh" ]; then
    _has_statusline=1
    info "Statusline detected. All hooks available."
else
    warn "Statusline not installed. usage-logger, context-alert, and notify-on-stop tmux feature will be limited."
    info "For full hook support, install statusline first: bash statusline/install.sh"
fi

# ── Step 2: Ensure jq is installed ───────────────────────────────────────────
info "Checking for jq..."
if ! command -v jq >/dev/null 2>&1; then
    info "jq not found. Installing..."
    OS=""
    if [ "$(uname)" = "Darwin" ]; then
        OS="macos"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
        OS="rhel"
    else
        error "Unsupported OS. Please install jq manually and re-run."
    fi
    case "$OS" in
        macos)
            command -v brew >/dev/null 2>&1 || error "Homebrew not found. Please install Homebrew first: https://brew.sh"
            brew install jq
            ;;
        debian) sudo apt-get update -qq && sudo apt-get install -y jq ;;
        rhel)   sudo yum install -y jq ;;
    esac
    success "jq installed."
else
    info "jq already installed: $(jq --version)"
fi

# ── Step 3: Create symlinks ──────────────────────────────────────────────────
# Use symbolic links so that `git pull` automatically updates installed hooks.
# Skip files that already exist and are NOT our symlinks (user's own scripts).
info "Creating symlinks in $HOOKS_DIR..."
mkdir -p "$HOOKS_DIR" "$HOOKS_DIR/sessions"

_skipped=""
for script in safety-guard.sh sensitive-files.sh auto-format.sh \
              notify-on-stop.sh context-alert.sh usage-logger.sh; do
    _target="$HOOKS_DIR/$script"
    if [ -e "$_target" ] && [ ! -L "$_target" ]; then
        warn "Skipped: $_target already exists (not a symlink)."
        _skipped="${_skipped} ${script}"
    else
        ln -sf "$SCRIPT_DIR/$script" "$_target"
    fi
done
if [ -n "$_skipped" ]; then
    warn "Skipped:${_skipped}. Remove them and re-run install.sh to overwrite."
else
    success "Hook scripts linked to $HOOKS_DIR"
fi

# ── Step 4: Hook selection ────────────────────────────────────────────────────
_install_recommended=1
_install_optional=0

printf '\n'
printf 'Install recommended hooks? [Y/n]\n'
printf '  - notify-on-stop     Desktop notification when Claude finishes\n'
printf '  - safety-guard       Block dangerous commands (rm -rf, force push, etc.)\n'
printf '  - sensitive-files    Block access to .env, credentials, *.key files\n'
printf '> '
read -r _answer
case "$_answer" in
    [Nn]*) _install_recommended=0 ;;
esac

printf '\n'
printf 'Also enable optional hooks? [y/N]\n'
printf '  - auto-format        Auto-format files after edit (detects prettier/black/gofmt)\n'
printf '  - usage-logger       Log session usage to ~/.claude/hooks/usage.jsonl\n'
printf '  - context-alert      Warn when context usage exceeds 80%%\n'
printf '> '
read -r _answer
case "$_answer" in
    [Yy]*) _install_optional=1 ;;
esac

# ── Step 5: Backup settings.json ─────────────────────────────────────────────
if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"
    info "Backed up settings.json to $SETTINGS_BACKUP"
else
    echo '{}' > "$SETTINGS_FILE"
    info "Created $SETTINGS_FILE"
fi

# ── Step 6: Merge hooks into settings.json ────────────────────────────────────
SETTINGS_TMP="${SETTINGS_FILE}.tmp"

# Build jq filter dynamically based on selection
_jq_filter='.'

# Recommended hooks
if [ "$_install_recommended" = "1" ]; then
    # safety-guard (PreToolUse: Bash)
    _jq_filter="$_jq_filter"'
    | if ([(.hooks.PreToolUse // [])[] | .hooks[]? | .command // ""] | any(test("hooks/safety-guard"))) then .
      else .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher":"Bash","hooks":[{"type":"command","command":"sh ~/.claude/hooks/safety-guard.sh"}]}])
      end'

    # sensitive-files (PreToolUse: Read|Edit|Write)
    _jq_filter="$_jq_filter"'
    | if ([(.hooks.PreToolUse // [])[] | .hooks[]? | .command // ""] | any(test("hooks/sensitive-files"))) then .
      else .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher":"Read|Edit|Write","hooks":[{"type":"command","command":"sh ~/.claude/hooks/sensitive-files.sh"}]}])
      end'

    # notify-on-stop (Stop)
    _jq_filter="$_jq_filter"'
    | if ([(.hooks.Stop // [])[] | .hooks[]? | .command // ""] | any(test("hooks/notify-on-stop"))) then .
      else .hooks.Stop = ((.hooks.Stop // []) + [{"hooks":[{"type":"command","command":"sh ~/.claude/hooks/notify-on-stop.sh $PPID"}]}])
      end'
fi

# Optional hooks
if [ "$_install_optional" = "1" ]; then
    # auto-format (PostToolUse: Edit|Write)
    _jq_filter="$_jq_filter"'
    | if ([(.hooks.PostToolUse // [])[] | .hooks[]? | .command // ""] | any(test("hooks/auto-format"))) then .
      else .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{"matcher":"Edit|Write","hooks":[{"type":"command","command":"sh ~/.claude/hooks/auto-format.sh"}]}])
      end'

    # usage-logger (SessionStart + SessionEnd)
    # Installs regardless of statusline — gracefully degrades without it
    _jq_filter="$_jq_filter"'
    | if ([(.hooks.SessionStart // [])[] | .hooks[]? | .command // ""] | any(test("hooks/usage-logger"))) then .
      else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":"sh ~/.claude/hooks/usage-logger.sh start $PPID"}]}])
      end
    | if ([(.hooks.SessionEnd // [])[] | .hooks[]? | .command // ""] | any(test("hooks/usage-logger"))) then .
      else .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"hooks":[{"type":"command","command":"sh ~/.claude/hooks/usage-logger.sh end $PPID"}]}])
      end'

    # context-alert (Stop) — requires statusline
    if [ "$_has_statusline" = "1" ]; then
        _jq_filter="$_jq_filter"'
        | if ([(.hooks.Stop // [])[] | .hooks[]? | .command // ""] | any(test("hooks/context-alert"))) then .
          else .hooks.Stop = ((.hooks.Stop // []) + [{"hooks":[{"type":"command","command":"sh ~/.claude/hooks/context-alert.sh $PPID"}]}])
          end'
    else
        warn "Skipping context-alert (requires statusline for session data)"
    fi
fi

# Step 7: Stop array ordering enforcement
_jq_filter="$_jq_filter"'
| if .hooks.Stop then
    .hooks.Stop = (
      [.hooks.Stop[] | select((.hooks // [])[] | .command // "" | test("status-hook"))] +
      [.hooks.Stop[] | select((.hooks // [])[] | .command // "" | test("hooks/notify-on-stop"))] +
      [.hooks.Stop[] | select((.hooks // [])[] | .command // "" | test("hooks/context-alert"))] +
      [.hooks.Stop[] | select((.hooks // [])[] | .command // "" | (test("status-hook|hooks/notify-on-stop|hooks/context-alert") | not))]
    )
  else . end'

jq "$_jq_filter" "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
success "settings.json updated with hook entries."

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
success "Installation complete!"
echo ""
if [ "$_install_recommended" = "1" ]; then
    info "Enabled: notify-on-stop, safety-guard, sensitive-files"
fi
if [ "$_install_optional" = "1" ]; then
    info "Enabled: auto-format, usage-logger, context-alert"
fi
echo ""
info "Restart Claude Code to activate hooks."
info "To uninstall: bash hooks/uninstall.sh"
