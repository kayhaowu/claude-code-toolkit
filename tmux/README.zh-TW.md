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
