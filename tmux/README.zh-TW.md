[English](README.md) | [繁體中文](README.zh-TW.md)

# tmux 設定

Catppuccin Mocha 主題的 tmux 設定，整合 Claude Code session 監控。

## 功能

- **Catppuccin Mocha 主題** — 柔和粉彩色，圓角視窗狀態
- **狀態列** — CPU、RAM、電池、日期時間、git 分支
- **Claude Code 監控** — 安裝 statusline 後自動顯示活躍的 Claude session
- **Vim-tmux 導航** — Ctrl-h/j/k/l 無縫切換窗格
- **滑鼠支援** — 點擊、捲動、拖曳選取並保持高亮
- **遠端部署** — 一鍵設定 Linux 伺服器

## 需求

- tmux **3.3+**
- git（用於 TPM 插件安裝）
- [TPM](https://github.com/tmux-plugins/tpm)（deploy.sh 會自動安裝）

Windows 請見 [Windows (psmux)](#windows-psmux)。

## 快速開始

### 本地設定

```bash
# 1. 複製設定檔
mkdir -p ~/.config/tmux
cp tmux/tmux.conf ~/.config/tmux/tmux.conf

# 2. 建立 TPM 相容的 symlink
ln -sf ~/.config/tmux ~/.tmux

# 3. 安裝 TPM（若尚未安裝）
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# 4. 啟動 tmux 並安裝插件
tmux
# 按 prefix (Ctrl-a) + I 安裝插件
```

### 遠端部署

```bash
bash tmux/deploy.sh user@host [ssh-options]
```

自動安裝 tmux、git、TPM、所有插件、Ghostty terminfo。可選安裝 Claude Code statusline。

## Windows (psmux)

`psmux.conf` 是 `tmux.conf` 移植到 [psmux](https://github.com/psmux/psmux) 的版本。psmux 是原生 Windows 的 tmux（不需要 WSL 或 Cygwin）。prefix、快捷鍵、Catppuccin Mocha 主題與狀態列都與原版相同。已在 psmux 3.4.0 測試。

### 需求

- [psmux](https://github.com/psmux/psmux)：`winget install marlocarlo.psmux`
- PowerShell 7：`winget install Microsoft.PowerShell`（設定檔使用 `default-shell pwsh`）
- Git for Windows：`winget install Git.Git`（狀態列的 git 分支；Claude 監控需要 Git Bash）
- Nerd Font：`winget install DEVCOM.JetBrainsMonoNerdFont`，並在終端機設定中選用

### 安裝

在 repo 根目錄執行：

```powershell
powershell -ExecutionPolicy Bypass -File tmux\install.ps1
```

安裝程式會：

- 檢查 psmux、PowerShell 7 與 Nerd Font。缺少 psmux 或 PowerShell 7 時會印出 `winget` 指令並結束；缺少 Nerd Font 只會警告。除非加上 `-InstallDeps`，否則不會安裝任何軟體；加上後會用 winget 安裝缺少的項目（`-FontPackage <winget id>` 可指定其他字型）。
- 複製設定檔與腳本（見下表）。目標檔案已存在且內容不同時，會先備份為 `<檔名>.bak-<yyyyMMdd-HHmmss>`；內容相同則略過，因此可重複執行。
- 若有其他會被 psmux 忽略的設定檔，會顯示警告（見下方說明）。

接著開啟新的終端機並執行 `tmux`（或 `psmux`）。已在執行中的 session 請按 `C-a r` 重載設定。

### 設定檔位置

| Repo 檔案 | 安裝位置 | 用途 |
|-----------|----------|------|
| `tmux/psmux.conf` | `~/.psmux.conf` | 主設定檔 |
| `tmux/scripts/sysinfo.ps1` | `~/.config/psmux/scripts/` | CPU / RAM / 電池資訊收集器 |
| `tmux/scripts/git-branch.cmd` | `~/.config/psmux/scripts/` | 目前窗格的 git 分支 |
| `tmux/scripts/open.ps1` | `~/.config/psmux/scripts/` | copy mode 的 `o`（開啟）與 `S`（搜尋）|
| （自動產生）| `~/.config/psmux/cache/sysinfo.txt` | 收集器輸出，供狀態列讀取 |

psmux 只會載入第一個找到的設定檔，順序為：`~/.psmux.conf`、`~/.psmuxrc`、`~/.tmux.conf`、`~/.config/psmux/psmux.conf`。`psmux -f <檔案>` 或 `PSMUX_CONFIG_FILE` 環境變數可覆寫此搜尋順序。安裝 `~/.psmux.conf` 後，其他三個檔案都會被忽略。

### 注意事項

與 Linux/macOS 版設定的差異與限制：

- **沒有 TPM 與插件。** catppuccin、tmux-sensible、vim-tmux-navigator、tmux-cpu、tmux-battery、tmux-open 都改為直接寫在 `psmux.conf` 或 `tmux/scripts/` 中實作。`C-a I` 沒有作用。
- `if-shell` 的條件在 **PowerShell** 中執行；狀態列的 `#(...)` 在 **cmd.exe** 中執行。
- psmux 不會展開 `#(...)` 裡的 `#{...}`。`git-branch.cmd` 會自行向 server 查詢目前窗格的路徑。
- psmux 引號 bug：設定字串中的 `"` 會被存成 `\"`，導致 cmd.exe 指令失效。`#(...)` 裡不要使用雙引號。
- `default-terminal` 設為 `xterm-256color`，因為 Git for Windows 的 ncurses 沒有 `tmux-256color`（Git Bash 的 vim 與 less 需要它）。
- `escape-time` 設為 50 ms（tmux-sensible 為 0），這是 psmux 在 Windows 上的建議值。
- 設定了 `allow-predictions on`：psmux 預設會在每個 pane 強制設定 PSReadLine `PredictionSource None`（在載入 profile 前後各一次），導致自動建議失效。已開啟的 pane 不會套用；要全部生效請執行 `tmux kill-server` 後重新啟動。
- 移除 `MouseDragEnd1Pane` 綁定：psmux 放開滑鼠時會自動把拖曳選取的內容複製到 Windows 剪貼簿。
- 移除 tmux-open 的 `C-o`（用 `$EDITOR` 開啟）。copy mode 中的 `o`（用 Windows 預設程式開啟）與 `S`（Google 搜尋）仍可使用。
- Claude 監控列只在 `~/.claude/tmux-sessions.sh` 存在時出現，且需要 Git Bash 與 jq（`winget install jqlang.jq`）。它執行 `%LOCALAPPDATA%\Programs\Git\bin\bash.exe`，也就是 Git for Windows 的個人安裝路徑。若 Git 是全機安裝，請修改 `~/.psmux.conf` 中的 `status-format[1]` 那一行。路徑無法加引號（見上方引號 bug），請使用不含空白的路徑，例如短檔名 `C:\PROGRA~1\Git\bin\bash.exe`。
- sysinfo 收集器（`sysinfo.ps1`）由設定檔以 `run-shell -b` 啟動。named mutex 確保每個使用者只有一個實例；最後一個 psmux session 結束後約 30 秒內會自行結束並刪除快取檔。
- 狀態列的圖示與圓角分隔符需要 Nerd Font。

## Claude Code 整合

安裝 [Claude Code statusline](../statusline/README.zh-TW.md) 後，會自動出現第二行狀態列：

```
⚡my-project 42% │ 💤other-proj 14%
```

透過 `if-shell` 條件控制 — 未安裝 statusline 時不會顯示空行。

## 快捷鍵

| 按鍵 | 功能 |
|------|------|
| `C-a` | Prefix（取代 C-b）|
| `C-a \|` | 水平分割 |
| `C-a -` | 垂直分割 |
| `C-a c` | 新視窗 |
| `C-a s` | 切換同步輸入 |
| `C-a r` | 重載設定 |
| `C-a h/j/k/l` | 調整窗格大小 |
| `C-a m` | 縮放窗格 |
| `C-a C-l` | 清除歷史 |
| `C-h/j/k/l` | 切換窗格（vim-tmux-navigator）|

## VS Code Terminal

在 VS Code 內建終端中，tmux mouse mode 會**自動停用**（偵測 `$TERM_PROGRAM=vscode`），讓原生複製貼上正常運作。

若在其他終端中需要繞過 tmux 滑鼠攔截：
- **macOS**：按住 `Option` 再選取文字
- **Linux/Windows**：按住 `Shift` 再選取文字

## 插件

| 插件 | 用途 |
|------|------|
| [tpm](https://github.com/tmux-plugins/tpm) | 插件管理器 |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | 合理預設值 |
| [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | Vim 風格窗格導航 |
| [catppuccin/tmux](https://github.com/catppuccin/tmux) | Catppuccin Mocha 主題 |
| [tmux-cpu](https://github.com/tmux-plugins/tmux-cpu) | CPU 與 RAM 顯示 |
| [tmux-battery](https://github.com/tmux-plugins/tmux-battery) | 電池顯示 |
| [tmux-open](https://github.com/tmux-plugins/tmux-open) | 從 copy mode 開啟 URL 與檔案 |
