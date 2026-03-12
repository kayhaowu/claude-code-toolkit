[English](README.md) | [繁體中文](README.zh-TW.md)

# Claude Code Toolkit

工程師日常使用 Claude Code 的工具與設定集合。

## 工具列表

### Status Line (`statusline/`)

自訂 Claude Code 底部狀態列，顯示模型名稱、Context 使用量進度條、Token 數、Git 分支與專案名稱。支援 5 種色彩主題（ansi-default、catppuccin-mocha、dracula、nord、none）與 NO_COLOR。

```
Opus 4.6 │ [████████░░░░░░░░░░░░] │ 42% │ 85.2k tokens │  main │ my-project
```

**一鍵安裝：**

```bash
bash statusline/install.sh
```

支援 macOS、Ubuntu/Debian、CentOS/RHEL。詳見 [`statusline/README.md`](README.md)。
