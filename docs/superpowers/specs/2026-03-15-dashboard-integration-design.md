# Dashboard Integration Design

**Date**: 2026-03-15
**Status**: Draft
**Scope**: Phase 1 — Integrate claude-dev into claude-code-toolkit as `dashboard/`

## Overview

Integrate the claude-dev web monitoring platform into the claude-code-toolkit repository as a unified dashboard with two core modules: Session Monitor and Web Terminal. The existing claude-dev codebase is migrated via move-and-trim (approach A), preserving battle-tested collector logic while removing unused features.

## Goals

- Provide a real-time web dashboard for monitoring all active Claude Code sessions
- Enable browser-based terminal access to individual tmux windows
- Integrate cleanly with existing toolkit components (statusline, hooks, tmux)
- Cross-platform: macOS and Windows (WSL)

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
- `types/` has no `package.json` — imported via relative paths from both frontend and backend
- Each package manages its own `node_modules` and scripts independently
- Each package has its own `pnpm-lock.yaml` (no workspace-level coordination)

### Shared Types Import Strategy

**No path aliases.** Both frontend and backend import types via relative paths to avoid runtime resolution issues. `tsc` does not rewrite path aliases in emitted JS, and Node.js cannot resolve them without additional tooling.

**backend** (TypeScript source, compiled with `tsc`, run with `tsx`):
```typescript
import type { Session } from '../../types/src/index.js';
```

**frontend** (bundled by Vite — Vite resolves TS imports at build time):
```typescript
// vite.config.ts adds resolve.alias for convenience:
// '@dashboard/types' → path.resolve(__dirname, '../types/src')
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
    port: 3000,
    proxy: {
      '/api': 'http://localhost:3001',
      '/socket.io': { target: 'http://localhost:3001', ws: true },
    },
  },
});
```

### Shared TypeScript Base Config

Migrate `claude-dev/tsconfig.base.json` → `dashboard/tsconfig.base.json`. Both `frontend/tsconfig.json` and `backend/tsconfig.json` extend it via `"extends": "../tsconfig.base.json"`.

## Module 1: Session Monitor

### Features

| Feature | Source | Changes |
|---------|--------|---------|
| Real-time session status | claude-dev SessionScanner | Rename "agent" → "session" throughout |
| Session card | claude-dev AgentCard | Display: PID, project, model, token, cost, git branch |
| Activity history | claude-dev LogTailer | Retain as-is |
| Contextual info | claude-dev (was Jira ticket) | Replace with TaskInfo (see below) |
| Status filter | claude-dev AgentGrid | Retain: working / idle / stopped filter |
| Text search | claude-dev AgentGrid | Search by project name, branch, task subject |

### Data Sources

| Source | Reader | Frequency |
|--------|--------|-----------|
| `~/.claude/sessions/{PID}.json` | SessionScanner | Polling every 2s |
| `~/.claude/sessions/{PID}.hb.dat` | SessionScanner | Polling every 2s |
| `~/.claude/projects/{slug}/*.jsonl` | LogTailer | fs.watch (event-driven) |
| `tmux list-panes -a` | TmuxMapper | Polling every 2s (with scanner) |

### TaskInfo Type (Replaces TicketInfo)

Replaces the removed Jira ticket detection. Extracted from JSONL log events:

```typescript
/** Replaces TicketInfo — generic task context for a session */
interface TaskInfo {
  /** Latest git commit message (from git tool use events) */
  commitMessage?: string;
  /** Current task subject (from TaskCreate/TaskUpdate events) */
  taskSubject?: string;
}
```

- `TicketInfo` interface: **removed**
- `TICKET_REGEX` constant: **removed**
- `JIRA_REFRESH_INTERVAL_MS` constant: **removed**
- `Session.ticket` field → replaced with `Session.taskInfo?: TaskInfo`
- Text search filter: matches on `taskInfo.taskSubject` (replaces `ticket.id`)

### Data Flow

```
SessionScanner ─┐
LogTailer ──────┤→ SessionStore (EventEmitter) → Socket.IO → Zustand → React
TmuxMapper ─────┘
```

## Module 2: Web Terminal

### Features

| Feature | Source | Changes |
|---------|--------|---------|
| Terminal tabs | NEW | Click session card → opens terminal tab |
| Attach to tmux window | claude-dev TerminalManager | Use grouped session, one window per tab |
| Multi-tab | claude-dev terminal components | Retain |
| Split pane | claude-dev SplitDivider | Retain |
| xterm.js rendering | claude-dev TerminalPane | Retain as-is |

### Attach Strategy (Phase 1)

For each terminal tab, the backend spawns a node-pty process that:

```bash
# Create a grouped session targeting the specific window
tmux new-session -d -s web-view-{tabId} -t {originalSession}
tmux select-window -t web-view-{tabId}:{targetWindow}
tmux attach-session -t web-view-{tabId}
```

- Each tab gets an independent grouped session
- User sees only the target window (one session per window)
- Full read/write interactive access
- Cleanup: grouped session is killed when tab closes

**Limitation**: If a window contains multiple panes, all panes in that window are visible. Per-pane isolation is deferred to Phase 2.

### UI Model

Terminal is embedded within the Session Monitor page (not a separate route):

- Session Monitor (`/`) is the only page
- Clicking a session card opens a terminal panel at the bottom of the viewport
- Terminal panel has tabs (one per attached session), showing project name + status
- Multiple tabs can be open simultaneously
- Split pane allows viewing multiple terminals side-by-side within the panel
- Panel is resizable (drag divider between monitor grid and terminal panel)

The previous `/terminal` separate page route is **removed**. `TerminalPage.tsx` is **not migrated**. Terminal sidebar agent list is replaced by the session cards themselves.

## Migration Plan (Move-and-Trim)

### Configuration Files

**Migrate**:
- `claude-dev/tsconfig.base.json` → `dashboard/tsconfig.base.json`
- `claude-dev/packages/server/package.json` → `dashboard/backend/package.json` (remove `@claude-dev/shared` dep)
- `claude-dev/packages/server/tsconfig.json` → `dashboard/backend/tsconfig.json` (update extends path)
- `claude-dev/packages/web/package.json` → `dashboard/frontend/package.json` (remove `@claude-dev/shared` dep)
- `claude-dev/packages/web/tsconfig.json` → `dashboard/frontend/tsconfig.json` (update extends path)
- `claude-dev/packages/web/vite.config.ts` → `dashboard/frontend/vite.config.ts` (add types alias, remove workflow proxy)
- `claude-dev/packages/web/vitest.config.ts` → `dashboard/frontend/vitest.config.ts`
- `claude-dev/packages/web/tailwind.config.js` → `dashboard/frontend/tailwind.config.js`
- `claude-dev/packages/web/postcss.config.js` → `dashboard/frontend/postcss.config.js`
- `claude-dev/packages/web/index.html` → `dashboard/frontend/index.html`

**Not migrated** (workspace-level or replaced, no longer needed):
- `claude-dev/package.json` (workspace root)
- `claude-dev/pnpm-workspace.yaml`
- `claude-dev/pnpm-lock.yaml`
- `claude-dev/packages/shared/package.json` (types/ has no package.json)
- `claude-dev/packages/shared/tsconfig.json` (types/ needs no tsconfig — it is raw TS source imported directly by frontend and backend, type-checked as part of their compilation)

### Types (`claude-dev/packages/shared/src/` → `dashboard/types/src/`)

| File | Action |
|------|--------|
| `types.ts` | Migrate. Remove: `Workflow`, `WorkflowTask`, `AgentRun`, `WorkflowEvent`, `WorkflowWSEvent`, `TicketInfo`. Remove constants: `TICKET_REGEX`, `PENDING_TASK_TTL_MS`, `JIRA_REFRESH_INTERVAL_MS`, `AGENT_RESULT_SUMMARY_MAX_LENGTH`. Rename `AgentSession` → `Session`. Add `TaskInfo`. Rename `agentPid` → `sessionPid` in `TerminalOpenPayload` and `TerminalSession`. |
| `index.ts` | Migrate. Update barrel exports. |

### Backend (`claude-dev/packages/server/src/` → `dashboard/backend/src/`)

| File | Action |
|------|--------|
| `index.ts` | Migrate. Remove workflow store/routes init. Remove `workflows:snapshot` emission on connect. |
| `collectors/session-scanner.ts` | Migrate as-is. |
| `collectors/log-tailer.ts` | Migrate. Remove ticket detection (TICKET_REGEX). Remove workflow event parsing. Add commit message / task info extraction. |
| `collectors/tmux-mapper.ts` | Migrate as-is. |
| `collectors/hook-receiver.ts` | Migrate as-is. |
| `store/agent-store.ts` | Migrate → rename to `session-store.ts`. Rename agent → session throughout. Update `ticket` field → `taskInfo`. |
| `terminal/terminal-manager.ts` | Migrate. Rename `agentPid` → `sessionPid`. |
| `api/routes.ts` | Migrate. Rename `/api/agents` → `/api/sessions`. |

| File | Action |
|------|--------|
| `collectors/parse-workflow-events.ts` | **Remove** |
| `store/workflow-store.ts` | **Remove** |
| `api/workflow-routes.ts` | **Remove** |

### Backend Tests

| File | Action |
|------|--------|
| `store/__tests__/agent-store.test.ts` | Migrate → rename to `session-store.test.ts`, rename agent → session |
| `api/__tests__/routes.test.ts` | Migrate, rename agent → session references |
| `collectors/__tests__/session-scanner.test.ts` | Migrate as-is |
| `collectors/__tests__/session-scanner-scan.test.ts` | Migrate as-is |
| `collectors/__tests__/log-tailer.test.ts` | Migrate as-is |
| `collectors/__tests__/tmux-mapper.test.ts` | Migrate as-is |
| `collectors/__tests__/hook-receiver.test.ts` | Migrate as-is |
| `terminal/__tests__/terminal-manager.test.ts` | Migrate, rename agentPid → sessionPid |
| `store/__tests__/workflow-store.test.ts` | **Remove** |
| `api/__tests__/workflow-routes.test.ts` | **Remove** |
| `collectors/__tests__/log-tailer-workflow.test.ts` | **Remove** |
| `collectors/__tests__/parse-workflow-events.test.ts` | **Remove** |

### Frontend (`claude-dev/packages/web/src/` → `dashboard/frontend/src/`)

| File | Action |
|------|--------|
| `main.tsx` | Migrate as-is. |
| `index.css` | Migrate as-is (Tailwind directives). |
| `App.tsx` | Migrate. Remove `/workflow` and `/terminal` routes. Single-page layout with session grid + terminal panel. Rename title. |
| `components/AgentCard.tsx` | Migrate → rename to `SessionCard.tsx`. |
| `components/AgentGrid.tsx` | Migrate → rename to `SessionGrid.tsx`. |
| `components/AgentDetailPanel.tsx` | Migrate → rename to `SessionDetailPanel.tsx`. |
| `components/ActivityFeed.tsx` | Migrate as-is. |
| `components/Header.tsx` | Migrate. Remove workflow/terminal nav links. Rename title "Claude Dev Platform" → "Dashboard". Rename "Agent Monitor" → "Session Monitor". |
| `components/SummaryBar.tsx` | Migrate as-is. |
| `components/terminal/TerminalPane.tsx` | Migrate as-is. |
| `components/terminal/TerminalContainer.tsx` | Migrate as-is. |
| `components/terminal/TerminalSidebar.tsx` | **Remove** (replaced by session cards). |
| `components/terminal/TerminalContextMenu.tsx` | Migrate as-is. |
| `components/terminal/SplitDivider.tsx` | Migrate as-is. |
| `hooks/socket.ts` | Migrate as-is (socket singleton). |
| `hooks/use-socket.ts` | Migrate. Remove workflow socket logic. |
| `hooks/use-terminal-socket.ts` | Migrate as-is. |
| `store/agent-store.ts` | Migrate → rename to `session-store.ts`. Rename `useAgentStore` → `useSessionStore`, `useSortedAgents` → `useSortedSessions`. Update filter to use `taskInfo.taskSubject` instead of `ticket.id`. |
| `store/terminal-store.ts` | Migrate as-is. |
| `utils/format.ts` | Migrate as-is. |

| File | Action |
|------|--------|
| `pages/WorkflowPage.tsx` | **Remove** |
| `pages/TerminalPage.tsx` | **Remove** |
| `components/workflow/*` | **Remove** (entire directory) |
| `hooks/use-workflow-socket.ts` | **Remove** |
| `store/workflow-store.ts` | **Remove** |

### Frontend Tests

| File | Action |
|------|--------|
| `components/__tests__/AgentCard.test.tsx` | Migrate → rename to `SessionCard.test.tsx` |
| `components/terminal/__tests__/TerminalContextMenu.test.tsx` | Migrate as-is |
| `components/terminal/__tests__/TerminalSidebar.test.tsx` | **Remove** (sidebar removed) |
| `hooks/__tests__/use-terminal-socket.test.ts` | Migrate as-is |
| `store/__tests__/agent-store.test.ts` | Migrate → rename to `session-store.test.ts` |
| `store/__tests__/terminal-store.test.ts` | Migrate as-is |
| `store/__tests__/workflow-store.test.ts` | **Remove** |
| `components/workflow/__tests__/WorkflowCard.test.tsx` | **Remove** |
| `components/workflow/__tests__/DagView.test.ts` | **Remove** |

### Naming Conventions

| Old (claude-dev) | New (dashboard) |
|-------------------|-----------------|
| `agent` | `session` |
| `AgentSession` | `Session` |
| `AgentStore` | `SessionStore` |
| `AgentCard` | `SessionCard` |
| `AgentGrid` | `SessionGrid` |
| `AgentDetailPanel` | `SessionDetailPanel` |
| `useAgentStore` | `useSessionStore` |
| `useSortedAgents` | `useSortedSessions` |
| `agentPid` | `sessionPid` |
| `agent:updated` | `session:updated` |
| `agent:removed` | `session:removed` |
| `agents:snapshot` | `sessions:snapshot` |
| `/api/agents` | `/api/sessions` |
| `TicketInfo` | `TaskInfo` |
| `ticket` | `taskInfo` |
| "Claude Dev Platform" | "Dashboard" |
| "Agent Monitor" | "Session Monitor" |

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
| Backend runtime | Node.js | >= 18 |
| Backend framework | Express | 4.x |
| Real-time | Socket.IO | 4.x |
| Terminal PTY | node-pty | 1.x |
| Frontend framework | React | 18.x |
| Build tool | Vite | 6.x |
| State management | Zustand | 5.x |
| Styling | Tailwind CSS | 3.x |
| Terminal rendering | xterm.js | 6.x |
| Routing | React Router DOM | 7.x |
| Testing | Vitest | 3.x |
| Language | TypeScript | 5.7+ (strict) |

Note: React Router DOM is retained but with a single route (`/`). It may be removed later if no additional routes are needed, but keeping it avoids unnecessary refactoring in Phase 1.

## Testing Strategy

- Migrate all non-workflow test files listed in the migration tables above
- Apply agent → session renames in all migrated test files
- Verify all backend tests pass: session-scanner, log-tailer, tmux-mapper, session-store, routes
- Verify all frontend tests pass: SessionCard, terminal components, session-store, terminal-store
- Remove all workflow-related test files listed in migration tables

## Decisions (Resolved)

1. **Deployment** — `docker-compose up -d` one-command deploy. `dashboard/` includes a `Dockerfile` and `docker-compose.yml`.
2. **Production serving** — Backend (Express) serves built frontend static files from `frontend/dist/`. Dev mode: Vite dev server on :3000 with proxy to backend :3141. Production: single Express server serves both API and static assets.
3. **Port** — `3141` (default, configurable via `PORT` env var).
4. **Access control** — Local-only. Backend binds to `127.0.0.1` (not `0.0.0.0`). Only `localhost` / `127.0.0.1` can connect. No authentication in Phase 1.
5. **Lock files** — Each package (`frontend/`, `backend/`) has its own independent `pnpm-lock.yaml`.
