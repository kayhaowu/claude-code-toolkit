[English](README.md) | [繁體中文](README.zh-TW.md)

# Claude Code Toolkit

<p align="center">
  <img src="assets/social-preview.png" alt="Claude Code Toolkit" width="640" />
</p>

> 提升 Claude Code CLI 使用體驗的工具與設定集合。

## 功能

- **自訂狀態列** — 模型名稱、Context 使用量進度條、Token 數、預估費用、Git 分支、專案名稱
- **5 種色彩主題** — ansi-default、catppuccin-mocha、dracula、nord、none（+ NO_COLOR 支援）
- **多實例 Dashboard** — 即時終端機畫面，顯示所有活躍的 Claude Code session
- **Web Dashboard** — 瀏覽器即時 Session 監控 + Web Terminal（xterm.js）
- **tmux 整合** — tmux 狀態列即時 session 監控，事件驅動偵測
- **一鍵安裝** — 支援 macOS、Ubuntu/Debian、CentOS/RHEL

在 tmux 中安裝後，同時擁有 Claude Code 狀態列與 tmux session 總覽：

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ $ claude                                                                     │
│                                                                              │
│ > 幫我重構 auth 模組                                                           │
│                                                                              │
│ 我先讀取目前的 auth 實作...                                                     │
│                                                                              │
│ Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │  main │ my-proj     │
├──────────────────────────────────────────────────────────────────────────────┤
│ [0] zsh           [1] claude*                                   13 Mar 10:30 │
│ Claude: ⚡my-proj 42% │ 💤api-server 18% │ 💤docs 7%                          │
└──────────────────────────────────────────────────────────────────────────────┘
 ↑ Claude Code 狀態列（CLI 內部）         ↑ tmux 列：所有 session 一覽
```

## 快速開始

### 一行安裝

```bash
curl -fsSL https://raw.githubusercontent.com/kayhaowu/claude-code-toolkit/main/install.sh | bash
```

然後啟用需要的模組：

```bash
bash ~/.claude-code-toolkit/statusline/install.sh   # 狀態列 + tmux
bash ~/.claude-code-toolkit/hooks/install.sh         # 安全 hooks
```

### 從本機 clone 安裝

```bash
git clone https://github.com/kayhaowu/claude-code-toolkit.git
cd claude-code-toolkit
bash statusline/install.sh
```

安裝完成後，重新啟動 Claude Code 即可啟用。若在 tmux 中執行，session 監控會自動出現。

### 移除

```bash
bash ~/.claude-code-toolkit/uninstall.sh
```

### 部署到遠端 Linux 主機

不需要在遠端 clone — 從本機執行即可：

```bash
bash tmux/deploy.sh user@host
```

透過 SSH 部署 tmux + Catppuccin 主題 + 插件，並詢問是否一併安裝 Claude Code statusline。

### 支援系統

| 系統 | 需求 |
|------|------|
| macOS | [Homebrew](https://brew.sh) |
| Ubuntu / Debian | sudo 權限 |
| CentOS / RHEL | sudo 權限 |

## 主題

在 shell 設定檔（`~/.zshrc` 或 `~/.bashrc`）中設定 `CLAUDE_STATUSLINE_THEME` 環境變數：

```bash
export CLAUDE_STATUSLINE_THEME="catppuccin-mocha"
```

| 主題 | 說明 | 顏色類型 |
|------|------|----------|
| `ansi-default` | 預設主題，標準 ANSI 顏色 | 4-bit ANSI |
| `catppuccin-mocha` | Catppuccin Mocha 色票，柔和粉彩風格 | 24-bit TrueColor |
| `dracula` | Dracula 主題，高對比深色風格 | 24-bit TrueColor |
| `nord` | Nord 主題，北極藍色調 | 24-bit TrueColor |
| `none` | 無顏色，純文字輸出 | 無 |

## Dashboard

在獨立終端機監控所有活躍的 Claude Code session：

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

每 2 秒自動更新，按 `Ctrl+C` 離開。

## Web Dashboard

瀏覽器即時監控 Claude Code session 並遠端操作終端機。

**Session Monitor** — 即時卡片顯示 PID、專案、模型、Token、費用、Git 分支、tmux 視窗、狀態（working/idle/stopped）。支援狀態篩選與搜尋。斷線自動顯示提示。

**Web Terminal** — 點擊 session 卡片上的「Open Terminal」按鈕，透過 xterm.js 連接 tmux 視窗。Catppuccin Mocha 主題、Nerd Font 圖示、分割面板、24-bit true color。

### 快速啟動

```bash
cd dashboard/backend && pnpm install
cd ../frontend && pnpm install && pnpm build
cd ../backend && pnpm dev
```

開啟 http://127.0.0.1:3141

### Docker

```bash
cd dashboard && docker compose up -d
```

僅限本機存取（綁定 `127.0.0.1:3141`）。需要 Node.js >= 24。

完整設計文件請參閱 [`docs/superpowers/specs/2026-03-15-dashboard-integration-design.md`](docs/superpowers/specs/2026-03-15-dashboard-integration-design.md)。

## tmux 整合

在 tmux session 中執行 `statusline/install.sh` 會自動在第二行狀態列設定 session 監控。會自動偵測 Catppuccin 主題並使用對應顏色；否則 fallback 至預設顏色。

狀態偵測透過 Claude Code hooks（UserPromptSubmit、PostToolUse、Stop）**事件驅動** — 近乎即時更新，非輪詢式。詳見 [`statusline/README.zh-TW.md`](statusline/README.zh-TW.md#即時狀態偵測原理)。

### tmux 設定（選用）

此 repo 還包含完整的 Catppuccin Mocha tmux 設定。如果你除了 Claude statusline 之外也想要完整的 tmux 環境（主題、快捷鍵、插件）：

```bash
# 複製設定檔並設定 TPM
cp tmux/tmux.conf ~/.config/tmux/tmux.conf
ln -sf ~/.config/tmux ~/.tmux
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# 啟動 tmux 後按 Ctrl-a + I 安裝插件
```

詳見 [`tmux/README.zh-TW.md`](tmux/README.zh-TW.md) 的快捷鍵、插件與詳細說明。

## Hooks

Claude Code 自動化 hook 腳本集合：

| Hook | 事件 | 說明 |
|------|------|------|
| `safety-guard` | PreToolUse | 攔截危險指令（rm -rf /、force push、DROP TABLE）|
| `sensitive-files` | PreToolUse | 攔截存取 .env、credentials、*.key 等敏感檔案 |
| `auto-format` | PostToolUse | 編輯後自動格式化（prettier/black/gofmt/clang-format）|
| `notify-on-stop` | Stop | Claude 完成時桌面/tmux 通知 |
| `context-alert` | Stop | Context 使用超過 80% 時警告 |
| `usage-logger` | Session | 記錄 session 使用量至 `~/.claude/hooks/usage.jsonl` |

### 安裝 Hooks

```bash
bash hooks/install.sh
```

建議 hooks（notify-on-stop、safety-guard、sensitive-files）預設啟用。選用 hooks（auto-format、usage-logger、context-alert）可在安裝時啟用。腳本以符號連結方式安裝，`git pull` 即可自動更新，無需重新安裝。

詳見 [`hooks/README.zh-TW.md`](hooks/README.zh-TW.md)。

## 環境設定

| 環境變數 | 說明 | 預設值 |
|---------|------|--------|
| `CLAUDE_STATUSLINE_THEME` | 色彩主題 | `ansi-default` |
| `CLAUDE_STATUSLINE_SHOW_COST` | 顯示預估 API 費用（`1` 啟用） | `0`（關閉）|
| `NO_COLOR` | 停用所有 ANSI 顏色（[no-color.org](https://no-color.org)）| 未設定 |

## 移除

```bash
bash statusline/uninstall.sh
```

詳見 [`statusline/README.zh-TW.md`](statusline/README.zh-TW.md) 的手動移除步驟。

## 貢獻

歡迎提交 Issue 和 Pull Request。請描述變更內容與動機。

## 授權

[MIT](LICENSE)
