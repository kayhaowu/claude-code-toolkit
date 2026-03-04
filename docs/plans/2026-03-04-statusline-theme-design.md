# StatusLine Theme & Segment System — Design

## Overview

Rewrite `statusline-command.sh` to add a theme system with semantic color tokens, new segments (cost, 200k alert), git cache, and NO_COLOR support — while preserving existing features (progress bar, multi-session second line, session state write).

## Theme System

### 5 Themes

| Theme | Type | Description |
|-------|------|-------------|
| `ansi-default` | 16-color ANSI | Default, universal compatibility |
| `catppuccin-mocha` | TrueColor 24-bit | Pastel theme, good contrast |
| `dracula` | TrueColor 24-bit | Vibrant purples and pinks |
| `nord` | TrueColor 24-bit | Arctic blue, muted tones |
| `none` | No color | NO_COLOR compliant |

### Theme Selection

```
NO_COLOR=1                          → forces "none" (highest priority)
CLAUDE_STATUSLINE_THEME=<name>      → use specified theme
neither set                         → use "ansi-default"
```

### 12 Semantic Color Tokens

| Token | Purpose |
|-------|---------|
| `C_MODEL` | Model name |
| `C_BAR_FILL` | Progress bar filled blocks |
| `C_BAR_EMPTY` | Progress bar empty blocks |
| `C_CTX_OK` | Context % when ≤60% used (safe) |
| `C_CTX_WARN` | Context % when 60-80% used |
| `C_CTX_BAD` | Context % when >80% used |
| `C_TOKENS` | Token count |
| `C_COST` | Cost display |
| `C_ALERT` | 200k token alert |
| `C_BRANCH` | Git branch |
| `C_PROJECT` | Project name |
| `C_SEP` | Separator `│` |
| `C_RESET` | Reset all formatting |

## Segments (8 total)

| # | Segment | Source | Display |
|---|---------|--------|---------|
| 1 | Model | `model.display_name` | Direct display |
| 2 | Progress bar | `context_window.used_percentage` | `[████████░░░░]` visual bar |
| 3 | Context % | same | Color-coded: OK ≤60%, WARN 60-80%, BAD >80% |
| 4 | Tokens | `total_input + total_output` | `45.2k tokens` with k suffix |
| 5 | Cost | `cost.total_cost_usd` | `est $X.XX`, shown only when ≥$0.005 |
| 6 | 200k alert | `exceeds_200k_tokens` | Bold warning when true |
| 7 | Git branch | shell `git` | ` branch-name`, 5s cache |
| 8 | Project | `workspace.project_dir` | basename |

## Second Line (preserved)

```
↳ project1 [WORKING 42% 10.3k] │ project2 [IDLE 88% 25.0k]
```

Colors follow theme system.

## Session State Write (preserved)

Continues writing `~/.claude/sessions/$PPID.json` for dashboard.

## Git Cache (new)

- Path: `/tmp/claude-statusline-git-cache-$(id -u)`
- TTL: 5 seconds
- Prevents frequent `git` invocations on every statusline render

## Output Examples

### ansi-default
```
Opus 4.6 │ [████████████░░░░░░░░] │ 60% │ 45.2k tokens │ est $0.12 │  main │ my-project
↳ other-project [WORKING 42% 10.3k]
```

### NO_COLOR=1
```
Opus 4.6 | [============........] | 60% | 45.2k tokens | est $0.12 | main | my-project
```

## Files Changed

- `statusline/statusline-command.sh` — full rewrite
- No changes to `install.sh` or other files

## Dependencies

- `jq` (existing requirement)
- `git` (existing optional requirement)
