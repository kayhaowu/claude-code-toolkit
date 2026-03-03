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

## Dashboard（多實例監控）

在獨立終端機執行，即時顯示所有 Claude Code session 的狀態：

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

每 2 秒自動更新，按 `Ctrl+C` 離開。

**運作原理：** `statusline-command.sh` 每次被 Claude Code 呼叫時，會將 session 狀態寫入 `~/.claude/sessions/<PID>.json`，dashboard 讀取這些檔案並彙整顯示。

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
| `install.sh` | 一鍵安裝腳本（重複執行可升級至最新版本） |
| `statusline-command.sh` | 狀態列腳本（安裝後複製至 `~/.claude/`） |
| `dashboard.sh` | 多實例 Dashboard（安裝後複製至 `~/.claude/`） |
| `README.md` | 本說明文件 |
