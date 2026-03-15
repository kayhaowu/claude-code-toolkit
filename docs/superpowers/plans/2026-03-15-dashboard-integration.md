# Dashboard Integration Implementation Plan

**Status:** Completed (2026-03-16)

**Goal:** Migrate claude-dev into claude-code-toolkit as `dashboard/` with Session Monitor + Web Terminal, trimming workflow/Jira features.

**Architecture:** Move-and-trim approach. Copy source files from `claude-dev/packages/` into `dashboard/{types,backend,frontend}/`, apply agent→session renames, remove workflow/Jira code, add Docker deployment. Backend serves static frontend in production, binds to 127.0.0.1:3141.

**Tech Stack:** TypeScript 5.7+, Node.js 24 (native TS), Express 4, Socket.IO 4, React 18, Vite 6, Zustand 5, xterm.js 6, node-pty 1.2.0-beta.12, Tailwind CSS 3, Vitest 3, Docker

**Spec:** `docs/superpowers/specs/2026-03-15-dashboard-integration-design.md`

## Post-Implementation Changes

The following changes were made during and after initial implementation:

1. **Runtime**: tsx → Node.js v24 native TS (`--experimental-strip-types`) due to ESM module resolution issues
2. **Types import**: `@dashboard/types` path alias → local barrel file (`backend/src/types/index.ts`) with relative `.ts` imports
3. **node-pty**: 1.1.0 → 1.2.0-beta.12 (Node v24 native addon compatibility)
4. **Terminal**: Added "Open Terminal" button on SessionCard, wired to `terminal:open` socket event
5. **tmux mapping**: Tab-delimited format, macOS `lsof` fallback, `/dev/*` TTY pattern
6. **Theme**: Catppuccin Mocha 16-color ANSI palette in xterm.js, JetBrainsMono Nerd Font from CDN
7. **True color**: `tmux -T 256,RGB,mouse,title` for per-client true color support
8. **Status source**: `.status` file (event-driven) as authoritative, `.hb.dat` as fallback
9. **Statusline enhancement**: Per-status colors (⚡ yellow, 💤 blue, ✅ green) in tmux-sessions.sh
10. **Error handling**: Silent catches → warn logging, React ErrorBoundary, ConnectionBanner, input validation
11. **Immutability**: SessionStore `updateActivity`/`updateTaskInfo` create new objects
12. **Tests**: 118 total (70 backend + 48 frontend)

---

## Chunk 1: Project Scaffolding & Shared Types

### Task 1: Create directory structure and config files

**Files:**
- Create: `dashboard/tsconfig.base.json`
- Create: `dashboard/backend/tsconfig.json`
- Create: `dashboard/backend/package.json`
- Create: `dashboard/frontend/tsconfig.json`
- Create: `dashboard/frontend/package.json`
- Create: `dashboard/frontend/vite.config.ts`
- Create: `dashboard/frontend/tailwind.config.js`
- Create: `dashboard/frontend/postcss.config.js`
- Create: `dashboard/frontend/index.html`

- [ ] **Step 1: Create dashboard directory structure**

```bash
mkdir -p dashboard/{types/src,backend/src,frontend/src}
```

- [ ] **Step 2: Create `dashboard/tsconfig.base.json`**

Copy from `claude-dev/tsconfig.base.json` as-is:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}
```

- [ ] **Step 3: Create `dashboard/backend/tsconfig.json`**

```json
{
  "extends": "../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src", "../types/src"]
}
```

Note: `../types/src` is included so backend can type-check the shared types via relative imports.

- [ ] **Step 4: Create `dashboard/backend/package.json`**

```json
{
  "name": "@dashboard/backend",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "express": "^4.21.0",
    "node-pty": "^1.1.0",
    "socket.io": "^4.8.0"
  },
  "devDependencies": {
    "@types/express": "^5.0.0",
    "@types/node": "^22.0.0",
    "@types/supertest": "^7.2.0",
    "supertest": "^7.2.2",
    "tsx": "^4.19.0",
    "typescript": "^5.7.0",
    "vitest": "^3.0.0"
  }
}
```

- [ ] **Step 5: Create `dashboard/frontend/tsconfig.json`**

```json
{
  "extends": "../tsconfig.base.json",
  "compilerOptions": {
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "outDir": "./dist",
    "noEmit": true
  },
  "include": ["src", "../types/src"]
}
```

- [ ] **Step 6: Create `dashboard/frontend/package.json`**

```json
{
  "name": "@dashboard/frontend",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "@xterm/addon-fit": "^0.11.0",
    "@xterm/xterm": "^6.0.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^7.13.1",
    "socket.io-client": "^4.8.0",
    "zustand": "^5.0.0"
  },
  "devDependencies": {
    "@testing-library/jest-dom": "^6.6.0",
    "@testing-library/react": "^16.0.0",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "autoprefixer": "^10.4.0",
    "jsdom": "^25.0.0",
    "postcss": "^8.4.0",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.7.0",
    "vite": "^6.0.0",
    "vitest": "^3.0.0"
  }
}
```

- [ ] **Step 7: Create `dashboard/frontend/vite.config.ts`**

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

- [ ] **Step 8: Copy frontend config files from claude-dev**

Copy these as-is from `claude-dev/packages/web/`:
- `tailwind.config.js` → `dashboard/frontend/tailwind.config.js`
- `postcss.config.js` → `dashboard/frontend/postcss.config.js`
- `index.html` → `dashboard/frontend/index.html`

```bash
cp claude-dev/packages/web/tailwind.config.js dashboard/frontend/
cp claude-dev/packages/web/postcss.config.js dashboard/frontend/
cp claude-dev/packages/web/index.html dashboard/frontend/
```

- [ ] **Step 9: Commit scaffolding**

```bash
git add dashboard/
git commit -m "scaffold: create dashboard directory structure and config files

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 2: Migrate and transform shared types

**Files:**
- Create: `dashboard/types/src/types.ts`
- Create: `dashboard/types/src/index.ts`

- [ ] **Step 1: Create `dashboard/types/src/types.ts`**

Write the transformed types file. Changes from original:
- Remove: `TicketInfo`, `Workflow`, `WorkflowTask`, `AgentRun`, `WorkflowEvent`, `WorkflowWSEvent`, `TicketWorkflows`
- Remove constants: `TICKET_REGEX`, `PENDING_TASK_TTL_MS`, `JIRA_REFRESH_INTERVAL_MS`, `AGENT_RESULT_SUMMARY_MAX_LENGTH`
- Rename: `AgentSession` → `Session`, `agentPid` → `sessionPid`
- Add: `TaskInfo`
- Rename WSEvent agent references → session

```typescript
export interface TmuxInfo {
  session: string;
  window: string;
  windowName: string;
  pane: string;
  tty: string;
}

/** Generic task context for a session (replaces TicketInfo) */
export interface TaskInfo {
  /** Latest git commit message (from git tool use events) */
  commitMessage?: string;
  /** Current task subject (from TaskCreate/TaskUpdate events) */
  taskSubject?: string;
}

export interface CurrentActivity {
  type: 'tool_use' | 'thinking' | 'responding' | 'idle';
  tool?: string;
  toolInput?: string;
  since: number;
}

export interface ActivityEntry {
  timestamp: number;
  type: string;
  summary: string;
}

export interface Session {
  id: string;
  pid: number;
  projectName: string;
  projectDir: string;
  gitBranch: string | null;
  model: string;
  costUsd: number;
  tokensIn: number;
  tokensOut: number;
  memKb: number;
  tmux: TmuxInfo;
  status: 'working' | 'idle' | 'stopped';
  startedAt: number;
  lastHeartbeat: number;
  taskInfo: TaskInfo;
  currentActivity: CurrentActivity;
  recentActivity: ActivityEntry[];
  dataSource: 'polling' | 'hooks' | 'both';
}

export type WSEvent =
  | { type: 'sessions:snapshot'; sessions: Session[] }
  | { type: 'session:updated'; session: Session }
  | { type: 'session:removed'; id: string };

// ── Terminal types ──

export type TerminalSession =
  | { id: string; mode: 'attach'; sessionPid: number; tmuxTarget: string; title: string; status: 'connected' | 'disconnected'; createdAt: number }
  | { id: string; mode: 'new'; sessionPid: null; tmuxTarget: string; title: string; status: 'connected' | 'disconnected'; createdAt: number };

export type TerminalOpenPayload =
  | { mode: 'attach'; sessionPid: number }
  | { mode: 'new'; cwd?: string };

export interface TerminalInputPayload {
  sessionId: string;
  data: string;
}

export interface TerminalResizePayload {
  sessionId: string;
  cols: number;
  rows: number;
}

export interface TerminalReconnectPayload {
  sessionIds: string[];
}

export type TerminalWSEvent =
  | { type: 'terminal:sessions'; sessions: TerminalSession[] }
  | { type: 'terminal:opened'; session: TerminalSession }
  | { type: 'terminal:closed'; sessionId: string }
  | { type: 'terminal:error'; sessionId?: string; message: string };

export const MAX_RECENT_ACTIVITY = 50;
export const SCAN_INTERVAL_MS = 2000;
export const PHANTOM_TTL_MS = 30_000;
export const ACTIVITY_STALENESS_MS = 120_000;
```

- [ ] **Step 2: Create `dashboard/types/src/index.ts`**

```typescript
export * from './types.js';
```

- [ ] **Step 3: Verify types compile**

```bash
cd dashboard/backend && npx tsc --noEmit
```

Expected: No errors (backend tsconfig includes `../types/src`).

- [ ] **Step 4: Commit shared types**

```bash
git add dashboard/types/
git commit -m "feat(dashboard): add shared types with agent→session renames

Remove workflow/Jira types, rename AgentSession→Session,
add TaskInfo to replace TicketInfo.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

## Chunk 2: Backend Migration

### Task 3: Migrate backend collectors (as-is files)

**Files:**
- Create: `dashboard/backend/src/collectors/session-scanner.ts`
- Create: `dashboard/backend/src/collectors/tmux-mapper.ts`
- Create: `dashboard/backend/src/collectors/hook-receiver.ts`

- [ ] **Step 1: Copy collectors that need no changes**

```bash
mkdir -p dashboard/backend/src/collectors
cp claude-dev/packages/server/src/collectors/session-scanner.ts dashboard/backend/src/collectors/
cp claude-dev/packages/server/src/collectors/tmux-mapper.ts dashboard/backend/src/collectors/
cp claude-dev/packages/server/src/collectors/hook-receiver.ts dashboard/backend/src/collectors/
```

- [ ] **Step 2: Fix imports in all three files**

In each copied file, replace:
```typescript
// Old:
import { ... } from '@claude-dev/shared';
import type { ... } from '@claude-dev/shared';
// New:
import { ... } from '../../types/src/index.js';
import type { ... } from '../../types/src/index.js';
```

Also in `session-scanner.ts`, rename any `AgentSession` references to `Session`, and change the `ticket` field initialization from `{ id: null, summary: null, status: null, url: null }` to `{}` (empty `TaskInfo`), renaming the property from `ticket` to `taskInfo`.

- [ ] **Step 3: Verify files have no syntax errors**

```bash
cd dashboard/backend && npx tsc --noEmit
```

Expected: May fail until all files are migrated (missing imports). That's OK for now.

- [ ] **Step 4: Commit**

```bash
git add dashboard/backend/src/collectors/session-scanner.ts dashboard/backend/src/collectors/tmux-mapper.ts dashboard/backend/src/collectors/hook-receiver.ts
git commit -m "feat(dashboard): migrate session-scanner, tmux-mapper, hook-receiver

Copy from claude-dev with import path updates. session-scanner
updated to use Session type and taskInfo field.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 4: Migrate and transform log-tailer

**Files:**
- Create: `dashboard/backend/src/collectors/log-tailer.ts`

- [ ] **Step 1: Copy log-tailer.ts**

```bash
cp claude-dev/packages/server/src/collectors/log-tailer.ts dashboard/backend/src/collectors/
```

- [ ] **Step 2: Transform log-tailer.ts**

Apply these changes:

1. **Remove imports:**
   - Remove `import { TICKET_REGEX, ... } from '@claude-dev/shared';`
   - Remove `import { parseWorkflowEvents } from './parse-workflow-events.js';`

2. **Fix imports:**
   ```typescript
   import { MAX_RECENT_ACTIVITY } from '../../types/src/index.js';
   import type { ActivityEntry } from '../../types/src/index.js';
   ```

3. **Remove `detectTicket` function** (lines ~53-56 in original)

4. **Remove ticket detection in `readNewLines`** — remove these lines:
   ```typescript
   const text = JSON.stringify(parsed);
   const ticket = detectTicket(text);
   if (ticket) {
     this.emit('ticket', { pid, ticketId: ticket });
   }
   ```

5. **Remove workflow event extraction in `readNewLines`** — remove these lines:
   ```typescript
   const workflowEvents = parseWorkflowEvents(parsed, pid);
   if (workflowEvents.length > 0) {
     this.emit('workflow', { pid, events: workflowEvents });
   }
   ```

6. **Add task info extraction in `readNewLines`** — after the activity emission, add:
   ```typescript
   // Extract task info from TaskCreate/TaskUpdate events
   if (parsed.type === 'assistant') {
     const content = parsed.message?.content;
     if (Array.isArray(content)) {
       for (const block of content) {
         if (block.type === 'tool_use' && block.name === 'TaskCreate') {
           this.emit('taskInfo', { pid, taskSubject: block.input?.subject });
         }
         if (block.type === 'tool_use' && block.name === 'TaskUpdate') {
           this.emit('taskInfo', { pid, taskSubject: block.input?.subject });
         }
         // Detect git commit messages
         if (block.type === 'tool_result' && typeof block.content === 'string') {
           const commitMatch = block.content.match(/\[[\w-]+\s+[\da-f]+\]\s+(.+)/);
           if (commitMatch) {
             this.emit('taskInfo', { pid, commitMessage: commitMatch[1] });
           }
         }
       }
     }
   }
   ```

- [ ] **Step 3: Commit**

```bash
git add dashboard/backend/src/collectors/log-tailer.ts
git commit -m "feat(dashboard): migrate log-tailer with ticket/workflow removal

Remove ticket detection and workflow event parsing.
Add task info extraction (commit messages, task subjects).

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 5: Migrate and transform session-store (was agent-store)

**Files:**
- Create: `dashboard/backend/src/store/session-store.ts`

- [ ] **Step 1: Create `dashboard/backend/src/store/session-store.ts`**

Write the transformed file. Changes from `agent-store.ts`:
- Rename class `AgentStore` → `SessionStore`
- Rename all `agent` variables/params → `session`
- Rename `agents` map → `sessions`
- Replace `ticket` with `taskInfo`
- Remove `updateTicket` method, add `updateTaskInfo` method
- Fix imports to relative paths

```typescript
import { EventEmitter } from 'node:events';
import type { Session, ActivityEntry, TaskInfo } from '../../types/src/index.js';
import { MAX_RECENT_ACTIVITY, PHANTOM_TTL_MS, ACTIVITY_STALENESS_MS } from '../../types/src/index.js';

export class SessionStore extends EventEmitter {
  private sessions = new Map<string, Session>();
  private stoppedAt = new Map<string, number>();

  getAll(): Session[] {
    return Array.from(this.sessions.values());
  }

  get(id: string): Session | undefined {
    return this.sessions.get(id);
  }

  updateFromScan(scanned: Session[], now = Date.now()): void {
    const scannedIds = new Set(scanned.map(s => s.id));

    for (const id of this.sessions.keys()) {
      if (!scannedIds.has(id)) {
        if (!this.stoppedAt.has(id)) {
          this.stoppedAt.set(id, now);
          const updated = { ...this.sessions.get(id)!, status: 'stopped' as const };
          this.sessions.set(id, updated);
          this.emit('session:updated', updated);
        } else {
          const elapsed = now - this.stoppedAt.get(id)!;
          if (elapsed >= PHANTOM_TTL_MS) {
            this.sessions.delete(id);
            this.stoppedAt.delete(id);
            this.emit('session:removed', id);
          }
        }
      }
    }

    for (const session of scanned) {
      if (this.stoppedAt.has(session.id)) {
        this.stoppedAt.delete(session.id);
      }
    }

    for (const session of scanned) {
      const existing = this.sessions.get(session.id);
      if (existing) {
        let currentActivity = existing.currentActivity;
        if (
          currentActivity.type !== 'idle' &&
          now - currentActivity.since >= ACTIVITY_STALENESS_MS
        ) {
          currentActivity = { type: 'idle', since: now };
        }

        const merged: Session = {
          ...session,
          currentActivity,
          recentActivity: existing.recentActivity,
          taskInfo: { ...existing.taskInfo, ...session.taskInfo },
          dataSource: existing.dataSource === 'hooks' ? 'both' : session.dataSource,
        };
        this.sessions.set(session.id, merged);
        this.emit('session:updated', merged);
      } else {
        this.sessions.set(session.id, session);
        this.emit('session:updated', session);
      }
    }
  }

  updateActivity(pid: number, activity: {
    type: 'tool_use'; tool: string; toolInput: string; summary: string; timestamp: number;
  }): void {
    const id = String(pid);
    const session = this.sessions.get(id);
    if (!session) return;

    session.currentActivity = {
      type: activity.type,
      tool: activity.tool,
      toolInput: activity.toolInput,
      since: activity.timestamp,
    };

    const entry: ActivityEntry = {
      timestamp: activity.timestamp,
      type: activity.type,
      summary: activity.summary,
    };
    session.recentActivity.push(entry);
    if (session.recentActivity.length > MAX_RECENT_ACTIVITY) {
      session.recentActivity = session.recentActivity.slice(-MAX_RECENT_ACTIVITY);
    }

    session.dataSource = session.dataSource === 'polling' ? 'polling' : 'both';
    this.emit('session:updated', session);
  }

  updateTaskInfo(pid: number, taskInfo: Partial<TaskInfo>): void {
    const id = String(pid);
    const session = this.sessions.get(id);
    if (!session) return;
    session.taskInfo = { ...session.taskInfo, ...taskInfo };
    this.emit('session:updated', session);
  }
}
```

- [ ] **Step 2: Commit**

```bash
mkdir -p dashboard/backend/src/store
git add dashboard/backend/src/store/session-store.ts
git commit -m "feat(dashboard): migrate agent-store → session-store

Rename AgentStore→SessionStore, agent→session throughout.
Replace ticket/TicketInfo with taskInfo/TaskInfo.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 6: Migrate terminal-manager and API routes

**Files:**
- Create: `dashboard/backend/src/terminal/terminal-manager.ts`
- Create: `dashboard/backend/src/api/routes.ts`

- [ ] **Step 1: Copy and transform terminal-manager**

```bash
mkdir -p dashboard/backend/src/terminal
cp claude-dev/packages/server/src/terminal/terminal-manager.ts dashboard/backend/src/terminal/
```

In the copied file:
- Replace `import ... from '@claude-dev/shared'` → `import ... from '../../types/src/index.js'`
- Replace `import { AgentStore }` → `import { SessionStore }`
- Replace `agentPid` → `sessionPid` throughout
- Replace `AgentStore` → `SessionStore` in constructor parameter type
- Replace import path `from '../store/agent-store.js'` → `from '../store/session-store.js'`

- [ ] **Step 2: Create `dashboard/backend/src/api/routes.ts`**

```typescript
import { Router } from 'express';
import type { SessionStore } from '../store/session-store.js';

export function createApiRouter(store: SessionStore): Router {
  const router = Router();

  router.get('/sessions', (_req, res) => {
    res.json(store.getAll());
  });

  return router;
}
```

- [ ] **Step 3: Commit**

```bash
git add dashboard/backend/src/terminal/ dashboard/backend/src/api/
git commit -m "feat(dashboard): migrate terminal-manager and API routes

Rename agentPid→sessionPid, AgentStore→SessionStore,
/api/agents→/api/sessions.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 7: Migrate and transform server entry point

**Files:**
- Create: `dashboard/backend/src/index.ts`

- [ ] **Step 1: Write `dashboard/backend/src/index.ts`**

Transformed from `claude-dev/packages/server/src/index.ts`. Changes:
- Remove all workflow imports, store, routes, events
- Remove ticket event handling
- Add taskInfo event handling
- Rename agent → session throughout
- Bind to `127.0.0.1` instead of `0.0.0.0`
- Port `3141` default
- Add static file serving for production

```typescript
import express from 'express';
import { createServer } from 'node:http';
import { Server as SocketIO } from 'socket.io';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';
import { SessionStore } from './store/session-store.js';
import { scanSessions } from './collectors/session-scanner.js';
import { LogTailer } from './collectors/log-tailer.js';
import { createHookRouter } from './collectors/hook-receiver.js';
import { createApiRouter } from './api/routes.js';
import { SCAN_INTERVAL_MS } from '../../types/src/index.js';
import { TerminalManager } from './terminal/terminal-manager.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = parseInt(process.env.PORT ?? '3141', 10);
const HOST = process.env.HOST ?? '127.0.0.1';

const app = express();
const http = createServer(app);
const io = new SocketIO(http, {
  cors: { origin: [`http://127.0.0.1:${PORT}`, `http://localhost:${PORT}`] },
});

app.use(express.json());

const store = new SessionStore();
const logTailer = new LogTailer();
const terminalManager = new TerminalManager(store);

// API routes
app.use('/api', createApiRouter(store));
app.use('/api/hooks', createHookRouter(store));

// Serve frontend static files in production
const staticDir = join(__dirname, '../../frontend/dist');
if (existsSync(staticDir)) {
  app.use(express.static(staticDir));
  app.get('*', (_req, res) => {
    res.sendFile(join(staticDir, 'index.html'));
  });
}

// WebSocket
io.on('connection', (socket) => {
  socket.emit('sessions:snapshot', { type: 'sessions:snapshot', sessions: store.getAll() });

  // ── Terminal ──
  socket.emit('terminal:sessions', {
    type: 'terminal:sessions',
    sessions: terminalManager.getBySocket(socket.id),
  });

  socket.on('terminal:open', async (payload: any) => {
    try {
      const session = await terminalManager.open(socket.id, payload);
      socket.emit('terminal:opened', { type: 'terminal:opened', session });
    } catch (err: any) {
      socket.emit('terminal:error', { type: 'terminal:error', message: err.message });
    }
  });

  socket.on('terminal:input', ({ sessionId, data }: any) => {
    try {
      terminalManager.write(sessionId, socket.id, data);
    } catch (err: any) {
      console.error(`[terminal:input] session=${sessionId}:`, err.message);
    }
  });

  socket.on('terminal:resize', ({ sessionId, cols, rows }: any) => {
    try {
      terminalManager.resize(sessionId, socket.id, cols, rows);
    } catch (err: any) {
      console.error(`[terminal:resize] session=${sessionId}:`, err.message);
    }
  });

  socket.on('terminal:close', ({ sessionId }: any) => {
    try {
      terminalManager.close(sessionId, socket.id);
      socket.emit('terminal:closed', { type: 'terminal:closed', sessionId });
    } catch (err: any) {
      console.error(`[terminal:close] session=${sessionId}:`, err.message);
      socket.emit('terminal:error', { type: 'terminal:error', message: err.message });
    }
  });

  socket.on('terminal:reconnect', ({ sessionIds }: any) => {
    const { lost } = terminalManager.handleReconnect(socket.id, sessionIds);
    for (const sessionId of lost) {
      socket.emit('terminal:closed', { type: 'terminal:closed', sessionId });
    }
    socket.emit('terminal:sessions', {
      type: 'terminal:sessions',
      sessions: terminalManager.getBySocket(socket.id),
    });
  });

  socket.on('disconnect', () => {
    terminalManager.handleDisconnect(socket.id);
  });
});

// Terminal binary output
terminalManager.on('output', ({ sessionId, socketId, data }: any) => {
  io.to(socketId).emit(`terminal:output:${sessionId}`, data);
});

terminalManager.on('exited', ({ sessionId, socketId }: any) => {
  io.to(socketId).emit('terminal:closed', { type: 'terminal:closed', sessionId });
});

process.on('SIGTERM', () => terminalManager.stopAll());
process.on('SIGINT', () => terminalManager.stopAll());

// Store events → Socket.IO broadcast
store.on('session:updated', (session) => {
  io.emit('session:updated', { type: 'session:updated', session });
});

store.on('session:removed', (id) => {
  io.emit('session:removed', { type: 'session:removed', id });
});

// LogTailer events
logTailer.on('activity', ({ pid, activity }) => {
  store.updateActivity(pid, activity);
});

logTailer.on('taskInfo', ({ pid, ...info }) => {
  store.updateTaskInfo(pid, info);
});

logTailer.on('file-rotated', ({ pid }) => {
  console.log(`JSONL rotated for PID ${pid}, will re-tail on next scan`);
});

// Scan loop
async function scanLoop() {
  try {
    const sessions = await scanSessions();
    store.updateFromScan(sessions);

    for (const session of sessions) {
      if (session.status !== 'stopped' && !logTailer.isTailing(session.pid)) {
        logTailer.startTailing(session.pid, session.projectDir);
      }
    }
  } catch (err) {
    console.error('Scan error:', err);
  }
}

setInterval(scanLoop, SCAN_INTERVAL_MS);
scanLoop();

http.listen(PORT, HOST, () => {
  console.log(`Dashboard server listening on http://${HOST}:${PORT}`);
});
```

- [ ] **Step 2: Install backend dependencies**

```bash
cd dashboard/backend && pnpm install
```

- [ ] **Step 3: Verify backend compiles**

```bash
cd dashboard/backend && npx tsc --noEmit
```

Expected: PASS (all imports resolve).

- [ ] **Step 4: Commit**

```bash
git add dashboard/backend/src/index.ts dashboard/backend/pnpm-lock.yaml
git commit -m "feat(dashboard): migrate server entry point

Remove workflow code, add static file serving, bind 127.0.0.1:3141,
wire taskInfo events from LogTailer.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 8: Migrate backend tests

**Files:**
- Create: `dashboard/backend/src/store/__tests__/session-store.test.ts`
- Create: `dashboard/backend/src/api/__tests__/routes.test.ts`
- Create: `dashboard/backend/src/collectors/__tests__/session-scanner.test.ts`
- Create: `dashboard/backend/src/collectors/__tests__/session-scanner-scan.test.ts`
- Create: `dashboard/backend/src/collectors/__tests__/log-tailer.test.ts`
- Create: `dashboard/backend/src/collectors/__tests__/tmux-mapper.test.ts`
- Create: `dashboard/backend/src/collectors/__tests__/hook-receiver.test.ts`
- Create: `dashboard/backend/src/terminal/__tests__/terminal-manager.test.ts`

- [ ] **Step 1: Copy test files**

```bash
mkdir -p dashboard/backend/src/store/__tests__
mkdir -p dashboard/backend/src/api/__tests__
mkdir -p dashboard/backend/src/collectors/__tests__
mkdir -p dashboard/backend/src/terminal/__tests__

cp claude-dev/packages/server/src/store/__tests__/agent-store.test.ts dashboard/backend/src/store/__tests__/session-store.test.ts
cp claude-dev/packages/server/src/api/__tests__/routes.test.ts dashboard/backend/src/api/__tests__/
cp claude-dev/packages/server/src/collectors/__tests__/session-scanner.test.ts dashboard/backend/src/collectors/__tests__/
cp claude-dev/packages/server/src/collectors/__tests__/session-scanner-scan.test.ts dashboard/backend/src/collectors/__tests__/
cp claude-dev/packages/server/src/collectors/__tests__/log-tailer.test.ts dashboard/backend/src/collectors/__tests__/
cp claude-dev/packages/server/src/collectors/__tests__/tmux-mapper.test.ts dashboard/backend/src/collectors/__tests__/
cp claude-dev/packages/server/src/collectors/__tests__/hook-receiver.test.ts dashboard/backend/src/collectors/__tests__/
cp claude-dev/packages/server/src/terminal/__tests__/terminal-manager.test.ts dashboard/backend/src/terminal/__tests__/
```

- [ ] **Step 2: Transform test files**

In all copied test files:
- Replace `from '@claude-dev/shared'` → `from '../../../types/src/index.js'` (adjust depth per file)
- In `session-store.test.ts`: rename `AgentStore` → `SessionStore`, `agent` → `session`, `ticket` → `taskInfo`, update import path from `../agent-store.js` → `../session-store.js`
- In `routes.test.ts`: rename `/api/agents` → `/api/sessions`, `AgentStore` → `SessionStore`, update import path
- In `terminal-manager.test.ts`: rename `agentPid` → `sessionPid`, `AgentStore` → `SessionStore`

- [ ] **Step 3: Run backend tests**

```bash
cd dashboard/backend && pnpm test
```

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add dashboard/backend/src/*/__tests__/ dashboard/backend/src/collectors/__tests__/
git commit -m "test(dashboard): migrate backend tests with agent→session renames

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

## Chunk 3: Frontend Migration

### Task 9: Migrate frontend foundation files

**Files:**
- Create: `dashboard/frontend/src/main.tsx`
- Create: `dashboard/frontend/src/index.css`
- Create: `dashboard/frontend/src/hooks/socket.ts`
- Create: `dashboard/frontend/src/utils/format.ts`

- [ ] **Step 1: Copy foundation files**

```bash
mkdir -p dashboard/frontend/src/{hooks,utils,components/terminal,store}
cp claude-dev/packages/web/src/main.tsx dashboard/frontend/src/
cp claude-dev/packages/web/src/index.css dashboard/frontend/src/
cp claude-dev/packages/web/src/hooks/socket.ts dashboard/frontend/src/hooks/
cp claude-dev/packages/web/src/utils/format.ts dashboard/frontend/src/utils/
```

No changes needed to these files (they don't import from `@claude-dev/shared`).

- [ ] **Step 2: Commit**

```bash
git add dashboard/frontend/src/main.tsx dashboard/frontend/src/index.css dashboard/frontend/src/hooks/socket.ts dashboard/frontend/src/utils/format.ts
git commit -m "feat(dashboard): migrate frontend foundation files

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 10: Migrate and transform frontend stores

**Files:**
- Create: `dashboard/frontend/src/store/session-store.ts`
- Create: `dashboard/frontend/src/store/terminal-store.ts`

- [ ] **Step 1: Create `dashboard/frontend/src/store/session-store.ts`**

Transformed from `agent-store.ts`:

```typescript
import { useMemo } from 'react';
import { create } from 'zustand';
import type { Session } from '@dashboard/types';

interface SessionStoreState {
  sessions: Map<string, Session>;
  selectedId: string | null;
  filter: { status: string | null; search: string };

  setSnapshot: (sessions: Session[]) => void;
  updateSession: (session: Session) => void;
  removeSession: (id: string) => void;
  setSelected: (id: string | null) => void;
  setFilter: (filter: Partial<SessionStoreState['filter']>) => void;
}

export const useSessionStore = create<SessionStoreState>((set) => ({
  sessions: new Map(),
  selectedId: null,
  filter: { status: null, search: '' },

  setSnapshot: (sessions) => set({
    sessions: new Map(sessions.map(s => [s.id, s])),
  }),
  updateSession: (session) => set((state) => {
    const next = new Map(state.sessions);
    next.set(session.id, session);
    return { sessions: next };
  }),
  removeSession: (id) => set((state) => {
    const next = new Map(state.sessions);
    next.delete(id);
    return { sessions: next };
  }),
  setSelected: (id) => set({ selectedId: id }),
  setFilter: (filter) => set((state) => ({
    filter: { ...state.filter, ...filter },
  })),
}));

export function useSortedSessions(): Session[] {
  const sessions = useSessionStore(s => s.sessions);
  const filter = useSessionStore(s => s.filter);

  return useMemo(() => {
    const statusOrder = { working: 0, idle: 1, stopped: 2 };
    let list = Array.from(sessions.values());

    if (filter.status) {
      list = list.filter(s => s.status === filter.status);
    }
    if (filter.search) {
      const q = filter.search.toLowerCase();
      list = list.filter(s =>
        s.projectName.toLowerCase().includes(q) ||
        s.taskInfo.taskSubject?.toLowerCase().includes(q) ||
        s.tmux.windowName.toLowerCase().includes(q)
      );
    }

    return list.sort((a, b) => statusOrder[a.status] - statusOrder[b.status]);
  }, [sessions, filter]);
}
```

- [ ] **Step 2: Copy terminal-store as-is**

```bash
cp claude-dev/packages/web/src/store/terminal-store.ts dashboard/frontend/src/store/
```

Fix import: replace `from '@claude-dev/shared'` → `from '@dashboard/types'`.

- [ ] **Step 3: Commit**

```bash
git add dashboard/frontend/src/store/
git commit -m "feat(dashboard): migrate frontend stores with agent→session renames

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 11: Migrate and transform frontend hooks

**Files:**
- Create: `dashboard/frontend/src/hooks/use-socket.ts`
- Create: `dashboard/frontend/src/hooks/use-terminal-socket.ts`

- [ ] **Step 1: Create `dashboard/frontend/src/hooks/use-socket.ts`**

Transformed from original — remove workflow, rename agent → session:

```typescript
import { useEffect } from 'react';
import { acquireSocket, releaseSocket } from './socket.js';
import { useSessionStore } from '../store/session-store.js';
import type { WSEvent } from '@dashboard/types';

export function useSocket() {
  const { setSnapshot, updateSession, removeSession } = useSessionStore();

  useEffect(() => {
    const socket = acquireSocket();

    socket.on('sessions:snapshot', (event: WSEvent & { type: 'sessions:snapshot' }) => {
      setSnapshot(event.sessions);
    });
    socket.on('session:updated', (event: WSEvent & { type: 'session:updated' }) => {
      updateSession(event.session);
    });
    socket.on('session:removed', (event: WSEvent & { type: 'session:removed' }) => {
      removeSession(event.id);
    });

    return () => {
      socket.off('sessions:snapshot');
      socket.off('session:updated');
      socket.off('session:removed');
      releaseSocket();
    };
  }, [setSnapshot, updateSession, removeSession]);
}
```

- [ ] **Step 2: Copy and transform use-terminal-socket.ts**

```bash
cp claude-dev/packages/web/src/hooks/use-terminal-socket.ts dashboard/frontend/src/hooks/
```

Fix imports: `@claude-dev/shared` → `@dashboard/types`, `useAgentStore` → `useSessionStore` if referenced.

- [ ] **Step 3: Commit**

```bash
git add dashboard/frontend/src/hooks/
git commit -m "feat(dashboard): migrate frontend hooks with session renames

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 12: Migrate and transform frontend components

**Files:**
- Create: `dashboard/frontend/src/components/SessionCard.tsx`
- Create: `dashboard/frontend/src/components/SessionGrid.tsx`
- Create: `dashboard/frontend/src/components/SessionDetailPanel.tsx`
- Create: `dashboard/frontend/src/components/ActivityFeed.tsx`
- Create: `dashboard/frontend/src/components/Header.tsx`
- Create: `dashboard/frontend/src/components/SummaryBar.tsx`
- Create: `dashboard/frontend/src/components/terminal/TerminalPane.tsx`
- Create: `dashboard/frontend/src/components/terminal/TerminalContainer.tsx`
- Create: `dashboard/frontend/src/components/terminal/TerminalContextMenu.tsx`
- Create: `dashboard/frontend/src/components/terminal/SplitDivider.tsx`

- [ ] **Step 1: Copy and rename component files**

```bash
cp claude-dev/packages/web/src/components/AgentCard.tsx dashboard/frontend/src/components/SessionCard.tsx
cp claude-dev/packages/web/src/components/AgentGrid.tsx dashboard/frontend/src/components/SessionGrid.tsx
cp claude-dev/packages/web/src/components/AgentDetailPanel.tsx dashboard/frontend/src/components/SessionDetailPanel.tsx
cp claude-dev/packages/web/src/components/ActivityFeed.tsx dashboard/frontend/src/components/
cp claude-dev/packages/web/src/components/SummaryBar.tsx dashboard/frontend/src/components/
cp claude-dev/packages/web/src/components/terminal/TerminalPane.tsx dashboard/frontend/src/components/terminal/
cp claude-dev/packages/web/src/components/terminal/TerminalContainer.tsx dashboard/frontend/src/components/terminal/
cp claude-dev/packages/web/src/components/terminal/TerminalContextMenu.tsx dashboard/frontend/src/components/terminal/
cp claude-dev/packages/web/src/components/terminal/SplitDivider.tsx dashboard/frontend/src/components/terminal/
```

- [ ] **Step 2: Transform all component files**

In every copied component:
- Replace `from '@claude-dev/shared'` → `from '@dashboard/types'`
- Replace `import { useAgentStore, useSortedAgents }` → `import { useSessionStore, useSortedSessions }`
- Replace `AgentSession` → `Session` in type annotations
- Replace `useAgentStore` → `useSessionStore`
- Replace `useSortedAgents` → `useSortedSessions`
- Replace `agent` variable names → `session` where they refer to the data type
- In `SessionCard.tsx`: replace `agent.ticket.id` with `session.taskInfo.taskSubject` or `session.taskInfo.commitMessage`
- In `SessionGrid.tsx`: update import from `./AgentCard` → `./SessionCard`, `./AgentDetailPanel` → `./SessionDetailPanel`
- Fix store method names: `updateAgent` → `updateSession`, `removeAgent` → `removeSession`

- [ ] **Step 3: Transform Header.tsx**

Replace the entire tabs array and title:

```typescript
import { useLocation, Link } from 'react-router-dom';

const tabs = [
  { id: 'monitor', label: 'Session Monitor', path: '/' },
];

export function Header() {
  const location = useLocation();

  return (
    <header className="flex items-center justify-between border-b border-gray-800 px-6 py-3">
      <h1 className="text-lg font-bold text-blue-400">Dashboard</h1>
      <nav className="flex gap-1">
        {tabs.map(tab => {
          const isActive = location.pathname === tab.path;
          return (
            <Link
              key={tab.id}
              to={tab.path}
              className={`px-3 py-1.5 rounded text-sm ${
                isActive
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-400 hover:text-gray-200 hover:bg-gray-800'
              }`}
            >
              {tab.label}
            </Link>
          );
        })}
      </nav>
    </header>
  );
}
```

- [ ] **Step 4: Commit**

```bash
git add dashboard/frontend/src/components/
git commit -m "feat(dashboard): migrate frontend components with agent→session renames

Rename AgentCard→SessionCard, update Header title to Dashboard,
replace ticket display with taskInfo.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 13: Create App.tsx with embedded terminal panel

**Files:**
- Create: `dashboard/frontend/src/App.tsx`

- [ ] **Step 1: Write `dashboard/frontend/src/App.tsx`**

Single-page layout with session monitor and embedded terminal panel (no separate routes):

```typescript
import { BrowserRouter } from 'react-router-dom';
import { Header } from './components/Header.js';
import { SummaryBar } from './components/SummaryBar.js';
import { SessionGrid } from './components/SessionGrid.js';
import { SessionDetailPanel } from './components/SessionDetailPanel.js';
import { ActivityFeed } from './components/ActivityFeed.js';
import { TerminalContainer } from './components/terminal/TerminalContainer.js';
import { useSocket } from './hooks/use-socket.js';
import { useTerminalSocket } from './hooks/use-terminal-socket.js';
import { useTerminalStore } from './store/terminal-store.js';

function SessionMonitorPage() {
  const layout = useTerminalStore(s => s.layout);

  return (
    <div className="flex flex-col flex-1 overflow-hidden">
      <div className={`flex-1 overflow-auto ${layout ? 'max-h-[60vh]' : ''}`}>
        <SummaryBar />
        <SessionGrid />
        <SessionDetailPanel />
        <ActivityFeed />
      </div>
      {layout && (
        <div className="border-t border-gray-800 min-h-[200px] flex-shrink-0" style={{ height: '40vh' }}>
          <TerminalContainer />
        </div>
      )}
    </div>
  );
}

export function App() {
  useSocket();
  useTerminalSocket();

  return (
    <BrowserRouter>
      <div className="min-h-screen flex flex-col bg-gray-950 text-gray-100">
        <Header />
        <SessionMonitorPage />
      </div>
    </BrowserRouter>
  );
}
```

- [ ] **Step 2: Install frontend dependencies**

```bash
cd dashboard/frontend && pnpm install
```

- [ ] **Step 3: Verify frontend compiles**

```bash
cd dashboard/frontend && npx tsc --noEmit
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add dashboard/frontend/src/App.tsx dashboard/frontend/pnpm-lock.yaml
git commit -m "feat(dashboard): create single-page App with embedded terminal panel

Session monitor with embedded terminal panel at bottom.
No separate routes for workflow or terminal.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 14: Migrate frontend tests

**Files:**
- Create: `dashboard/frontend/src/components/__tests__/SessionCard.test.tsx`
- Create: `dashboard/frontend/src/components/terminal/__tests__/TerminalContextMenu.test.tsx`
- Create: `dashboard/frontend/src/hooks/__tests__/use-terminal-socket.test.ts`
- Create: `dashboard/frontend/src/store/__tests__/session-store.test.ts`
- Create: `dashboard/frontend/src/store/__tests__/terminal-store.test.ts`
- Create: `dashboard/frontend/vitest.config.ts`

- [ ] **Step 1: Copy vitest config**

```bash
cp claude-dev/packages/web/vitest.config.ts dashboard/frontend/
```

- [ ] **Step 2: Copy and rename test files**

```bash
mkdir -p dashboard/frontend/src/components/__tests__
mkdir -p dashboard/frontend/src/components/terminal/__tests__
mkdir -p dashboard/frontend/src/hooks/__tests__
mkdir -p dashboard/frontend/src/store/__tests__

cp claude-dev/packages/web/src/components/__tests__/AgentCard.test.tsx dashboard/frontend/src/components/__tests__/SessionCard.test.tsx
cp claude-dev/packages/web/src/components/terminal/__tests__/TerminalContextMenu.test.tsx dashboard/frontend/src/components/terminal/__tests__/
cp claude-dev/packages/web/src/hooks/__tests__/use-terminal-socket.test.ts dashboard/frontend/src/hooks/__tests__/
cp claude-dev/packages/web/src/store/__tests__/agent-store.test.ts dashboard/frontend/src/store/__tests__/session-store.test.ts
cp claude-dev/packages/web/src/store/__tests__/terminal-store.test.ts dashboard/frontend/src/store/__tests__/
```

- [ ] **Step 3: Transform test files**

In all copied test files:
- Replace `from '@claude-dev/shared'` → `from '@dashboard/types'`
- In `SessionCard.test.tsx`: rename component import, `AgentCard` → `SessionCard`, `agent` → `session`, `ticket` → `taskInfo`
- In `session-store.test.ts`: rename `useAgentStore` → `useSessionStore`, `AgentSession` → `Session`, `updateAgent` → `updateSession`, `removeAgent` → `removeSession`, `ticket` → `taskInfo`

- [ ] **Step 4: Run frontend tests**

```bash
cd dashboard/frontend && pnpm test
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add dashboard/frontend/vitest.config.ts dashboard/frontend/src/*/__tests__/ dashboard/frontend/src/components/terminal/__tests__/
git commit -m "test(dashboard): migrate frontend tests with agent→session renames

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

## Chunk 4: Docker Deployment & Final Verification

### Task 15: Add Docker deployment

**Files:**
- Create: `dashboard/Dockerfile`
- Create: `dashboard/docker-compose.yml`
- Create: `dashboard/.dockerignore`

- [ ] **Step 1: Create `dashboard/Dockerfile`**

```dockerfile
FROM node:18-slim

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Install backend dependencies
COPY backend/package.json backend/pnpm-lock.yaml ./backend/
RUN cd backend && pnpm install --frozen-lockfile

# Install frontend dependencies and build
COPY frontend/package.json frontend/pnpm-lock.yaml ./frontend/
RUN cd frontend && pnpm install --frozen-lockfile

# Copy source
COPY types/ ./types/
COPY backend/ ./backend/
COPY frontend/ ./frontend/

# Build frontend
RUN cd frontend && pnpm build

# Build backend
RUN cd backend && pnpm build

EXPOSE 3141

CMD ["node", "backend/dist/index.js"]
```

- [ ] **Step 2: Create `dashboard/docker-compose.yml`**

```yaml
services:
  dashboard:
    build: .
    ports:
      - "127.0.0.1:3141:3141"
    volumes:
      - "${HOME}/.claude:/root/.claude:ro"
    environment:
      - HOST=0.0.0.0
      - PORT=3141
      - HOME=/root
    restart: unless-stopped
```

Note: Inside Docker, we bind to `0.0.0.0` (the container's network), but the port mapping `127.0.0.1:3141:3141` ensures only localhost can reach it from the host.

- [ ] **Step 3: Create `dashboard/.dockerignore`**

```
**/node_modules
**/dist
**/.git
```

- [ ] **Step 4: Commit**

```bash
git add dashboard/Dockerfile dashboard/docker-compose.yml dashboard/.dockerignore
git commit -m "feat(dashboard): add Docker deployment with docker-compose

Single-command deploy: docker-compose up -d
Binds to 127.0.0.1:3141, mounts ~/.claude read-only.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 16: End-to-end verification

- [ ] **Step 1: Verify backend compiles clean**

```bash
cd dashboard/backend && npx tsc --noEmit
```

Expected: No errors.

- [ ] **Step 2: Run backend tests**

```bash
cd dashboard/backend && pnpm test
```

Expected: All tests PASS.

- [ ] **Step 3: Verify frontend compiles clean**

```bash
cd dashboard/frontend && npx tsc --noEmit
```

Expected: No errors.

- [ ] **Step 4: Run frontend tests**

```bash
cd dashboard/frontend && pnpm test
```

Expected: All tests PASS.

- [ ] **Step 5: Build frontend**

```bash
cd dashboard/frontend && pnpm build
```

Expected: `dist/` directory created with bundled assets.

- [ ] **Step 6: Test dev mode startup**

Terminal 1:
```bash
cd dashboard/backend && pnpm dev
```
Expected: `Dashboard server listening on http://127.0.0.1:3141`

Terminal 2:
```bash
cd dashboard/frontend && pnpm dev
```
Expected: Vite dev server on http://127.0.0.1:3000, proxying API to :3141.

- [ ] **Step 7: Test Docker build**

```bash
cd dashboard && docker compose build
```

Expected: Build succeeds.

- [ ] **Step 8: Final commit — update .gitignore**

Add `dashboard/*/node_modules/` and `dashboard/*/dist/` to root `.gitignore` if not already covered.

```bash
git add .gitignore
git commit -m "chore: update .gitignore for dashboard node_modules and dist

Co-authored-by: Claude <noreply@anthropic.com>"
```
