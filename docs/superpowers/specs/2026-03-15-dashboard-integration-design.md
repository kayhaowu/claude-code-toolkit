# Dashboard Integration Design

**Date**: 2026-03-15
**Status**: Implemented
**Scope**: Phase 1 — Integrate claude-dev into claude-code-toolkit as `dashboard/`

## Overview

Integrate the claude-dev web monitoring platform into the claude-code-toolkit repository as a unified dashboard with two core modules: Session Monitor and Web Terminal. The existing claude-dev codebase is migrated via move-and-trim (approach A), preserving battle-tested collector logic while removing unused features.

## Goals

- Provide a real-time web dashboard for monitoring all active Claude Code sessions
- Enable browser-based terminal access to individual tmux windows
- Integrate cleanly with existing toolkit components (statusline, hooks, tmux)
- Cross-platform: macOS and Linux (WSL)

## Non-Goals (Phase 1)

- Workflow/pipeline visualizer (deferred to Phase 2)
- Spec/design document visualization (deferred to Phase 2)
- Per-pane terminal isolation within a multi-pane window (deferred to Phase 2)
- Jira or any project-tracker-specific integration

## Directory Structure

```
claude-code-toolkit/
├── statusline/          # Existing — shell scripts
├── hooks/               # Existing — shell scripts
├── tmux/                # Existing — tmux config & deploy
└── dashboard/           # NEW — web monitoring platform
    ├── frontend/        # React + Vite + Zustand (has package.json)
    ├── backend/         # Express + Socket.IO (has package.json)
    └── types/           # Shared TypeScript types (no package.json)
```

### Package Management

- Two independent `package.json` files: `frontend/` and `backend/`
- `types/` has no `package.json` — raw TypeScript source imported by both packages
- Each package manages its own `node_modules` and scripts independently
- Each package has its own `pnpm-lock.yaml` (no workspace-level coordination)

### Shared Types Import Strategy

**Backend** uses a local barrel file at `backend/src/types/index.ts` that re-exports from `../../types/src/types.ts`. All backend source files import via relative path to this barrel:

```typescript
import type { Session } from '../types/index.ts';
import { SCAN_INTERVAL_MS } from '../types/index.ts';
```

**Frontend** uses a Vite `resolve.alias` for convenience:

```typescript
import type { Session } from '@dashboard/types';
```

**frontend/vite.config.ts**:
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@dashboard/types': path.resolve(__dirname, '../types/src'),
    },
  },
  server: {
    host: '127.0.0.1',
    port: 3000,
    proxy: {
      '/api': 'http://127.0.0.1:3141',
      '/socket.io': { target: 'http://127.0.0.1:3141', ws: true },
    },
  },
});
```

### Runtime

Backend runs directly from TypeScript source using Node.js v24 native TypeScript support:

```bash
node --experimental-strip-types --experimental-transform-types src/index.ts
```

This avoids `tsx` ESM module resolution issues with Node v24. No separate build step needed for development or production.

### Shared TypeScript Base Config

`dashboard/tsconfig.base.json` — shared by both `frontend/tsconfig.json` and `backend/tsconfig.json` via `"extends": "../tsconfig.base.json"`.

## Module 1: Session Monitor

### Features

| Feature | Description |
|---------|-------------|
| Real-time session status | Socket.IO push, 2s polling interval |
| Session card | PID, project, model, token, cost, git branch, tmux window, "Open Terminal" button |
| Activity history | LogTailer reads JSONL via fs.watch |
| Task context | TaskInfo: commit message + task subject (replaces Jira ticket) |
| Status filter | Button bar: All / Working / Idle / Stopped |
| Text search | Search by project name, git branch, task subject, tmux window name |
| Connection status | Yellow banner on disconnect, auto-reconnect |
| Error boundary | React ErrorBoundary with "Try Again" and "Reload Page" |

### Data Sources

| Source | Reader | Frequency | Provides |
|--------|--------|-----------|----------|
| `~/.claude/sessions/{PID}.json` | SessionScanner | Polling every 2s | PID, project, model, tokens, cost, git branch |
| `~/.claude/sessions/{PID}.status` | SessionScanner | Polling every 2s | **status** (authoritative, event-driven source) |
| `~/.claude/sessions/{PID}.hb.dat` | SessionScanner | Polling every 2s | lastHeartbeat, memKb, status (fallback) |
| `~/.claude/projects/{slug}/*.jsonl` | LogTailer | fs.watch (event-driven) | currentActivity, taskInfo |
| `tmux list-panes -a` (tab-delimited) | TmuxMapper | Polling every 2s (with scanner) | tmux session/window/pane mapping |

### TaskInfo Type (Replaces TicketInfo)

```typescript
interface TaskInfo {
  /** Latest git commit message (from git tool use events) */
  commitMessage?: string;
  /** Current task subject (from TaskCreate/TaskUpdate events) */
  taskSubject?: string;
}
```

Extracted via `extractTaskInfo()` function in log-tailer, tested independently.

### Timestamps

All timestamps are in **epoch milliseconds** (matching `Date.now()`):
- `Session.startedAt` — converted from seconds at the scanner boundary
- `Session.lastHeartbeat` — converted from seconds at the scanner boundary
- `CurrentActivity.since` — already in milliseconds

### SessionStore Design

- **Immutable updates**: `updateActivity()` and `updateTaskInfo()` create new Session objects via spread, never mutate in-place
- **Status and activity are independent concerns**:
  - `status` (working/idle/stopped): **`.status` file is authoritative** (event-driven, written by `status-hook.sh` on UserPromptSubmit/PostToolUse/Stop events). SessionScanner reads `~/.claude/sessions/{PID}.status` first, falls back to `.hb.dat` heartbeat if `.status` not available. This matches the same priority used by `tmux-sessions.sh`.
  - `currentActivity` (which tool is in use): **LogTailer is the source**. Detected from JSONL logs in near real-time. Has a 120s staleness timeout — if no new activity for 2 minutes, resets to idle.
  - These are displayed separately on the SessionCard: status badge (green/yellow/red dot) vs. activity text (tool name or "idle").
  - The store never overrides scan-provided status — it trusts the scanner's result which reflects the `.status` file.
- **Phantom TTL**: Stopped sessions remain visible for 30s before removal
- **Activity staleness**: Resets to idle if no heartbeat for 2 minutes
- **Event-driven**: Emits `session:updated` and `session:removed` events

### Data Flow

```
SessionScanner ─┐
LogTailer ──────┤→ SessionStore (EventEmitter) → Socket.IO → Zustand → React
TmuxMapper ─────┘
```

## Module 2: Web Terminal

### Features

| Feature | Description |
|---------|-------------|
| Open Terminal button | On each non-stopped SessionCard with tmux mapping |
| Attach to tmux window | Grouped session via node-pty, one window per tab |
| True color support | `tmux -T 256,RGB,mouse,title` for 24-bit color |
| Catppuccin Mocha theme | Full 16-color ANSI palette in xterm.js |
| Nerd Font | JetBrainsMono Nerd Font loaded from CDN for icons |
| Multi-tab | Multiple terminals open simultaneously |
| Split pane | Horizontal/vertical split with drag divider |
| Error surfacing | Terminal errors shown in UI, auto-dismiss after 5s |

### Attach Strategy

```bash
# 1. Create grouped session
tmux new-session -d -s claude-view-{id} -t {originalSession}
tmux select-window -t claude-view-{id}:{targetWindow}
tmux select-pane -t claude-view-{id}:{targetWindow}.{targetPane}

# 2. Attach with true color support
tmux -T 256,RGB,mouse,title attach-session -t claude-view-{id}
```

- node-pty spawns the attach command with `TERM=xterm-256color` + `COLORTERM=truecolor`
- Cleanup: grouped session killed when tab closes or socket disconnects

**Limitation**: If a window contains multiple panes, all panes in that window are visible. Per-pane isolation is deferred to Phase 2.

### tmux Mapping (Cross-platform)

`TmuxMapper` uses tab-delimited `tmux list-panes` output to handle window names with spaces. `readPidTty` supports both platforms:
- **Linux**: reads `/proc/{pid}/fd/0` symlink
- **macOS**: uses `lsof -p {pid} -a -d 0 -Fn` to find controlling TTY

TTY path validation accepts any `/dev/*` path (covers `/dev/pts/X` on Linux, `/dev/ttysXXX` on macOS, `/dev/ttyXX` on FreeBSD).

### UI Model

Terminal is embedded within the Session Monitor page (not a separate route):

- Session Monitor (`/`) is the only page
- Clicking "Open Terminal" on a session card opens a terminal panel at the bottom (40vh)
- Terminal panel shows xterm.js with Catppuccin Mocha theme
- Multiple terminals via split pane (right-click context menu)
- Session grid shrinks to 60vh when terminal panel is open

### xterm.js Configuration

```typescript
{
  scrollback: 5000,
  fontFamily: '"JetBrainsMono Nerd Font", "JetBrains Mono", "Fira Code", monospace',
  fontSize: 14,
  theme: { /* Catppuccin Mocha full 16-color palette */ },
}
```

Nerd Font loaded via CSS `@font-face` from jsDelivr CDN for powerline/icon glyph support.

## Error Handling

### Backend

- All catch blocks log warnings with context (file, PID, error)
- ENOENT errors silenced (expected for missing files/tmux not installed)
- `isProcessAlive`: EPERM treated as alive (process exists but owned by another user)
- WebSocket input validation: `terminal:resize` checks `Number.isInteger`, `terminal:input` validates types, `terminal:reconnect` validates array
- `terminal:open` cwd validation: must be under `$HOME` or `/tmp`, uses trailing-slash prefix check
- `terminal:open` error messages sanitized (known prefixes pass through, generic message for unexpected errors)
- `disconnect` handler wrapped in try-catch

### Frontend

- `ErrorBoundary`: class component catching render errors, "Try Again" + "Reload Page" buttons
- `ConnectionBanner`: yellow banner on socket disconnect, shows error message
- `connection-store`: Zustand store tracking `connected` and `error` state, preserves error on disconnect
- Terminal error: `terminal:error` events stored in terminal-store, auto-dismissed after 5s with timer deduplication

## API Surface

### REST Endpoints

```
GET  /api/sessions          # Full session snapshot
POST /api/hooks             # Hook receiver (from Claude CLI)
```

### Socket.IO Events

```
Server → Client:
  sessions:snapshot         { sessions: Session[] }
  session:updated           { session: Session }
  session:removed           { id: string }
  terminal:sessions         { sessions: TerminalSession[] }
  terminal:opened           { session: TerminalSession }
  terminal:output:{id}      Buffer (raw PTY output)
  terminal:closed           { sessionId: string }
  terminal:error            { message: string }

Client → Server:
  terminal:open             { mode: 'attach' | 'new', sessionPid?: number, cwd?: string }
  terminal:input            { sessionId: string, data: string }
  terminal:resize           { sessionId: string, cols: number, rows: number }
  terminal:close            { sessionId: string }
  terminal:reconnect        { sessionIds: string[] }
```

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Backend runtime | Node.js | >= 24 (native TS via --experimental-strip-types) |
| Backend framework | Express | 4.x |
| Real-time | Socket.IO | 4.x |
| Terminal PTY | node-pty | 1.2.0-beta.12 |
| Frontend framework | React | 18.x |
| Build tool | Vite | 6.x |
| State management | Zustand | 5.x |
| Styling | Tailwind CSS | 3.x |
| Terminal rendering | xterm.js | 6.x |
| Terminal font | JetBrainsMono Nerd Font | CDN |
| Routing | React Router DOM | 7.x |
| Testing | Vitest | 3.x |
| Language | TypeScript | 5.7+ (strict) |

## Testing

- Backend: 70 tests across 9 files (session-store, routes, session-scanner, session-scanner-scan, log-tailer, log-tailer-taskinfo, tmux-mapper, hook-receiver, terminal-manager)
- Frontend: 48 tests across 6 files (SessionCard, TerminalContextMenu, use-socket, use-terminal-socket, session-store, terminal-store)
- Both `tsc --noEmit` clean

## Decisions (Resolved)

1. **Deployment** — `docker-compose up -d` one-command deploy. Dockerfile installs tmux + build tools, pins pnpm version.
2. **Production serving** — Backend (Express) serves built frontend static files from `frontend/dist/`. Dev mode: Vite dev server on :3000 with proxy to backend :3141. Production: single server serves both API and static assets.
3. **Port** — `3141` (default, configurable via `PORT` env var).
4. **Access control** — Local-only. Backend binds to `127.0.0.1` (not `0.0.0.0`). Docker maps `127.0.0.1:3141:3141`. No authentication in Phase 1.
5. **Lock files** — Each package (`frontend/`, `backend/`) has its own independent `pnpm-lock.yaml`.
6. **Runtime** — Node.js v24 native TypeScript support (`--experimental-strip-types --experimental-transform-types`) instead of tsx, due to ESM module resolution incompatibility with tsx on Node v24.
7. **Terminal colors** — tmux `-T 256,RGB,mouse,title` flag for per-client true color. xterm.js uses Catppuccin Mocha theme. Nerd Font from CDN.

## Statusline Enhancement

As part of this integration, `statusline/tmux-sessions.sh` was enhanced:
- Per-status colors using tmux style tags (Catppuccin Mocha palette)
- Working (⚡) → yellow `#f9e2af`
- Idle (💤) → blue `#89b4fa`
- Done (✅) → green `#a6e3a1`
- Separator (│) → purple `#bd93f9`
- Space between icon and session name for readability
