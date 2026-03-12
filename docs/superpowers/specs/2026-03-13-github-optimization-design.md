# Claude Code Toolkit — GitHub Optimization Design

## Goal

Prepare the claude-code-toolkit project for public release on GitHub, targeting the international open-source community. Fix all known bugs, security issues, and documentation gaps before the initial public push.

## Scope

11 changes in sequential order (some have implicit dependencies). Each change is a separate commit.

## Commit Order

Steps must be executed in numbered order:
1. Git history rewrite (must be first — rewrites all hashes)
2–4. Infrastructure (.gitignore, LICENSE, version) — independent of each other but after step 1
5–7. Bug fixes — independent of each other
8. Uninstall script (references files from step 7's fixed install.sh)
9–10. Doc cleanup — independent
11. README internationalization (must be last — references final state of all files)

---

## 1. Git History Rewrite

- Create a backup branch `backup/pre-rewrite` before the operation
- Rewrite all 28 commits: author/committer from `kay_wu <kay_wu@edge-core.com>` to `kayhaowu <ak0789456@gmail.com>`
- Use `git filter-repo` (repo-local only, no global config changes)
- Remove old GitLab origin
- Add new remote: `git@github.com:kayhaowu/claude-code-toolkit.git`

## 2. Add `.gitignore`

```
.claude/
.DS_Store
*.swp
*.swo
*~
```

Note: `.claude/` in the repo root (currently untracked) will be ignored — this is intentional, it contains local settings.

## 3. Add MIT LICENSE

- License: MIT
- Copyright holder: kayhaowu

## 4. Version Tracking

- Add `VERSION="1.0.0"` constant at top of `statusline/statusline-command.sh`
- **`--version` must be checked before `input=$(cat)`** to avoid blocking on stdin:
  ```sh
  VERSION="1.0.0"
  if [ "${1:-}" = "--version" ]; then echo "$VERSION"; exit 0; fi
  input=$(cat)
  ```
- `install.sh` displays version on completion (read from the installed script)

## 5. Fix Cross-Platform Bug — `heartbeat.sh`

**Problem:** `readlink -f "/proc/$TARGET_PID/cwd"` fails on macOS — both because `/proc` doesn't exist and because macOS `readlink` doesn't support `-f`.

**Fix:** Linux path via `/proc`, macOS path via `lsof`:
```sh
_cwd=$(readlink -f "/proc/$TARGET_PID/cwd" 2>/dev/null) \
  || _cwd=$(lsof -a -p "$TARGET_PID" -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-) \
  || _cwd=""
```

The `readlink` branch is Linux-only; the `lsof` branch is the macOS codepath.

## 6. Fix awk Command Injection — `statusline-command.sh` + `dashboard.sh`

**Problem:** Variables are interpolated directly into awk BEGIN blocks.

**Fix:** Use awk `-v` parameter for safe variable passing:
```sh
# Before (unsafe)
tokens_str=$(awk "BEGIN { printf \"%.1fk\", $tokens_used/1000 }")
# After (safe)
tokens_str=$(awk -v n="$tokens_used" 'BEGIN { printf "%.1fk", n/1000 }')
```

**Complete inventory of vulnerable awk calls (6 total):**

`statusline-command.sh` (3 calls):
1. Line 194: `tokens_str` formatting (`$tokens_used`)
2. Line 204: `_show_cost` threshold check (`$cost_usd`)
3. Line 206: `cost_str` formatting (`$cost_usd`)

`dashboard.sh` (4 calls):
1. Line 34: `fmt_k()` — million formatting (`$n`)
2. Line 36: `fmt_k()` — thousand formatting (`$n`)
3. Line 45: `fmt_mem()` — GB formatting (`$kb`)
4. Line 47: `fmt_mem()` — MB formatting (`$kb`)

## 7. Fix `install.sh` Hooks Overwrite

**Problem:** jq `*` merge overwrites user's existing SessionStart/SessionEnd hooks.

**Fix:** Append logic with three cases:
1. **hooks field doesn't exist** — create it
2. **hooks exist but don't contain our hook** — append to array
3. **hooks already contain our hook** (reinstall) — skip, don't duplicate

Detection: check if hook command string contains the **literal** string `heartbeat.sh` (for SessionStart) or `sessions/$PPID` (for SessionEnd). These are literal strings stored in JSON, not expanded shell variables.

## 8. Add `statusline/uninstall.sh`

Features:
1. Kill running heartbeat daemons (find PIDs from `~/.claude/sessions/*.hb.pid`)
2. Clean session files: `*.json`, `*.hb.dat`, `*.hb.pid` in `~/.claude/sessions/`
3. Remove installed scripts: `~/.claude/statusline-command.sh`, `~/.claude/statusline.sh` (symlink), `~/.claude/dashboard.sh`, `~/.claude/heartbeat.sh`, `~/.claude/tmux-sessions.sh`
4. Remove `statusLine` key from `~/.claude/settings.json`
5. Remove only our hooks (entries with command containing literal `heartbeat.sh` or `sessions/$PPID`) from settings.json; if array becomes empty, remove the key; if `hooks` object becomes empty, remove it
6. Print tmux restore suggestion with exact commands:
   ```
   If you were using tmux integration, run:
     tmux set-option -g status 1
     tmux set-option -gu status-format[1]
   ```
7. Each step prints status: removed / not found (skipped)

**Not copied to `~/.claude/`** — users run from cloned repo or re-clone to uninstall.

## 9. Redirect `claude-code-statusline-setup.md`

Replace content with:
```markdown
# Claude Code Status Line Setup

This guide has moved to [`statusline/README.md`](statusline/README.md).
```

## 10. Add `docs/plans/README.md`

```markdown
# Development Plans

Internal design documents and implementation plans created during development.
These are preserved as historical reference and are not required for using the toolkit.
```

The 6 Chinese design files in `docs/plans/` are kept as-is (no translation needed).

## 11. README Internationalization

### Files changed:
| File | Action |
|------|--------|
| `README.md` | Rewrite in English |
| `README.zh-TW.md` | New, preserve current Chinese content |
| `statusline/README.md` | Rewrite in English |
| `statusline/README.zh-TW.md` | New, preserve current Chinese content |

### Language switcher at top of each README:
```
[English](README.md) | [繁體中文](README.zh-TW.md)
```

### Root `README.md` English structure:
```
# Claude Code Toolkit
> A collection of tools and utilities for enhancing the Claude Code CLI experience.

[English](README.md) | [繁體中文](README.zh-TW.md)

## Features
- Custom status line (model, context bar, tokens, cost, git branch, project)
- 5 color themes + NO_COLOR support
- Multi-instance dashboard
- tmux real-time session monitor
- One-click installer (macOS, Ubuntu/Debian, CentOS/RHEL)

## Quick Start
bash statusline/install.sh

## Themes
(table of 5 themes with descriptions)

## Dashboard
(usage + screenshot example)

## tmux Integration
(automatic setup + manual commands)

## Configuration
(CLAUDE_STATUSLINE_THEME, CLAUDE_STATUSLINE_SHOW_COST, NO_COLOR)

## Uninstall
bash statusline/uninstall.sh
(+ manual steps reference)

## Contributing
Brief: issues, PRs welcome, describe the change.

## License
MIT
```

Content is derived from existing Chinese README — translate and adapt, not rewrite from scratch.

---

## Out of Scope

- Translating `docs/plans/` internal design files
- Adding CI/CD or automated tests
- New features beyond what exists today
