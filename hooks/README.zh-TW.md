[English](README.md) | [繁體中文](README.zh-TW.md)

# Claude Code Hooks 集合

用於自動化 Claude Code 工作流程的即用 hook 腳本集合。Hooks 整合 Claude Code 事件系統，新增安全防護、自動格式化、通知與使用量記錄功能。

## 快速參考

| Hook | 事件 | 說明 |
|------|------|------|
| `safety-guard.sh` | PreToolUse | 攔截危險指令（rm -rf /、force push、DROP TABLE）|
| `sensitive-files.sh` | PreToolUse | 攔截存取 .env、credentials、*.key 等敏感檔案 |
| `auto-format.sh` | PostToolUse | 編輯後自動格式化（prettier/black/gofmt/clang-format）|
| `notify-on-stop.sh` | Stop | Claude 完成時桌面/tmux 通知（30 秒門檻）|
| `context-alert.sh` | Stop | Context 使用超過 80% 或 95% 時警告 |
| `usage-logger.sh` | Session | 記錄 session 使用量至 `~/.claude/hooks/usage.jsonl` |
| `daily-log.sh` | Stop | 將 session 摘要追加至 `~/.claude/daily-draft.md` |

## 安裝 / 移除

```bash
# 安裝
bash hooks/install.sh

# 移動資料夾後修復壞掉的 symlinks
bash hooks/install.sh --relink

# 移除
bash hooks/uninstall.sh
```

## 分層預設值

Hooks 分為兩個層級：

**建議開啟（預設啟用）：**
- `notify-on-stop.sh` — Claude 完成時桌面/tmux 通知
- `safety-guard.sh` — 在執行前攔截破壞性指令
- `sensitive-files.sh` — 攔截存取憑證檔案

**選用關閉（預設停用，安裝時可啟用）：**
- `auto-format.sh` — 需要已安裝格式化工具
- `context-alert.sh` — 接近 context 上限時有用
- `usage-logger.sh` — 建立持久化日誌檔案
- `daily-log.sh` — 需要 cron 排程發布日誌

## Hook 詳細說明

### safety-guard.sh

在 `Bash` 工具呼叫的 `PreToolUse` 事件觸發。掃描指令是否符合危險模式黑名單，若符合則阻擋執行並顯示錯誤訊息。

| 模式 | 原因 |
|------|------|
| `rm -rf /` | 遞迴刪除根目錄 |
| `rm -rf /*` | 遞迴刪除根目錄（glob）|
| `:(){ :|:& };:` | Fork bomb |
| `git push --force` | 強制推送至遠端 |
| `git push -f` | 強制推送（短參數）|
| `DROP TABLE` | SQL 資料表破壞 |
| `DROP DATABASE` | SQL 資料庫破壞 |
| `mkfs` | 檔案系統格式化 |
| `dd if=` | 原始磁碟寫入 |
| `chmod -R 777 /` | 全域可寫根目錄 |

設定 `CLAUDE_HOOKS_ALLOW_DANGEROUS=1` 可繞過（不建議）。

### sensitive-files.sh

在檔案讀寫工具呼叫的 `PreToolUse` 事件觸發。攔截符合敏感模式的檔案存取。

敏感模式：
- `.env`、`.env.*` — 環境變數檔案
- `credentials`、`credentials.json` — 憑證檔案
- `*.key`、`*.pem`、`*.p12` — 私鑰與憑證
- `*.secret` — 機密檔案
- `id_rsa`、`id_ed25519`、`id_ecdsa` — SSH 私鑰
- `.netrc` — 網路憑證檔案
- `*.keystore` — Java 金鑰庫

需要合法存取時，設定 `CLAUDE_HOOKS_ALLOW_SENSITIVE=1` 可繞過。

### auto-format.sh

在檔案編輯工具呼叫的 `PostToolUse` 事件觸發。偵測檔案類型並執行對應的格式化工具。若找不到格式化工具則靜默跳過。

| 檔案類型 | 格式化工具 | 優先順序 |
|---------|-----------|---------|
| `.js`、`.ts`、`.jsx`、`.tsx`、`.json`、`.css`、`.html`、`.md` | `prettier` | 第 1 優先 |
| `.py` | `black` | 第 1 優先，fallback 至 `autopep8` |
| `.go` | `gofmt` | 內建 |
| `.c`、`.cpp`、`.h`、`.hpp` | `clang-format` | 內建 |
| `.rs` | `rustfmt` | 內建 |
| `.sh`、`.bash` | `shfmt` | 內建 |
| `.rb` | `rubocop -a` | 內建 |
| `.java` | `google-java-format` | 內建 |

### notify-on-stop.sh

在 `Stop` 事件觸發。當 Claude 完成回應時發送通知。僅在 session 持續超過 **30 秒**時觸發（避免快速回覆的噪音）。

通知鏈（非排他，多管道同時觸發）：
1. tmux ✅ 狀態 — 將 `done` 寫入 `.status` 檔，tmux 顯示 ✅ 持續 30 秒（需要 tmux + statusline）
2. Terminal bell — `printf '\a'`
3. macOS 通知中心 — `osascript`（SSH 連線時跳過）
4. Linux 桌面通知 — `notify-send`（需要 `$DISPLAY` 或 `$WAYLAND_DISPLAY`）

通知包含專案名稱與簡短完成訊息。

statusline tmux 列中的 ✅ DONE 狀態由此 hook 驅動 — 它將 session 狀態設為 `done`，30 秒後自動消失。

### context-alert.sh

在 `Stop` 事件觸發。從 session 狀態檔案讀取當前 context 使用百分比，若超過門檻則發出警告。

| 門檻 | 動作 |
|------|------|
| ≥ 95% | 嚴重警告 — Context 即將用盡 |
| ≥ 80% | 警告 — 考慮開始新 session |

警告透過與 `notify-on-stop.sh` 相同的通知鏈發送。

需要 statusline 元件提供 session 狀態檔案（`~/.claude/sessions/<PID>.json`）。

### usage-logger.sh

在 `SessionStart` 和 `SessionEnd` 事件觸發。每次事件在 `~/.claude/hooks/usage.jsonl` 追加一行 JSON。

JSONL 格式：

```json
{"event":"SessionStart","pid":12345,"project":"my-project","model":"claude-opus-4-5","timestamp":"2026-03-14T10:00:00Z"}
{"event":"SessionEnd","pid":12345,"project":"my-project","tokens":85200,"cost_usd":0.12,"duration_s":342,"timestamp":"2026-03-14T10:05:42Z"}
```

欄位說明：
- `event` — `SessionStart` 或 `SessionEnd`
- `pid` — Claude Code 程序 ID
- `project` — 專案目錄名稱
- `model` — session 狀態中的模型名稱
- `tokens` — 總使用 token 數（僅 SessionEnd）
- `cost_usd` — 預估費用（美元，僅 SessionEnd）
- `duration_s` — session 持續秒數（僅 SessionEnd）
- `timestamp` — ISO 8601 UTC 時間戳記

需要 statusline 元件提供 session 狀態檔案。

### daily-log.sh

在 `Stop` 事件觸發。將 Claude 最後回應的前 300 字元加上時間戳記追加至 `~/.claude/daily-draft.md`。摘要在一天中持續累積。

透過 cron 執行 `daily-log-publish.sh` 發布日誌：

```
0 0 * * * sh ~/.claude/hooks/daily-log-publish.sh
```

在 `~/.claude/.env` 設定：

| 變數 | 說明 |
|------|------|
| `DAILY_LOG_MODE` | `local`（預設）— 寫入 `DAILY_LOG_DIR`；`git` — 寫入 `DAILY_LOG_GIT_REPO/logs/` 並推送 |
| `DAILY_LOG_DIR` | local 模式的日誌目錄（預設：`~/.claude/logs`）|
| `DAILY_LOG_GIT_REPO` | git 模式的 repo 路徑 |
| `DAILY_LOG_LLM_URL` | 用於整理日誌的 OpenAI 相容 API 端點（選填）|
| `DAILY_LOG_LLM_KEY` | LLM API key（選填）|
| `DAILY_LOG_LLM_MODEL` | 模型名稱（選填，預設：`gpt-4o-mini`）|

未設定 `DAILY_LOG_LLM_URL` 時直接拼接所有 session 摘要，不需要 LLM。支援任何 OpenAI 相容端點。

## 環境變數

| 變數 | 說明 |
|------|------|
| `CLAUDE_HOOKS_ALLOW_DANGEROUS` | 設為 `1` 可繞過 safety-guard 攔截 |
| `CLAUDE_HOOKS_ALLOW_SENSITIVE` | 設為 `1` 可繞過 sensitive-files 攔截 |
| `DAILY_LOG_MODE` | `local` 或 `git`（daily-log）|
| `DAILY_LOG_DIR` | local 模式日誌目錄（daily-log）|
| `DAILY_LOG_GIT_REPO` | git 模式 repo 路徑（daily-log）|
| `DAILY_LOG_LLM_URL` | LLM 端點（daily-log）|
| `DAILY_LOG_LLM_KEY` | LLM API key（daily-log）|
| `DAILY_LOG_LLM_MODEL` | LLM 模型名稱（daily-log）|

## 必要條件

| 需求 | 使用者 |
|------|--------|
| `jq` | usage-logger、context-alert（JSON 解析）|
| statusline 元件 | context-alert、usage-logger（session 狀態檔案）|
| `prettier` / `black` / `gofmt` 等 | auto-format（選用，不存在則跳過）|
| `terminal-notifier` 或 `notify-send` | notify-on-stop（選用，fallback 至 tmux）|

## 檔案說明

| 檔案 | 說明 |
|------|------|
| `install.sh` | 一鍵安裝腳本 |
| `uninstall.sh` | 一鍵移除腳本 |
| `safety-guard.sh` | 危險指令攔截器（PreToolUse）|
| `sensitive-files.sh` | 敏感檔案存取攔截器（PreToolUse）|
| `auto-format.sh` | 編輯後自動格式化（PostToolUse）|
| `notify-on-stop.sh` | 完成通知（Stop）|
| `context-alert.sh` | Context 使用量警告（Stop）|
| `usage-logger.sh` | Session 使用量記錄（Session）|
| `daily-log.sh` | 追加 session 摘要至草稿（Stop）|
| `daily-log-publish.sh` | 整合草稿並儲存日誌（cron）|
| `README.md` | 英文說明文件 |
| `README.zh-TW.md` | 繁體中文說明文件 |
