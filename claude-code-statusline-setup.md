# Claude Code Status Line 設定指南

自訂 Claude Code 底部狀態列，顯示以下資訊（各欄位以不同顏色區分）：

```
Claude Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │  main │ my-project
   紫色                綠色/灰色             黃色      青色         藍色      綠色
```

---

## 步驟一：建立狀態列腳本

### 前置需求

系統需安裝 `jq`：

```bash
# Ubuntu / Debian
sudo apt install -y jq

# CentOS / RHEL
sudo yum install -y jq
```

### 建立腳本

```bash
mkdir -p ~/.claude
```

```bash
cat << 'SCRIPT' > ~/.claude/statusline-command.sh
#!/bin/sh
# Status line: model | progress bar | % used | tokens used | git branch | project name

input=$(cat)

# ANSI color codes
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Segment colors
COLOR_MODEL='\033[35m'       # Purple/violet  (model name)
COLOR_BAR_FILL='\033[32m'    # Green          (filled bar blocks)
COLOR_BAR_EMPTY='\033[90m'   # Dark gray      (empty bar blocks)
COLOR_PCT='\033[33m'         # Yellow/amber   (percentage)
COLOR_TOKENS='\033[36m'      # Cyan           (tokens)
COLOR_BRANCH='\033[34m'      # Blue           (git branch)
COLOR_PROJECT='\033[32m'     # Green          (project name)
COLOR_SEP='\033[2;37m'       # Dim gray       (separators)

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
SCRIPT
```

設定執行權限：

```bash
chmod +x ~/.claude/statusline-command.sh
```

---

## 步驟二：設定 Claude Code

如果 `~/.claude/settings.json` 已存在，將 `statusLine` 區塊合併進去。如果不存在，直接建立：

```bash
cat << 'EOF' > ~/.claude/settings.json
{
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline-command.sh"
  }
}
EOF
```

> **注意**：如果你的 `settings.json` 已有其他設定，請手動將 `statusLine` 區塊加入，避免覆蓋既有設定。

---

## 步驟三：驗證

重新啟動 Claude Code，底部應顯示彩色狀態列。

不需要額外設定，啟動後立即生效。

---

## 顏色對照表

| 資訊 | 顏色 | ANSI Code |
|------|------|-----------|
| Model name | 紫色 | `\033[35m` |
| Progress bar（填滿）| 綠色 | `\033[32m` |
| Progress bar（空白）| 深灰 | `\033[90m` |
| Percentage | 黃色 | `\033[33m` |
| Tokens | 青色 | `\033[36m` |
| Git branch | 藍色 | `\033[34m` |
| Project name | 綠色 | `\033[32m` |
| 分隔符 │ | 淡灰 | `\033[2;37m` |

> 如需自訂顏色，修改 `~/.claude/statusline-command.sh` 頂部的 `COLOR_*` 變數即可。
