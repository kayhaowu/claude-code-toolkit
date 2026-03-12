# Claude Code Toolkit — GitHub Optimization Design

## Goal

Prepare the claude-code-toolkit project for public release on GitHub, targeting the international open-source community. Fix all known bugs, security issues, and documentation gaps before the initial public push.

## Scope

11 changes, each as an independent commit with clean git history.

---

## 1. Git History Rewrite

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

## 3. Add MIT LICENSE

- License: MIT
- Copyright holder: kayhaowu

## 4. Version Tracking

- Add `VERSION="1.0.0"` constant at top of `statusline/statusline-command.sh`
- Support `--version` flag: `sh statusline-command.sh --version` prints version
- `install.sh` displays version on completion

## 5. Fix Cross-Platform Bug — `heartbeat.sh`

**Problem:** `readlink -f "/proc/$TARGET_PID/cwd"` fails silently on macOS (no `/proc`).

**Fix:** Add `lsof` fallback:
```sh
_cwd=$(readlink -f "/proc/$TARGET_PID/cwd" 2>/dev/null) \
  || _cwd=$(lsof -a -p "$TARGET_PID" -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-) \
  || _cwd=""
```

## 6. Fix awk Command Injection — `statusline-command.sh` + `dashboard.sh`

**Problem:** Variables like `$tokens_used`, `$cost_usd` are interpolated directly into awk BEGIN blocks.

**Fix:** Use awk `-v` parameter for safe variable passing:
```sh
# Before (unsafe)
tokens_str=$(awk "BEGIN { printf \"%.1fk\", $tokens_used/1000 }")
# After (safe)
tokens_str=$(awk -v n="$tokens_used" 'BEGIN { printf "%.1fk", n/1000 }')
```

Apply to all awk calls in:
- `statusline-command.sh`: `tokens_str`, `cost_str`, `_show_cost`
- `dashboard.sh`: `fmt_k()`, `fmt_mem()`

## 7. Fix `install.sh` Hooks Overwrite

**Problem:** jq `*` merge overwrites user's existing SessionStart/SessionEnd hooks.

**Fix:** Append logic with three cases:
1. **hooks field doesn't exist** — create it
2. **hooks exist but don't contain our hook** — append to array
3. **hooks already contain our hook** (reinstall) — skip, don't duplicate

Detection: check if hook command string contains `heartbeat.sh` or `sessions/$PPID`.

## 8. Add `statusline/uninstall.sh`

Features:
1. Kill running heartbeat daemons
2. Clean session files (`~/.claude/sessions/*.json`, `*.hb.*`)
3. Remove installed scripts (`~/.claude/statusline-command.sh`, `statusline.sh`, `dashboard.sh`, `heartbeat.sh`, `tmux-sessions.sh`)
4. Remove `statusLine` key from `~/.claude/settings.json`
5. Remove only our hooks (entries containing `heartbeat.sh` or `sessions/$PPID`) from settings.json; if array becomes empty, remove the key; if `hooks` object becomes empty, remove it
6. Print suggestion for user to manually restore tmux settings (do NOT auto-revert)

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
> One-liner tagline

[English](README.md) | [繁體中文](README.zh-TW.md)

## Features
## Quick Start
## Themes
## Dashboard
## tmux Integration
## Configuration (env vars: SHOW_COST, THEME, NO_COLOR)
## Uninstall
## Contributing (brief)
## License
```

---

## Out of Scope

- Translating `docs/plans/` internal design files
- Adding CI/CD or automated tests
- New features beyond what exists today
