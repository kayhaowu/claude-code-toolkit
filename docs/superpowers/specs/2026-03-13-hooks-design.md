# Claude Code Hooks Collection

## Problem

Claude Code supports hooks for automating workflows, but users have to write their own scripts from scratch. Common needs — completion notifications, safety guards, auto-formatting, usage logging — are universal but tedious to implement correctly, especially handling stdin JSON parsing, matcher configuration, and settings.json merging.

## Goals

- Provide 6 ready-to-use hooks as a standalone `hooks/` component
- One-click installer with sensible defaults (security hooks ON, optional hooks OFF)
- Works independently from statusline, with graceful degradation for hooks that benefit from session data
- Support both GUI and headless/server/SSH environments

## Non-Goals

- Custom hook authoring framework — users can add their own hooks manually
- Hook configuration UI — toggling is via `install.sh` / `uninstall.sh` or manual `settings.json` editing
- Supporting formatters beyond the big four (prettier, black, gofmt, clang-format)
- Cost tracking — statusline already handles estimated cost display

## Prerequisites

- `jq` (install.sh will install if missing, same as statusline)
- For `usage-logger`, `context-alert`, and `notify-on-stop` tmux ✅ feature: statusline must be installed (provides session JSON)

## Design

### Directory Structure

```
hooks/
├── install.sh              # Layered installer
├── uninstall.sh            # One-click removal
├── notify-on-stop.sh       # Completion notification (Stop)
├── safety-guard.sh         # Dangerous command guard (PreToolUse: Bash)
├── sensitive-files.sh      # Sensitive file protection (PreToolUse: Read|Edit|Write)
├── auto-format.sh          # Auto-format after edit (PostToolUse: Edit|Write)
├── usage-logger.sh         # Session usage log (SessionStart + SessionEnd)
├── context-alert.sh        # Context usage warning (Stop)
├── README.md
└── README.zh-TW.md
```

All scripts are symlinked to `~/.claude/hooks/` (separate from statusline scripts in `~/.claude/`). Symlinks point back to the repo so that `git pull` automatically updates installed hooks without re-running the installer.

### PID Resolution

All hooks that need the Claude process PID receive it as a command-line argument via `$PPID` in the hook command string. Claude Code spawns `sh -c "<command>"` to run each hook; `$PPID` in that `sh -c` context resolves to the Claude Code process — the same proven pattern used by `status-hook.sh` and `heartbeat.sh` in the statusline component.

Hooks that only read stdin JSON (safety-guard, sensitive-files, auto-format) do not need the PID.

### Hook → Event Mapping

| Hook Script | Event | Matcher | Command | stdin Fields Used |
|-------------|-------|---------|---------|-------------------|
| `safety-guard.sh` | PreToolUse | `Bash` | `sh ~/.claude/hooks/safety-guard.sh` | `tool_input.command` |
| `sensitive-files.sh` | PreToolUse | `Read\|Edit\|Write` | `sh ~/.claude/hooks/sensitive-files.sh` | `tool_input.file_path` |
| `auto-format.sh` | PostToolUse | `Edit\|Write` | `sh ~/.claude/hooks/auto-format.sh` | `tool_input.file_path` |
| `notify-on-stop.sh` | Stop | — | `sh ~/.claude/hooks/notify-on-stop.sh $PPID` | `stop_hook_active` |
| `context-alert.sh` | Stop | — | `sh ~/.claude/hooks/context-alert.sh $PPID` | `stop_hook_active` |
| `usage-logger.sh` | SessionStart | — | `sh ~/.claude/hooks/usage-logger.sh start $PPID` | `session_id`, `cwd`, `model` |
| `usage-logger.sh` | SessionEnd | — | `sh ~/.claude/hooks/usage-logger.sh end $PPID` | `session_id` |

**Tool name verification:** Matchers are case-sensitive capitalized names (`Bash`, `Read`, `Edit`, `Write`). Field names `tool_input.command` and `tool_input.file_path` match Claude Code's internal schema. The pipe `|` separator in matchers (e.g., `Read|Edit|Write`) is Claude Code's built-in OR syntax.

### Layered Default Installation

**Recommended (ON by default):**
- `notify-on-stop` — Desktop/tmux notification when Claude finishes
- `safety-guard` — Block dangerous commands (rm -rf, force push, etc.)
- `sensitive-files` — Block access to .env, credentials, *.key files

**Optional (OFF by default):**
- `auto-format` — Auto-format files after edit (detects prettier/black/gofmt)
- `usage-logger` — Log session usage to `~/.claude/hooks/usage.jsonl`
- `context-alert` — Warn when context usage exceeds 80%

Install flow:
```
Install recommended hooks? [Y/n]
  - notify-on-stop     Desktop notification when Claude finishes
  - safety-guard       Block dangerous commands (rm -rf, force push, etc.)
  - sensitive-files    Block access to .env, credentials, *.key files

Also enable optional hooks? [y/N]
  - auto-format        Auto-format files after edit (detects prettier/black/gofmt)
  - usage-logger       Log session usage to ~/.claude/hooks/usage.jsonl
  - context-alert      Warn when context usage exceeds 80%
```

### Hook Behavior Details

#### notify-on-stop.sh (Stop)

**PID argument:** Receives Claude PID as `$1` (from `$PPID` in command string).

**Time threshold:** Only triggers when working time > 30 seconds. Reads `~/.claude/sessions/$1.status` to get the last `working` timestamp and calculates elapsed time. Short responses produce no notification.

**Notification fallback chain (non-exclusive, multiple fire):**

| Order | Condition | Action |
|-------|-----------|--------|
| 1 | In tmux + statusline installed | Write `done` to `.status`, tmux shows ✅. Auto-expires to 💤 after 30s |
| 2 | Always | `printf '\a'` terminal bell |
| 3 | macOS + not SSH (`$SSH_TTY` unset) | `osascript` push to Notification Center |
| 4 | Linux + `$DISPLAY` or `$WAYLAND_DISPLAY` set | `notify-send` |

Notification content: `"Task complete (45s) — my-project"` (project name from session JSON).

**`done` status lifecycle:**
- `notify-on-stop.sh` writes `done <epoch>` to `.status` (overrides `idle` written by `status-hook.sh` earlier in the same Stop event)
- `tmux-sessions.sh` displays ✅ when `done` and age < 30s, 💤 when age ≥ 30s
- Next `UserPromptSubmit` → `status-hook.sh` writes `working`, overriding `done`

#### safety-guard.sh (PreToolUse, matcher: Bash)

Reads `tool_input.command` from stdin JSON. Matches against blocklist patterns:

| Pattern | Blocked | Allowed |
|---------|---------|---------|
| `rm -rf /`, `rm -rf ~`, `rm -rf .` | Yes | `rm -rf node_modules`, `rm -rf dist` |
| `git push --force` | Yes | `git push --force-with-lease` |
| `DROP TABLE`, `DROP DATABASE` | Yes | — |
| `curl ... \| sh`, `wget ... \| sh` | Yes | `curl` without pipe to shell |
| `chmod 777` | Yes | `chmod 755`, `chmod +x` |
| `> /dev/sda`, `dd if=... of=/dev/` | Yes | — |
| `mkfs.` | Yes | — |

On match: `exit 2`, stderr explains why (fed back to Claude as context).

**Bypass:** Set `CLAUDE_HOOKS_ALLOW_DANGEROUS=1` environment variable.

#### sensitive-files.sh (PreToolUse, matcher: Read|Edit|Write)

Reads `tool_input.file_path` from stdin JSON. Matches against sensitive patterns:

- `.env`, `.env.*`, `.env.local`, `.env.production`
- `*credentials*`, `*secret*`, `*secrets*`
- `*.key`, `*.pem`, `*.p12`, `*.pfx`
- `id_rsa`, `id_ed25519`, `id_ecdsa`
- `~/.ssh/*`, `~/.aws/*`, `~/.gnupg/*`
- `*password*`, `*token*` (matched against `basename` of file path only — avoids false positives from path components like `/tokens/config.json`)

On match: `exit 2`, stderr explains why.

**Bypass:** Set `CLAUDE_HOOKS_ALLOW_SENSITIVE=1` environment variable.

#### auto-format.sh (PostToolUse, matcher: Edit|Write)

Reads `tool_input.file_path` from stdin JSON. Detection order:

| Priority | Condition | Formatter | File Types |
|----------|-----------|-----------|------------|
| 1 | `.prettierrc*` exists, or `package.json` has `prettier` in `dependencies`/`devDependencies` | `npx prettier --write` | `.js`, `.ts`, `.tsx`, `.css`, `.json`, `.md` |
| 2 | `pyproject.toml` or `setup.cfg` exists | `black` | `.py` |
| 3 | `go.mod` exists or file is `.go` | `gofmt -w` | `.go` |
| 4 | `.clang-format` exists | `clang-format -i` | `.c`, `.cpp`, `.h`, `.hpp` |

- Formatter command not found → silently skip (`exit 0`)
- File extension doesn't match → silently skip
- Format succeeds → `exit 0`, no stdout (avoids interfering with Claude)
- Format fails → non-blocking, stderr logged in verbose mode

#### usage-logger.sh (SessionStart + SessionEnd)

**PID argument:** Receives Claude PID as `$2` (after `start`/`end` subcommand, from `$PPID` in command string).

**SessionStart:** Creates temp file `~/.claude/hooks/sessions/<PID>.tmp.json`:
```json
{"session_id":"abc","project":"my-proj","model":"claude-sonnet-4-6","start":"2026-03-13T10:00:00Z"}
```

`project` derived from `cwd` field in stdin JSON (basename). `model` read directly from stdin JSON `model` field (always present in SessionStart events).

**SessionEnd:** Reads temp file + `~/.claude/sessions/<PID>.json` (if statusline installed), appends one line to `~/.claude/hooks/usage.jsonl`:
```json
{"session_id":"abc","project":"my-proj","model":"opus-4","start":"2026-03-13T10:00:00Z","end":"2026-03-13T10:30:00Z","duration_s":1800,"tokens":85200}
```

If statusline not installed, `tokens` field is omitted. Cleans up temp file.

**Log directory:** `~/.claude/hooks/sessions/` for temp files, `~/.claude/hooks/usage.jsonl` for persistent log.

#### context-alert.sh (Stop)

**PID argument:** Receives Claude PID as `$1` (from `$PPID` in command string).

Reads `~/.claude/sessions/<PID>.json` to get `used_pct`.

| Context % | Action |
|-----------|--------|
| < 80% | Silent, `exit 0` |
| 80-94% | `{"systemMessage": "⚠ Context usage at <actual>%. Consider using /compact to free up space."}` |
| ≥ 95% | `{"systemMessage": "⚠ Context nearly full (<actual>%). Recommend /compact now to avoid auto-compaction."}` |

Requires statusline installed. If session JSON doesn't exist, silently exits.

### Stop Hook Execution Order

Settings.json Stop hooks array order matters — Claude Code executes sequentially:

1. `status-hook.sh` → writes `idle` to `.status`, **preserving the epoch from the previous `working` entry** (so notify-on-stop can calculate elapsed working time)
2. `notify-on-stop.sh` → reads preserved epoch, if elapsed > 30s, overwrites `.status` with `done`; otherwise leaves `idle`
3. `context-alert.sh` → reads session JSON, returns systemMessage if needed

Updated file ownership model:

| File | Writers |
|------|---------|
| `<PID>.json` | `statusline-command.sh` |
| `<PID>.status` | `status-hook.sh` (working/idle), `notify-on-stop.sh` (done, conditional overwrite) |
| `<PID>.hb.dat` | `heartbeat.sh` |

### settings.json Structure

Example with all hooks enabled (statusline hooks shown for ordering context):
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "sh ~/.claude/hooks/safety-guard.sh"}]
      },
      {
        "matcher": "Read|Edit|Write",
        "hooks": [{"type": "command", "command": "sh ~/.claude/hooks/sensitive-files.sh"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "sh ~/.claude/hooks/auto-format.sh"}]
      }
    ],
    "Stop": [
      {
        "hooks": [{"type": "command", "command": "sh ~/.claude/status-hook.sh $PPID idle"}]
      },
      {
        "hooks": [{"type": "command", "command": "sh ~/.claude/hooks/notify-on-stop.sh $PPID"}]
      },
      {
        "hooks": [{"type": "command", "command": "sh ~/.claude/hooks/context-alert.sh $PPID"}]
      }
    ],
    "SessionStart": [
      {
        "hooks": [{"type": "command", "command": "sh ~/.claude/hooks/usage-logger.sh start $PPID"}]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [{"type": "command", "command": "sh ~/.claude/hooks/usage-logger.sh end $PPID"}]
      }
    ]
  }
}
```

`install.sh` uses `test("hooks/")` guard pattern to avoid conflicting with statusline hooks (which use `test("status-hook\\.sh")`, `test("heartbeat\\.sh")`).

**stdin consumption pattern:** All hooks that read stdin must consume it once into a variable at script start: `_input=$(cat)`. Then use `echo "$_input" | jq ...` for subsequent field extraction. stdin is a stream and can only be read once.

**Stop hook loop prevention:** Stop hooks receive `stop_hook_active` boolean in stdin JSON. If `true`, the hook was triggered because Claude continued after a previous Stop hook's `systemMessage`. `context-alert.sh` should check this field and `exit 0` immediately if `true` to avoid infinite warning loops.

### Install / Uninstall

**hooks/install.sh:**
1. Check statusline installed (`~/.claude/statusline-command.sh` exists)
   - If not: skip `usage-logger`, `context-alert`, and `notify-on-stop` tmux ✅ feature (bell + OS notification still work)
   - Print: `"For full hook support, install statusline first: bash statusline/install.sh"`
2. Install `jq` if missing (same OS detection as statusline)
3. Create symlinks from `~/.claude/hooks/` → repo source (skip files that already exist as regular files to avoid overwriting user's own scripts)
4. Two-step Y/N confirmation for hook selection
5. Backup `settings.json` → `settings.json.backup`
6. jq merge into `settings.json` (idempotent, `any(test("hooks/"))` guard)
7. **Stop array ordering enforcement:** After merging, reorder the Stop array to guarantee: `status-hook.sh` entries first, then `notify-on-stop.sh`, then `context-alert.sh`, then any other entries. Algorithm:
   ```
   .hooks.Stop = (
     [.hooks.Stop[] | select(.hooks[]?.command | test("status-hook"))] +
     [.hooks.Stop[] | select(.hooks[]?.command | test("notify-on-stop"))] +
     [.hooks.Stop[] | select(.hooks[]?.command | test("context-alert"))] +
     [.hooks.Stop[] | select(.hooks[]?.command | (test("status-hook|notify-on-stop|context-alert") | not))]
   )
   ```
   This ensures correct ordering even if statusline is reinstalled after hooks.

**hooks/uninstall.sh:**
1. jq remove all entries with command matching `hooks/` path
2. Clean up empty arrays and empty hooks objects
3. Delete `~/.claude/hooks/` directory
4. Does not touch statusline hooks (pattern `hooks/` vs `status-hook\.sh` — no overlap)

### Integration with Existing Components

**tmux/deploy.sh** — add third prompt after statusline:
```
1. Also install Claude Code statusline? [y/N]
2. Also install Claude Code hooks? [y/N]
   (Note: usage-logger and context-alert require statusline)
```
If step 1 = N and step 2 = Y, hooks install auto-skips statusline-dependent hooks with message.

**statusline/tmux-sessions.sh** — support `done` status:
- Read `.status` file with `{ read -r _status _status_epoch < file; } 2>/dev/null` (brace-group suppresses redirect errors for missing files)
- Calculate age: `$(( _now - _status_epoch ))`
- `done` + age < 30s → display ✅
- `done` + age ≥ 30s → display 💤 (auto-expire, same icon as `idle`)

**statusline/dashboard.sh** — support `done` status:
- Display as `DONE` in STATUS column

**statusline/README.md + README.zh-TW.md** — add ✅ `done` status explanation to status icons table.

**Root README.md + README.zh-TW.md** — add Hooks section with overview and install command.

## Testing

1. **Fresh install (with statusline):** All 6 hooks installed, settings.json correct
2. **Fresh install (without statusline):** 3 hooks skipped with message, remaining 3 work
3. **Idempotent:** Re-run install.sh, no duplicate entries
4. **safety-guard:** `rm -rf /` blocked, `rm -rf node_modules` allowed, `CLAUDE_HOOKS_ALLOW_DANGEROUS=1` bypasses
5. **sensitive-files:** `.env` blocked, normal files allowed, `CLAUDE_HOOKS_ALLOW_SENSITIVE=1` bypasses
6. **auto-format:** Detects prettier in JS project, black in Python project, skips when no formatter
7. **notify-on-stop:** Short response (< 30s) → no notification; long task → bell + tmux ✅ + OS notification
8. **done status:** tmux shows ✅ for 30s then auto-expires to 💤
9. **usage-logger:** SessionStart creates temp, SessionEnd writes JSONL with correct fields
10. **context-alert:** At 85% → systemMessage warning; at 50% → silent
11. **uninstall:** All hook entries removed, statusline hooks untouched
12. **deploy.sh:** Remote hooks install works with and without statusline
