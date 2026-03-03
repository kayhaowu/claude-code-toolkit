# Design: Claude Code Status Line One-Click Installer

**Date:** 2026-03-03
**Status:** Approved

## Overview

Create a one-click installer for the Claude Code status line feature, organized in a `statusline/` directory with a README.md for documentation.

## Requirements

- Multi-platform support: macOS, Debian/Ubuntu, CentOS/RHEL
- Auto-detect OS and install `jq` dependency accordingly
- Auto-backup and merge `~/.claude/settings.json` if it already exists
- Folder structure with separate template file and README

## File Structure

```
statusline/
├── install.sh              # One-click installer entry point
├── statusline-command.sh   # Status line script template
└── README.md               # Usage documentation (Chinese)
```

## install.sh Flow

1. Detect OS (macOS / Debian-Ubuntu / CentOS-RHEL / unknown)
2. Check if `jq` is installed; auto-install if missing:
   - macOS: `brew install jq`
   - Debian/Ubuntu: `sudo apt install -y jq`
   - CentOS/RHEL: `sudo yum install -y jq`
   - Other: prompt manual install and exit
3. Create `~/.claude/` directory if it doesn't exist
4. Copy `statusline-command.sh` to `~/.claude/`
5. Set executable permission with `chmod +x`
6. Handle `~/.claude/settings.json`:
   - If missing: create new file with `statusLine` config
   - If exists: backup to `settings.json.backup`, merge `statusLine` with `jq`
7. Print success message, prompt user to restart Claude Code

## statusline-command.sh

Standalone POSIX shell script that:
- Reads JSON input from stdin (Claude Code status data)
- Extracts: model name, context window usage, tokens, git branch, project name
- Outputs colored status line using ANSI escape codes

## README.md Content

- Feature description with example output
- Quick install (one-liner)
- Manual install steps
- Color customization instructions
- Uninstall instructions
- Supported platforms

## Decisions

- **Separate template file** (Option B) chosen over single monolithic script for easier preview and customization
- **Auto-backup + merge** chosen for settings.json conflict handling to preserve existing user config
- **jq for JSON merging** to safely merge settings without regex or manual parsing
