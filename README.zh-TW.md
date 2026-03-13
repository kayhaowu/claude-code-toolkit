[English](README.md) | [繁體中文](README.zh-TW.md)

# Claude Code Toolkit

> 提升 Claude Code CLI 使用體驗的工具與設定集合。

## 功能

- **自訂狀態列** — 模型名稱、Context 使用量進度條、Token 數、預估費用、Git 分支、專案名稱
- **5 種色彩主題** — ansi-default、catppuccin-mocha、dracula、nord、none（+ NO_COLOR 支援）
- **多實例 Dashboard** — 即時終端機畫面，顯示所有活躍的 Claude Code session
- **tmux 整合** — tmux 狀態列即時 session 監控，事件驅動偵測
- **一鍵安裝** — 支援 macOS、Ubuntu/Debian、CentOS/RHEL

在 tmux 中安裝後，同時擁有 Claude Code 狀態列與 tmux session 總覽：

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ $ claude                                                                     │
│                                                                              │
│ > 幫我重構 auth 模組                                                          │
│                                                                              │
│ 我先讀取目前的 auth 實作...                                                    │
│                                                                              │
│ Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │  main │ my-proj  │
├──────────────────────────────────────────────────────────────────────────────┤
│ [0] zsh           [1] claude*                                   13 Mar 10:30 │
│ Claude: ⚡my-proj 42% │ 💤api-server 18% │ 💤docs 7%                        │
└──────────────────────────────────────────────────────────────────────────────┘
 ↑ Claude Code 狀態列（CLI 內部）         ↑ tmux 列：所有 session 一覽
```

## 快速開始

```bash
bash statusline/install.sh
```

安裝完成後，重新啟動 Claude Code 即可啟用。

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

## tmux 整合

在 tmux session 中執行安裝腳本會自動設定 session 監控。手動設定：

```bash
tmux set-option -g status 2
tmux set-option -g status-format[1] "#[align=left,fg=#bd93f9,bg=#282a36] Claude: #(sh ~/.claude/tmux-sessions.sh)"
tmux set-option -g status-interval 2
```

狀態偵測透過 Claude Code hooks（UserPromptSubmit、PostToolUse、Stop）**事件驅動** — 近乎即時更新，非輪詢式。詳見 [`statusline/README.zh-TW.md`](statusline/README.zh-TW.md#即時狀態偵測原理)。

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
