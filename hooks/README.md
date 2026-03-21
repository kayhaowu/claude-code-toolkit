[English](README.md) | [繁體中文](README.zh-TW.md)

# Claude Code Hooks Collection

Ready-to-use hook scripts for automating Claude Code workflows. Hooks integrate with the Claude Code event system to add safety guardrails, auto-formatting, notifications, and usage logging.

## Quick Reference

| Hook | Event | Description |
|------|-------|-------------|
| `safety-guard.sh` | PreToolUse | Block dangerous commands (rm -rf /, force push, DROP TABLE) |
| `sensitive-files.sh` | PreToolUse | Block access to .env, credentials, *.key files |
| `auto-format.sh` | PostToolUse | Auto-format files after edit (prettier/black/gofmt/clang-format) |
| `notify-on-stop.sh` | Stop | Desktop/tmux notification when Claude finishes (30s threshold) |
| `context-alert.sh` | Stop | Warn when context usage exceeds 80% or 95% |
| `usage-logger.sh` | Session | Log session usage to `~/.claude/hooks/usage.jsonl` |
| `daily-log.sh` | Stop | Append session summary to `~/.claude/daily-draft.md` |

## Install / Uninstall

```bash
# Install
bash hooks/install.sh

# Repair broken symlinks after moving the toolkit folder
bash hooks/install.sh --relink

# Uninstall
bash hooks/uninstall.sh
```

## Layered Defaults

Hooks are split into two tiers:

**Recommended ON (enabled by default):**
- `notify-on-stop.sh` — desktop/tmux notification when Claude finishes
- `safety-guard.sh` — blocks destructive commands before they run
- `sensitive-files.sh` — blocks access to credential files

**Optional OFF (disabled by default, enabled during install):**
- `auto-format.sh` — requires formatters to be installed
- `context-alert.sh` — useful when nearing context limits
- `usage-logger.sh` — creates a persistent log file
- `daily-log.sh` — requires a cron job for publishing

## Hook Details

### safety-guard.sh

Fires on `PreToolUse` for `Bash` tool calls. Scans the command against a blocklist of dangerous patterns and blocks execution with an error message if matched.

| Pattern | Reason |
|---------|--------|
| `rm -rf /` | Recursive root deletion |
| `rm -rf /*` | Recursive root deletion (glob) |
| `:(){ :|:& };:` | Fork bomb |
| `git push --force` | Force push to remote |
| `git push -f` | Force push (short flag) |
| `DROP TABLE` | SQL table destruction |
| `DROP DATABASE` | SQL database destruction |
| `mkfs` | Filesystem format |
| `dd if=` | Raw disk write |
| `chmod -R 777 /` | World-writable root |

Set `CLAUDE_HOOKS_ALLOW_DANGEROUS=1` to bypass (not recommended).

### sensitive-files.sh

Fires on `PreToolUse` for file read/write tool calls. Blocks access to files matching sensitive patterns.

Sensitive patterns:
- `.env`, `.env.*` — environment variable files
- `credentials`, `credentials.json` — credential files
- `*.key`, `*.pem`, `*.p12` — private keys and certificates
- `*.secret` — secret files
- `id_rsa`, `id_ed25519`, `id_ecdsa` — SSH private keys
- `.netrc` — network credential file
- `*.keystore` — Java keystores

Set `CLAUDE_HOOKS_ALLOW_SENSITIVE=1` to bypass when legitimate access is needed.

### auto-format.sh

Fires on `PostToolUse` for file edit tool calls. Detects the file type and runs the appropriate formatter. Silently skips if no formatter is found.

| File Type | Formatter | Priority |
|-----------|-----------|----------|
| `.js`, `.ts`, `.jsx`, `.tsx`, `.json`, `.css`, `.html`, `.md` | `prettier` | 1st |
| `.py` | `black` | 1st, falls back to `autopep8` |
| `.go` | `gofmt` | built-in |
| `.c`, `.cpp`, `.h`, `.hpp` | `clang-format` | built-in |
| `.rs` | `rustfmt` | built-in |
| `.sh`, `.bash` | `shfmt` | built-in |
| `.rb` | `rubocop -a` | built-in |
| `.java` | `google-java-format` | built-in |

### notify-on-stop.sh

Fires on `Stop` events. Sends a notification when Claude finishes a response. Only fires if the session has been active for more than **30 seconds** (avoids noise for quick replies).

Notification chain (non-exclusive, multiple fire):
1. tmux ✅ status — writes `done` to `.status` file, tmux shows ✅ for 30s (requires tmux + statusline)
2. Terminal bell — `printf '\a'`
3. macOS Notification Center — `osascript` (skipped over SSH)
4. Linux desktop — `notify-send` (requires `$DISPLAY` or `$WAYLAND_DISPLAY`)

The notification includes the project name and a brief completion message.

The ✅ DONE status in the statusline tmux bar is driven by this hook — it sets the session status to `done` which auto-expires after 30 seconds.

### context-alert.sh

Fires on `Stop` events. Reads the current context usage percentage from the session state file and emits a warning if thresholds are exceeded.

| Threshold | Action |
|-----------|--------|
| ≥ 95% | Critical alert — context nearly full |
| ≥ 80% | Warning — consider starting a new session |

Alerts are sent via the same notification chain as `notify-on-stop.sh`.

Requires the statusline component for session state files (`~/.claude/sessions/<PID>.json`).

### usage-logger.sh

Fires on `SessionStart` and `SessionEnd` events. Appends a JSON line to `~/.claude/hooks/usage.jsonl` for each event.

JSONL format:

```json
{"event":"SessionStart","pid":12345,"project":"my-project","model":"claude-opus-4-5","timestamp":"2026-03-14T10:00:00Z"}
{"event":"SessionEnd","pid":12345,"project":"my-project","tokens":85200,"cost_usd":0.12,"duration_s":342,"timestamp":"2026-03-14T10:05:42Z"}
```

Fields:
- `event` — `SessionStart` or `SessionEnd`
- `pid` — Claude Code process ID
- `project` — project directory name
- `model` — model name from session state
- `tokens` — total tokens used (SessionEnd only)
- `cost_usd` — estimated cost in USD (SessionEnd only)
- `duration_s` — session duration in seconds (SessionEnd only)
- `timestamp` — ISO 8601 UTC timestamp

Requires the statusline component for session state files.

### daily-log.sh

Fires on `Stop` events. Appends the first 300 characters of Claude's last response with a timestamp to `~/.claude/daily-draft.md`. Summaries accumulate throughout the day.

To publish, run `daily-log-publish.sh` via cron:

```
0 0 * * * sh ~/.claude/hooks/daily-log-publish.sh
```

Configure in `~/.claude/.env`:

| Variable | Description |
|----------|-------------|
| `DAILY_LOG_MODE` | `local` (default) — write to `DAILY_LOG_DIR`; `git` — write to `DAILY_LOG_GIT_REPO/logs/` and push |
| `DAILY_LOG_DIR` | Log directory for local mode (default: `~/.claude/logs`) |
| `DAILY_LOG_GIT_REPO` | Git repo path for git mode |
| `DAILY_LOG_LLM_URL` | OpenAI-compatible API endpoint for summarization (optional) |
| `DAILY_LOG_LLM_KEY` | API key for the LLM endpoint (optional) |
| `DAILY_LOG_LLM_MODEL` | Model name (optional, default: `gpt-4o-mini`) |

If `DAILY_LOG_LLM_URL` is not set, session summaries are concatenated without AI processing. Supports any OpenAI-compatible endpoint: OpenAI, Claude API (via proxy), Ollama, LiteLLM, etc.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_HOOKS_ALLOW_DANGEROUS` | Set to `1` to bypass safety-guard blocks |
| `CLAUDE_HOOKS_ALLOW_SENSITIVE` | Set to `1` to bypass sensitive-files blocks |
| `DAILY_LOG_MODE` | `local` or `git` (daily-log) |
| `DAILY_LOG_DIR` | Log directory for local mode (daily-log) |
| `DAILY_LOG_GIT_REPO` | Git repo path for git mode (daily-log) |
| `DAILY_LOG_LLM_URL` | LLM endpoint for log summarization (daily-log) |
| `DAILY_LOG_LLM_KEY` | LLM API key (daily-log) |
| `DAILY_LOG_LLM_MODEL` | LLM model name (daily-log) |

## Prerequisites

| Requirement | Used By |
|-------------|---------|
| `jq` | usage-logger, context-alert (JSON parsing) |
| statusline component | context-alert, usage-logger (session state files) |
| `prettier` / `black` / `gofmt` etc. | auto-format (optional, skipped if absent) |
| `terminal-notifier` or `notify-send` | notify-on-stop (optional, falls back to tmux) |

## File Descriptions

| File | Description |
|------|-------------|
| `install.sh` | One-click installer |
| `uninstall.sh` | One-click uninstaller |
| `safety-guard.sh` | Dangerous command blocker (PreToolUse) |
| `sensitive-files.sh` | Sensitive file access blocker (PreToolUse) |
| `auto-format.sh` | Post-edit auto-formatter (PostToolUse) |
| `notify-on-stop.sh` | Completion notifier (Stop) |
| `context-alert.sh` | Context usage alerter (Stop) |
| `usage-logger.sh` | Session usage logger (Session) |
| `daily-log.sh` | Append session summary to draft (Stop) |
| `daily-log-publish.sh` | Consolidate draft and store log (cron) |
| `README.md` | This documentation (English) |
| `README.zh-TW.md` | Documentation (Traditional Chinese) |
