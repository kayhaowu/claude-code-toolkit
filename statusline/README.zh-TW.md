[English](README.md) | [繁體中文](README.zh-TW.md)

# Claude Code Status Line

自訂 Claude Code 底部狀態列，顯示模型、Context 使用量、Token 數、費用、Git 分支與專案名稱。支援 5 種色彩主題。

**狀態列**（Claude Code CLI 內部）：
```
Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │ est $0.12 │  main │ my-project
 紫色            綠/灰              黃色      青色          黃色       藍色      綠色
```

**安裝後在 tmux 中** — 狀態列 + session 總覽：
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ $ claude                                                                     │
│                                                                              │
│ > 幫我重構 auth 模組                                                          │
│                                                                              │
│ Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │  main │ my-proj  │
├──────────────────────────────────────────────────────────────────────────────┤
│ [0] zsh           [1] claude*                                   13 Mar 10:30 │
│ Claude: ⚡my-proj 42% │ 💤api-server 18% │ 💤docs 7%                        │
└──────────────────────────────────────────────────────────────────────────────┘
 ↑ Claude Code 狀態列（CLI 內部）         ↑ tmux 列：所有 session 一覽
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
3. 複製腳本至 `~/.claude/`（`statusline-command.sh`、`dashboard.sh`、`heartbeat.sh`、`tmux-sessions.sh`、`status-hook.sh`）
4. 更新 `~/.claude/settings.json` — 設定 statusLine、session 生命週期 hooks（SessionStart/SessionEnd）、事件驅動狀態 hooks（UserPromptSubmit/PostToolUse/Stop）。自動備份既有設定
5. 若在 tmux session 中執行，自動設定第二行狀態列顯示即時 session 監控（每 2 秒更新）

若 `settings.json` 已存在，原始檔案會備份為 `~/.claude/settings.json.backup`。

## 主題（Themes）

內建 5 種色彩主題，透過環境變數 `CLAUDE_STATUSLINE_THEME` 選擇：

| 主題 | 說明 | 顏色類型 |
|------|------|----------|
| `ansi-default` | 預設主題，使用標準 ANSI 顏色 | 4-bit ANSI |
| `catppuccin-mocha` | Catppuccin Mocha 色票，柔和粉彩風格 | 24-bit TrueColor |
| `dracula` | Dracula 主題，高對比深色風格 | 24-bit TrueColor |
| `nord` | Nord 主題，北極藍色調 | 24-bit TrueColor |
| `none` | 無顏色，純文字輸出 | 無 |

### 設定方式

在 shell 設定檔（`~/.zshrc` 或 `~/.bashrc`）中加入：

```bash
export CLAUDE_STATUSLINE_THEME="catppuccin-mocha"
```

### NO_COLOR 支援

設定 `NO_COLOR=1` 環境變數可完全停用所有 ANSI 顏色輸出（符合 [no-color.org](https://no-color.org) 標準）。`NO_COLOR` 優先於 `CLAUDE_STATUSLINE_THEME`。

```bash
export NO_COLOR=1
```

無顏色模式下，進度條使用 `=` 和 `.`，分隔符使用 `|`。

### 新增顯示區段

- **費用（Cost）**：顯示預估 API 費用 `est $X.XX`，**預設關閉**（訂閱制用戶不需要）。API 計費用戶可設定 `export CLAUDE_STATUSLINE_SHOW_COST=1` 開啟
- **200k 警告（Alert）**：當 Token 數超過 200k 時顯示 `⚠ 200k`
- **Context % 顏色**：依使用率變色 — ≤60% 正常、60-80% 警告、>80% 危險

### 12 語意色彩 Token

每個主題定義 12 個語意色彩 Token：

| Token | 用途 |
|-------|------|
| `C_MODEL` | 模型名稱 |
| `C_BAR_FILL` | 進度條已填滿 |
| `C_BAR_EMPTY` | 進度條未填滿 |
| `C_CTX_OK` | Context % 正常（≤60%） |
| `C_CTX_WARN` | Context % 警告（60-80%） |
| `C_CTX_BAD` | Context % 危險（>80%） |
| `C_TOKENS` | Token 數 |
| `C_COST` | 費用 |
| `C_ALERT` | 警告訊息 |
| `C_BRANCH` | Git 分支 |
| `C_PROJECT` | 專案名稱 |
| `C_SEP` | 分隔符 |

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

## tmux 狀態列

tmux 整合會在第二行狀態列顯示精簡的 session 概覽：

```
⚡my-project 42% │ 💤other-proj 14%
```

- `⚡` = WORKING（Claude 正在處理中）
- `✅` = DONE（任務剛完成，30 秒後自動消失）
- `💤` = IDLE（Claude 等待輸入中）

✅ DONE 狀態需要安裝 [hooks 元件](../hooks/README.zh-TW.md)（`notify-on-stop.sh`）。

### 即時狀態偵測原理

狀態偵測使用**事件驅動 hooks** 實現即時更新：

| 事件 | Hook | 寫入狀態 |
|------|------|---------|
| 使用者送出 prompt | `UserPromptSubmit` | `working` |
| 工具呼叫完成 | `PostToolUse` | `working` |
| Claude 完成回應 | `Stop` | `idle` |

Hooks 寫入輕量純文字檔（`~/.claude/sessions/<PID>.status`）— 不需要 JSON 解析，約 5ms 完成更新。tmux 每 2 秒讀取此檔案，實現近乎即時的狀態顯示。

**檔案所有權模型（無競態條件）：**

| 檔案 | 唯一寫入者 |
|------|-----------|
| `<PID>.json` | `statusline-command.sh` |
| `<PID>.status` | `status-hook.sh`（由 hooks 觸發）|
| `<PID>.hb.dat` | `heartbeat.sh` |

若未安裝 hooks，系統會自動 fallback 至 JSON 檔案的 token 比較偵測。

## 移除

```bash
bash statusline/uninstall.sh
```

或手動移除：

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
| `uninstall.sh` | 一鍵移除腳本 |
| `statusline-command.sh` | 狀態列腳本（安裝後複製至 `~/.claude/`） |
| `dashboard.sh` | 多實例 Dashboard（安裝後複製至 `~/.claude/`） |
| `heartbeat.sh` | 心跳 Daemon（安裝後複製至 `~/.claude/`） |
| `tmux-sessions.sh` | tmux 狀態列 segment（安裝後複製至 `~/.claude/`） |
| `status-hook.sh` | 事件驅動狀態 hook（安裝後複製至 `~/.claude/`） |
| `README.md` | 英文說明文件 |
| `README.zh-TW.md` | 繁體中文說明文件 |
