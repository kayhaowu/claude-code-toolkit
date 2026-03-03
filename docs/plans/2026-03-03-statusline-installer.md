# Status Line Installer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a one-click installer for Claude Code status line, organized in `statusline/` directory with multi-platform support and safe settings.json merging.

**Architecture:** Three-file structure: `install.sh` orchestrates the install flow (OS detection → jq install → file copy → settings merge), `statusline-command.sh` is the standalone status line template, and `README.md` documents usage. The installer reads from the local template file rather than embedding the script inline.

**Tech Stack:** POSIX shell (sh), jq (JSON merging), brew/apt/yum (package managers)

---

### Task 1: Create `statusline/statusline-command.sh`

**Files:**
- Create: `statusline/statusline-command.sh`

**Step 1: Create the statusline script template**

Create `statusline/statusline-command.sh` with the following content (extracted from `claude-code-statusline-setup.md`):

```sh
#!/bin/sh
# Status line: model | progress bar | % used | tokens used | git branch | project name

input=$(cat)

# ANSI color codes
RESET='\033[0m'

# Segment colors
COLOR_MODEL='\033[35m'       # Purple/violet  (model name)
COLOR_BAR_FILL='\033[32m'    # Green          (filled bar blocks)
COLOR_BAR_EMPTY='\033[90m'   # Dark gray      (empty bar blocks)
COLOR_PCT='\033[33m'         # Yellow/amber   (percentage)
COLOR_TOKENS='\033[36m'      # Cyan           (tokens)
COLOR_BRANCH='\033[34m'      # Blue           (git branch)
COLOR_PROJECT='\033[32m'     # Green          (project name)

SEP=' \033[2;37m│\033[0m '

# 1. Model name
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')

# 2. Context window data for progress bar and percentage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
tokens_used=$(( total_input + total_output ))

# Build two-tone progress bar (20 chars wide) and percentage string
if [ -n "$used_pct" ]; then
    pct_int=$(printf "%.0f" "$used_pct")
    filled=$(( pct_int * 20 / 100 ))
    empty=$(( 20 - filled ))

    filled_bar=""
    i=0
    while [ $i -lt $filled ]; do
        filled_bar="${filled_bar}█"
        i=$(( i + 1 ))
    done

    empty_bar=""
    i=0
    while [ $i -lt $empty ]; do
        empty_bar="${empty_bar}░"
        i=$(( i + 1 ))
    done

    pct_str="${pct_int}%"
else
    filled_bar=""
    empty_bar="░░░░░░░░░░░░░░░░░░░░"
    pct_str="0%"
fi

# 4. Tokens used (formatted with k suffix if >= 1000)
if [ "$tokens_used" -ge 1000 ] 2>/dev/null; then
    tokens_str=$(awk "BEGIN { printf \"%.1fk\", $tokens_used/1000 }")
else
    tokens_str="${tokens_used}"
fi

# 5. Git branch (from project_dir, skip optional locks)
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // ""')
git_branch=""
if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
    git_branch=$(git -C "$project_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# 6. Project name (basename of project_dir)
if [ -n "$project_dir" ]; then
    project_name=$(basename "$project_dir")
else
    project_name=$(basename "$(pwd)")
fi

# Assemble the status line with colors
printf "${COLOR_MODEL}${model}${RESET}"
printf "${SEP}"
printf "[${COLOR_BAR_FILL}${filled_bar}${COLOR_BAR_EMPTY}${empty_bar}${RESET}]"
printf "${SEP}"
printf "${COLOR_PCT}${pct_str}${RESET}"
printf "${SEP}"
printf "${COLOR_TOKENS}${tokens_str} tokens${RESET}"
if [ -n "$git_branch" ]; then
    printf "${SEP}"
    printf "${COLOR_BRANCH} ${git_branch}${RESET}"
fi
printf "${SEP}"
printf "${COLOR_PROJECT}${project_name}${RESET}"
printf "\n"
```

**Step 2: Set executable permission**

```bash
chmod +x statusline/statusline-command.sh
```

**Step 3: Commit**

```bash
git add statusline/statusline-command.sh
git commit -m "feat: add statusline-command.sh template"
```

---

### Task 2: Create `statusline/install.sh`

**Files:**
- Create: `statusline/install.sh`

**Step 1: Create install.sh**

Create `statusline/install.sh` with the following content:

```sh
#!/bin/sh
# One-click installer for Claude Code status line
# Supports: macOS, Debian/Ubuntu, CentOS/RHEL
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET_SCRIPT="$CLAUDE_DIR/statusline-command.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SETTINGS_BACKUP="$CLAUDE_DIR/settings.json.backup"

# ── Color output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; exit 1; }
success() { printf "${GREEN}[DONE]${NC}  %s\n" "$1"; }

# ── Step 1: Detect OS ─────────────────────────────────────────────────────────
info "Detecting operating system..."
OS=""
if [ "$(uname)" = "Darwin" ]; then
    OS="macos"
elif [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
    OS="rhel"
else
    warn "Unrecognized OS. Please install 'jq' manually and re-run this script."
    error "Unsupported OS"
fi
info "Detected: $OS"

# ── Step 2: Ensure jq is installed ───────────────────────────────────────────
info "Checking for jq..."
if ! command -v jq >/dev/null 2>&1; then
    info "jq not found. Installing..."
    case "$OS" in
        macos)
            if ! command -v brew >/dev/null 2>&1; then
                error "Homebrew not found. Please install Homebrew first: https://brew.sh"
            fi
            brew install jq
            ;;
        debian)
            sudo apt-get update -qq && sudo apt-get install -y jq
            ;;
        rhel)
            sudo yum install -y jq
            ;;
    esac
    success "jq installed."
else
    info "jq already installed: $(jq --version)"
fi

# ── Step 3: Create ~/.claude directory ───────────────────────────────────────
info "Creating $CLAUDE_DIR if needed..."
mkdir -p "$CLAUDE_DIR"

# ── Step 4: Copy statusline-command.sh ───────────────────────────────────────
info "Installing statusline-command.sh to $CLAUDE_DIR..."
cp "$SCRIPT_DIR/statusline-command.sh" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
success "Copied to $TARGET_SCRIPT"

# ── Step 5: Merge settings.json ──────────────────────────────────────────────
STATUS_LINE_CONFIG='{"statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"}}'

if [ -f "$SETTINGS_FILE" ]; then
    info "Backing up existing settings.json to $SETTINGS_BACKUP..."
    cp "$SETTINGS_FILE" "$SETTINGS_BACKUP"
    info "Merging statusLine into existing settings.json..."
    jq '. * {"statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"}}' \
        "$SETTINGS_BACKUP" > "$SETTINGS_FILE"
    success "Settings merged. Original backed up to $SETTINGS_BACKUP"
else
    info "Creating $SETTINGS_FILE..."
    printf '%s\n' "$STATUS_LINE_CONFIG" | jq '.' > "$SETTINGS_FILE"
    success "Settings file created."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "Installation complete!"
info "Restart Claude Code to activate the status line."
echo ""
info "To customize colors, edit: $TARGET_SCRIPT"
info "To uninstall, see: $SCRIPT_DIR/README.md"
```

**Step 2: Set executable permission**

```bash
chmod +x statusline/install.sh
```

**Step 3: Commit**

```bash
git add statusline/install.sh
git commit -m "feat: add one-click install.sh with multi-platform support"
```

---

### Task 3: Create `statusline/README.md`

**Files:**
- Create: `statusline/README.md`

**Step 1: Create README.md**

Create `statusline/README.md` with the following content:

```markdown
# Claude Code Status Line

自訂 Claude Code 底部狀態列，顯示模型、Context 使用量、Token 數、Git 分支與專案名稱。

```
Claude Sonnet 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │  main │ my-project
     紫色                  綠/灰              黃色      青色         藍色      綠色
```

## 支援系統

| 系統 | 需求 |
|------|------|
| macOS | [Homebrew](https://brew.sh) |
| Ubuntu / Debian | sudo 權限 |
| CentOS / RHEL | sudo 權限 |

## 快速安裝

在專案根目錄執行：

```bash
bash statusline/install.sh
```

安裝完成後，**重新啟動 Claude Code** 即可看到狀態列。

### 安裝流程

腳本會自動執行以下步驟：

1. 偵測作業系統
2. 安裝 `jq`（若尚未安裝）
3. 複製 `statusline-command.sh` 至 `~/.claude/`
4. 更新 `~/.claude/settings.json`（自動備份既有設定）

若 `settings.json` 已存在，原始檔案會備份為 `~/.claude/settings.json.backup`。

## 自訂顏色

安裝後，編輯 `~/.claude/statusline-command.sh` 頂部的 `COLOR_*` 變數：

```sh
COLOR_MODEL='\033[35m'       # 紫色（模型名稱）
COLOR_BAR_FILL='\033[32m'    # 綠色（進度條填滿）
COLOR_BAR_EMPTY='\033[90m'   # 深灰（進度條空白）
COLOR_PCT='\033[33m'         # 黃色（百分比）
COLOR_TOKENS='\033[36m'      # 青色（Token 數）
COLOR_BRANCH='\033[34m'      # 藍色（Git 分支）
COLOR_PROJECT='\033[32m'     # 綠色（專案名稱）
```

ANSI 顏色代碼參考：`\033[30m`-`\033[37m`（標準），`\033[90m`-`\033[97m`（亮色）

## 手動安裝

若偏好手動安裝：

```bash
# 1. 安裝 jq
brew install jq          # macOS
sudo apt install -y jq   # Ubuntu/Debian
sudo yum install -y jq   # CentOS/RHEL

# 2. 複製腳本
mkdir -p ~/.claude
cp statusline/statusline-command.sh ~/.claude/
chmod +x ~/.claude/statusline-command.sh

# 3. 設定 Claude Code（若 settings.json 已存在，請手動合併 statusLine 區塊）
cat > ~/.claude/settings.json << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline-command.sh"
  }
}
EOF
```

## 移除

```bash
# 移除腳本
rm ~/.claude/statusline-command.sh

# 移除 settings.json 中的 statusLine 設定
# 手動編輯 ~/.claude/settings.json，刪除 statusLine 區塊
# 或者恢復備份（若有）：
cp ~/.claude/settings.json.backup ~/.claude/settings.json
```

## 檔案說明

| 檔案 | 說明 |
|------|------|
| `install.sh` | 一鍵安裝腳本 |
| `statusline-command.sh` | 狀態列腳本（安裝後複製至 `~/.claude/`） |
| `README.md` | 本說明文件 |
```

**Step 2: Commit**

```bash
git add statusline/README.md
git commit -m "docs: add statusline README with install and customization guide"
```

---

### Task 4: Update root `README.md`

**Files:**
- Modify: `README.md`

**Step 1: Replace root README.md with a proper toolkit overview**

Replace the default GitLab template content with:

```markdown
# Claude Code Toolkit

A collection of tools and configurations for Claude Code.

## Tools

### Status Line (`statusline/`)

Customizes the Claude Code bottom status bar with model name, context usage progress bar, token count, git branch, and project name.

**Quick install:**

```bash
bash statusline/install.sh
```

See [`statusline/README.md`](statusline/README.md) for full documentation.
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update root README with toolkit overview"
```

---

## Final Verification

After all tasks complete, verify the structure:

```bash
ls -la statusline/
# Expected:
# install.sh
# statusline-command.sh
# README.md
```

Test install on a clean environment (or dry-run by reading the script):

```bash
# Check the script is syntactically valid
sh -n statusline/install.sh
sh -n statusline/statusline-command.sh
```
