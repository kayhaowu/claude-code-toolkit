# GitHub Optimization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare claude-code-toolkit for public GitHub release — fix bugs, security issues, add proper open-source infrastructure, and internationalize documentation.

**Architecture:** 1 git history rewrite + 10 new sequential commits, each addressing one concern. Git history rewrite first, then infrastructure, bug fixes, and documentation. Shell scripts only (no new languages).

**Tech Stack:** Shell (POSIX sh), jq, git filter-repo, git

**Spec:** `docs/superpowers/specs/2026-03-13-github-optimization-design.md`

---

## Chunk 1: Git Infrastructure (Tasks 1–4)

### Task 1: Git History Rewrite

**Files:**
- No file changes — git operations only

**Prerequisites:** Install `git-filter-repo` if not available (`brew install git-filter-repo` or `pip install git-filter-repo`).

- [ ] **Step 1: Verify git-filter-repo is available**

Run: `git filter-repo --version`
Expected: version number printed. If not found, install it:
```bash
brew install git-filter-repo
```

- [ ] **Step 2: Create backup branch**

```bash
git branch backup/pre-rewrite
```

- [ ] **Step 3: Rewrite all commit authors**

```bash
git filter-repo --name-callback 'return b"kayhaowu"' --email-callback 'return b"ak0789456@gmail.com"' --force
```

- [ ] **Step 4: Verify rewrite**

Run: `git log --format="%an <%ae>" | sort -u`
Expected: only `kayhaowu <ak0789456@gmail.com>`

- [ ] **Step 5: Set local git config for future commits**

```bash
git config --local user.name "kayhaowu"
git config --local user.email "ak0789456@gmail.com"
```

- [ ] **Step 6: Add new GitHub remote**

`git filter-repo` removes remotes. Add the new one:
```bash
git remote add origin git@github.com:kayhaowu/claude-code-toolkit.git
```

- [ ] **Step 7: Verify remote and config**

Run: `git remote -v`
Expected: `origin  git@github.com:kayhaowu/claude-code-toolkit.git (fetch/push)`

Run: `git config --local user.name && git config --local user.email`
Expected: `kayhaowu` and `ak0789456@gmail.com`

---

### Task 2: Add `.gitignore`

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Create `.gitignore`**

```
.claude/
.DS_Store
*.swp
*.swo
*~
```

- [ ] **Step 2: Verify `.claude/` directory is ignored**

Run: `git status`
Expected: `.claude/` no longer appears as untracked. `.gitignore` appears as new file.

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

### Task 3: Add MIT LICENSE

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Create LICENSE file**

```
MIT License

Copyright (c) 2026 kayhaowu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT license"
```

---

### Task 4: Add Version Tracking

**Files:**
- Modify: `statusline/statusline-command.sh:1-7` (add version constant + `--version` flag before `input=$(cat)`)
- Modify: `statusline/install.sh:140-148` (display version on completion)

- [ ] **Step 1: Add version constant and `--version` check to `statusline-command.sh`**

Insert after the comment header (line 5), before `input=$(cat)` (line 7):

```sh
VERSION="1.0.0"
if [ "${1:-}" = "--version" ]; then echo "$VERSION"; exit 0; fi
```

The file should read:
```sh
#!/bin/sh
# Statusline with theme support
# Segments: model | [progress bar] | ctx% | tokens | cost | alert | git | project
# Themes: ansi-default, catppuccin-mocha, dracula, nord, none
# Set CLAUDE_STATUSLINE_THEME to choose theme. Set NO_COLOR=1 to disable colors.

VERSION="1.0.0"
if [ "${1:-}" = "--version" ]; then echo "$VERSION"; exit 0; fi

input=$(cat)
```

- [ ] **Step 2: Verify `--version` works**

Run: `echo "" | sh statusline/statusline-command.sh --version`
Expected: `1.0.0`

- [ ] **Step 3: Add version display to `install.sh`**

In `install.sh`, insert between line 142 (`success "Installation complete!"`) and line 143 (`info "Restart Claude Code..."`):

```sh
# Before (lines 142-143):
success "Installation complete!"
info "Restart Claude Code to activate the status line."
# After:
success "Installation complete!"
_installed_ver=$(sh "$TARGET_SCRIPT" --version 2>/dev/null || echo "unknown")
info "Version: $_installed_ver"
info "Restart Claude Code to activate the status line."
```

Or equivalently, just add these 2 lines after line 142:

```sh
_installed_ver=$(sh "$TARGET_SCRIPT" --version 2>/dev/null || echo "unknown")
info "Version: $_installed_ver"
```

- [ ] **Step 4: Commit**

```bash
git add statusline/statusline-command.sh statusline/install.sh
git commit -m "feat: add version tracking (v1.0.0) with --version flag"
```

---

## Chunk 2: Bug Fixes (Tasks 5–7)

### Task 5: Fix Cross-Platform Bug in `heartbeat.sh`

**Files:**
- Modify: `statusline/heartbeat.sh:35` (replace `readlink` call)

- [ ] **Step 1: Replace the `readlink` line**

In `statusline/heartbeat.sh`, replace line 35:

```sh
# Before:
    _cwd=$(readlink -f "/proc/$TARGET_PID/cwd" 2>/dev/null) || _cwd=""
# After:
    _cwd=$(readlink -f "/proc/$TARGET_PID/cwd" 2>/dev/null) \
        || _cwd=$(lsof -a -p "$TARGET_PID" -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-) \
        || _cwd=""
```

- [ ] **Step 2: Verify on macOS**

Run: `sh -c '_pid=$$; lsof -a -p "$_pid" -d cwd -Fn 2>/dev/null | grep "^n" | cut -c2-'`
Expected: prints current working directory path (confirms `lsof` fallback works on this machine)

- [ ] **Step 3: Commit**

```bash
git add statusline/heartbeat.sh
git commit -m "fix: add macOS fallback for cwd detection in heartbeat"
```

---

### Task 6: Fix awk Command Injection

**Files:**
- Modify: `statusline/statusline-command.sh:193-206` (3 awk calls)
- Modify: `statusline/dashboard.sh:33-47` (4 awk calls)

- [ ] **Step 1: Fix `statusline-command.sh` — `tokens_str` (line 194)**

```sh
# Before:
    tokens_str=$(awk "BEGIN { printf \"%.1fk\", $tokens_used/1000 }")
# After:
    tokens_str=$(awk -v n="$tokens_used" 'BEGIN { printf "%.1fk", n/1000 }')
```

- [ ] **Step 2: Fix `statusline-command.sh` — `_show_cost` (line 204)**

```sh
# Before:
        _show_cost=$(awk "BEGIN { print ($cost_usd >= 0.005) ? 1 : 0 }")
# After:
        _show_cost=$(awk -v c="$cost_usd" 'BEGIN { print (c >= 0.005) ? 1 : 0 }')
```

- [ ] **Step 3: Fix `statusline-command.sh` — `cost_str` (line 206)**

```sh
# Before:
            cost_str=$(awk "BEGIN { printf \"est \$%.2f\", $cost_usd }")
# After:
            cost_str=$(awk -v c="$cost_usd" 'BEGIN { printf "est $%.2f", c }')
```

- [ ] **Step 4: Fix `dashboard.sh` — `fmt_k()` (lines 34, 36)**

```sh
# Before:
fmt_k() {
    n="$1"
    if [ "$n" -ge 1000000 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1fM\",$n/1000000}"
    elif [ "$n" -ge 1000 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1fk\",$n/1000}"
    else
        printf '%s' "$n"
    fi
}
# After:
fmt_k() {
    n="$1"
    if [ "$n" -ge 1000000 ] 2>/dev/null; then
        awk -v v="$n" 'BEGIN{printf "%.1fM",v/1000000}'
    elif [ "$n" -ge 1000 ] 2>/dev/null; then
        awk -v v="$n" 'BEGIN{printf "%.1fk",v/1000}'
    else
        printf '%s' "$n"
    fi
}
```

- [ ] **Step 5: Fix `dashboard.sh` — `fmt_mem()` (lines 45, 47)**

```sh
# Before:
fmt_mem() {
    kb="$1"
    if [ "$kb" -ge 1048576 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1fG\",$kb/1048576}"
    elif [ "$kb" -ge 1024 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1fM\",$kb/1024}"
    else
        printf '%s' "${kb}K"
    fi
}
# After:
fmt_mem() {
    kb="$1"
    if [ "$kb" -ge 1048576 ] 2>/dev/null; then
        awk -v v="$kb" 'BEGIN{printf "%.1fG",v/1048576}'
    elif [ "$kb" -ge 1024 ] 2>/dev/null; then
        awk -v v="$kb" 'BEGIN{printf "%.1fM",v/1024}'
    else
        printf '%s' "${kb}K"
    fi
}
```

- [ ] **Step 6: Verify no remaining unsafe awk interpolation**

Run: `grep -n 'awk "BEGIN' statusline/statusline-command.sh statusline/dashboard.sh`
Expected: no output (all unsafe patterns replaced)

- [ ] **Step 7: Commit**

```bash
git add statusline/statusline-command.sh statusline/dashboard.sh
git commit -m "security: fix awk command injection in statusline and dashboard"
```

---

### Task 7: Fix `install.sh` Hooks Overwrite

**Files:**
- Modify: `statusline/install.sh:96-122` (replace the settings merge section)

- [ ] **Step 1: Replace the settings merge logic**

Replace the entire `Step 5: Merge settings.json` section (lines 96–122) with:

```sh
# ── Step 5: Merge settings.json ──────────────────────────────────────────────
STATUSLINE_CONFIG='{"type":"command","command":"sh ~/.claude/statusline-command.sh"}'
HB_START_CMD='nohup sh ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &'
HB_STOP_CMD="sh -c 'kill \$(cat ~/.claude/sessions/\$PPID.hb.pid 2>/dev/null) 2>/dev/null; rm -f ~/.claude/sessions/\$PPID.json ~/.claude/sessions/\$PPID.hb.dat ~/.claude/sessions/\$PPID.hb.pid'"

if [ -f "$SETTINGS_FILE" ]; then
    info "Backing up existing settings.json to $SETTINGS_BACKUP..."
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"
    info "Merging statusLine into existing settings.json..."
else
    info "Creating $SETTINGS_FILE..."
    echo '{}' > "$SETTINGS_FILE"
fi

# Merge statusLine key
SETTINGS_TMP="${SETTINGS_FILE}.tmp"
jq --argjson sl "$STATUSLINE_CONFIG" '.statusLine = $sl' "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"

# Append hooks (skip if already present)
_has_hb_start=$(jq -r '(.hooks.SessionStart // [])[] | .hooks[]? | .command // "" | test("heartbeat\\.sh")' "$SETTINGS_FILE" 2>/dev/null | grep -c true || true)
if [ "$_has_hb_start" -eq 0 ]; then
    jq --arg cmd "$HB_START_CMD" '
        .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$cmd}]}])
    ' "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
    info "SessionStart hook added."
else
    info "SessionStart hook already exists, skipping."
fi

_has_hb_stop=$(jq -r '(.hooks.SessionEnd // [])[] | .hooks[]? | .command // "" | test("sessions/\\$PPID")' "$SETTINGS_FILE" 2>/dev/null | grep -c true || true)
if [ "$_has_hb_stop" -eq 0 ]; then
    jq --arg cmd "$HB_STOP_CMD" '
        .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"hooks":[{"type":"command","command":$cmd}]}])
    ' "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
    info "SessionEnd hook added."
else
    info "SessionEnd hook already exists, skipping."
fi

if [ -f "$SETTINGS_BACKUP" ]; then
    success "Settings merged. Original backed up to $SETTINGS_BACKUP"
else
    success "Settings file created."
fi
```

- [ ] **Step 2: Test fresh install (no existing settings)**

```bash
# Simulate: create temp dir, run the jq logic
_tmp=$(mktemp -d)
echo '{}' > "$_tmp/settings.json"
jq --argjson sl '{"type":"command","command":"sh ~/.claude/statusline-command.sh"}' '.statusLine = $sl' "$_tmp/settings.json" > "$_tmp/s2.json"
cat "$_tmp/s2.json"
rm -rf "$_tmp"
```
Expected: JSON with `statusLine` key present.

- [ ] **Step 3: Test with existing hooks (should append, not overwrite)**

```bash
_tmp=$(mktemp -d)
cat > "$_tmp/settings.json" << 'TESTEOF'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo hello"}]}]}}
TESTEOF
_cmd='nohup sh ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &'
jq --arg cmd "$_cmd" '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$cmd}]}])' "$_tmp/settings.json"
rm -rf "$_tmp"
```
Expected: `SessionStart` array has 2 entries — original `echo hello` AND heartbeat hook.

- [ ] **Step 4: Test reinstall (should skip duplicate)**

```bash
_tmp=$(mktemp -d)
cat > "$_tmp/settings.json" << 'TESTEOF'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"nohup sh ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &"}]}]}}
TESTEOF
_has=$(jq -r '(.hooks.SessionStart // [])[] | .hooks[]? | .command // "" | test("heartbeat\\.sh")' "$_tmp/settings.json" 2>/dev/null | grep -c true || true)
echo "has_heartbeat: $_has"
rm -rf "$_tmp"
```
Expected: `has_heartbeat: 1` (detection works, skip logic triggered)

- [ ] **Step 5: Commit**

```bash
git add statusline/install.sh
git commit -m "fix: append hooks instead of overwriting user's existing hooks"
```

---

## Chunk 3: Uninstall Script (Task 8)

### Task 8: Create `statusline/uninstall.sh`

**Files:**
- Create: `statusline/uninstall.sh`

- [ ] **Step 1: Create the uninstall script**

```sh
#!/bin/sh
# Uninstaller for Claude Code status line toolkit
# Usage: bash statusline/uninstall.sh
set -e

CLAUDE_DIR="$HOME/.claude"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# ── Color output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
removed() { printf "${GREEN}[REMOVED]${NC}  %s\n" "$1"; }
skipped() { printf "${YELLOW}[SKIPPED]${NC}  %s\n" "$1"; }

# ── Step 1: Kill running heartbeat daemons ────────────────────────────────────
info "Stopping heartbeat daemons..."
_killed=0
for pidfile in "$SESSIONS_DIR"/*.hb.pid; do
    [ -f "$pidfile" ] || continue
    _hb_pid=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$_hb_pid" ] && kill -0 "$_hb_pid" 2>/dev/null; then
        kill "$_hb_pid" 2>/dev/null && removed "heartbeat process $_hb_pid"
        _killed=$(( _killed + 1 ))
    fi
    rm -f "$pidfile"
done
[ "$_killed" -eq 0 ] && skipped "No running heartbeat daemons found"

# ── Step 2: Clean session files ───────────────────────────────────────────────
info "Cleaning session files..."
_cleaned=0
for pattern in "$SESSIONS_DIR"/*.json "$SESSIONS_DIR"/*.hb.dat "$SESSIONS_DIR"/*.hb.pid; do
    for f in $pattern; do
        [ -f "$f" ] || continue
        rm -f "$f"
        _cleaned=$(( _cleaned + 1 ))
    done
done
if [ "$_cleaned" -gt 0 ]; then
    removed "$_cleaned session file(s)"
else
    skipped "No session files found"
fi

# ── Step 3: Remove installed scripts ──────────────────────────────────────────
info "Removing installed scripts..."
for script in statusline-command.sh statusline.sh dashboard.sh heartbeat.sh tmux-sessions.sh; do
    target="$CLAUDE_DIR/$script"
    if [ -f "$target" ] || [ -L "$target" ]; then
        rm -f "$target"
        removed "$target"
    else
        skipped "$target (not found)"
    fi
done

# ── Step 4: Clean settings.json ───────────────────────────────────────────────
if [ -f "$SETTINGS_FILE" ]; then
    info "Cleaning settings.json..."
    SETTINGS_TMP="${SETTINGS_FILE}.tmp"

    # Remove statusLine key
    if jq -e '.statusLine' "$SETTINGS_FILE" > /dev/null 2>&1; then
        jq 'del(.statusLine)' "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
        removed "statusLine config"
    else
        skipped "statusLine config (not found)"
    fi

    # Remove our hooks from SessionStart (entries containing heartbeat.sh)
    if jq -e '.hooks.SessionStart' "$SETTINGS_FILE" > /dev/null 2>&1; then
        jq '.hooks.SessionStart = [.hooks.SessionStart[] | select((.hooks // []) | all(.command // "" | test("heartbeat\\.sh") | not))]' \
            "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
        # Remove empty SessionStart array
        jq 'if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end' \
            "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
        removed "SessionStart hook"
    else
        skipped "SessionStart hook (not found)"
    fi

    # Remove our hooks from SessionEnd (entries containing sessions/$PPID)
    if jq -e '.hooks.SessionEnd' "$SETTINGS_FILE" > /dev/null 2>&1; then
        jq '.hooks.SessionEnd = [.hooks.SessionEnd[] | select((.hooks // []) | all(.command // "" | test("sessions/\\$PPID") | not))]' \
            "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
        # Remove empty SessionEnd array
        jq 'if (.hooks.SessionEnd | length) == 0 then del(.hooks.SessionEnd) else . end' \
            "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
        removed "SessionEnd hook"
    else
        skipped "SessionEnd hook (not found)"
    fi

    # Remove empty hooks object
    jq 'if (.hooks // {} | length) == 0 then del(.hooks) else . end' \
        "$SETTINGS_FILE" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
else
    skipped "settings.json (not found)"
fi

# ── Step 5: tmux suggestion ──────────────────────────────────────────────────
echo ""
info "If you were using tmux integration, run:"
info "  tmux set-option -g status 1"
info "  tmux set-option -gu status-format[1]"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
printf "${GREEN}[DONE]${NC}  Uninstall complete.\n"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x statusline/uninstall.sh
```

- [ ] **Step 3: Commit**

```bash
git add statusline/uninstall.sh
git commit -m "feat: add uninstall script"
```

---

## Chunk 4: Doc Cleanup (Tasks 9–10)

### Task 9: Redirect `claude-code-statusline-setup.md`

**Files:**
- Modify: `claude-code-statusline-setup.md` (replace entire content)

- [ ] **Step 1: Replace content with redirect**

```markdown
# Claude Code Status Line Setup

This guide has moved to [`statusline/README.md`](statusline/README.md).
```

- [ ] **Step 2: Commit**

```bash
git add claude-code-statusline-setup.md
git commit -m "docs: redirect legacy setup guide to statusline/README.md"
```

---

### Task 10: Add `docs/plans/README.md`

**Files:**
- Create: `docs/plans/README.md`

- [ ] **Step 1: Create the file**

```markdown
# Development Plans

Internal design documents and implementation plans created during development.
These are preserved as historical reference and are not required for using the toolkit.
```

- [ ] **Step 2: Commit**

```bash
git add docs/plans/README.md
git commit -m "docs: add README explaining plans directory is historical reference"
```

---

## Chunk 5: README Internationalization (Task 11)

### Task 11: English README + Chinese `.zh-TW.md`

**Files:**
- Modify: `README.md` (rewrite in English)
- Create: `README.zh-TW.md` (current Chinese content + language switcher)
- Modify: `statusline/README.md` (rewrite in English)
- Create: `statusline/README.zh-TW.md` (current Chinese content + language switcher)

- [ ] **Step 1: Copy current `README.md` to `README.zh-TW.md`**

Copy the current Chinese content, then prepend the language switcher:
```markdown
[English](README.md) | [繁體中文](README.zh-TW.md)

```
Followed by the existing Chinese content from `README.md`.

- [ ] **Step 2: Copy current `statusline/README.md` to `statusline/README.zh-TW.md`**

Copy the current Chinese content, then prepend the language switcher:
```markdown
[English](README.md) | [繁體中文](README.zh-TW.md)

```
Followed by the existing Chinese content from `statusline/README.md`.

- [ ] **Step 3: Rewrite `README.md` in English**

```markdown
# Claude Code Toolkit

[English](README.md) | [繁體中文](README.zh-TW.md)

> A collection of tools and utilities for enhancing the Claude Code CLI experience.

## Features

- **Custom status line** — model name, context usage bar, token count, estimated cost, git branch, and project name
- **5 color themes** — ansi-default, catppuccin-mocha, dracula, nord, none (+ NO_COLOR support)
- **Multi-instance dashboard** — live terminal view of all active Claude Code sessions
- **tmux integration** — real-time session monitor on tmux status bar
- **One-click installer** — supports macOS, Ubuntu/Debian, CentOS/RHEL

```
Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │  main │ my-project
```

## Quick Start

```bash
bash statusline/install.sh
```

Restart Claude Code after installation to activate the status line.

### System Requirements

| System | Requirement |
|--------|-------------|
| macOS | [Homebrew](https://brew.sh) |
| Ubuntu / Debian | sudo access |
| CentOS / RHEL | sudo access |

## Themes

Set the theme via the `CLAUDE_STATUSLINE_THEME` environment variable in your shell config (`~/.zshrc` or `~/.bashrc`):

```bash
export CLAUDE_STATUSLINE_THEME="catppuccin-mocha"
```

| Theme | Description | Color Type |
|-------|-------------|------------|
| `ansi-default` | Default theme using standard ANSI colors | 4-bit ANSI |
| `catppuccin-mocha` | Catppuccin Mocha palette, soft pastel style | 24-bit TrueColor |
| `dracula` | Dracula theme, high-contrast dark style | 24-bit TrueColor |
| `nord` | Nord theme, arctic blue tones | 24-bit TrueColor |
| `none` | No colors, plain text output | None |

## Dashboard

Monitor all active Claude Code sessions in a separate terminal:

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
```

Updates every 2 seconds. Press `Ctrl+C` to exit.

## tmux Integration

If you run the installer inside a tmux session, the session monitor is configured automatically. For manual setup:

```bash
tmux set-option -g status 2
tmux set-option -g status-format[1] "#[align=left,fg=#bd93f9,bg=#282a36] Claude: #(sh ~/.claude/tmux-sessions.sh)"
tmux set-option -g status-interval 2
```

## Configuration

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `CLAUDE_STATUSLINE_THEME` | Color theme | `ansi-default` |
| `CLAUDE_STATUSLINE_SHOW_COST` | Show estimated API cost (`1` to enable) | `0` (off) |
| `NO_COLOR` | Disable all ANSI colors ([no-color.org](https://no-color.org)) | unset |

## Uninstall

```bash
bash statusline/uninstall.sh
```

See [`statusline/README.md`](statusline/README.md) for manual uninstall steps.

## Contributing

Issues and pull requests are welcome. Please describe the change and its motivation.

## License

[MIT](LICENSE)
```

- [ ] **Step 4: Rewrite `statusline/README.md` in English**

Translate the current Chinese `statusline/README.md` content to English, preserving all technical details (themes table, semantic color tokens, manual install steps, dashboard section, file descriptions). Add language switcher at top. Keep the same structure and sections.

Key sections to include:
- Quick Install
- Install Process (what the script does)
- Themes (with config examples, NO_COLOR support, 12 semantic tokens table)
- Additional Segments (Cost, 200k Alert, Context % color)
- Manual Install
- Dashboard
- Uninstall (reference uninstall.sh + manual steps)
- File Descriptions table

- [ ] **Step 5: Verify all links work**

Check that these relative links resolve correctly:
- `README.md` ↔ `README.zh-TW.md`
- `statusline/README.md` ↔ `statusline/README.zh-TW.md`
- `README.md` → `statusline/README.md`
- `README.md` → `LICENSE`

- [ ] **Step 6: Commit**

```bash
git add README.md README.zh-TW.md statusline/README.md statusline/README.zh-TW.md
git commit -m "docs: internationalize READMEs (English + Traditional Chinese)"
```

---

## Post-Implementation

After all 11 tasks are complete:

- [ ] **Verify final state**: `git log --oneline` should show 10 new commits on top of the rewritten history, all with author `kayhaowu`
- [ ] **Verify no sensitive files**: `git ls-files` should not include `.env`, credentials, or `.claude/` directory
- [ ] **Do NOT push yet** — user will review and push manually
