# Dashboard Sidebar Layout Implementation Plan (Phase 2a)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the card grid layout with a sidebar-based layout — session list on the left, tabbed main area on the right (Terminal / Activity / Git / Detail).

**Architecture:** Refactor the frontend only. No backend changes. Replace `SessionGrid`, `SummaryBar`, `SessionCard` with `Sidebar` + `SidebarItem`. Restructure `App.tsx` from single-page grid to sidebar + tabs layout. Existing components (ActivityFeed, SessionDetailPanel, TerminalContainer) become tab contents.

**Tech Stack:** React 18, Zustand 5, Tailwind CSS 3, TypeScript 5.7+

**Spec:** `docs/superpowers/specs/2026-03-16-dashboard-ui-overhaul-design.md`

---

## Chunk 1: Sidebar Components

### Task 1: Create SidebarItem component

**Files:**
- Create: `dashboard/frontend/src/components/sidebar/SidebarItem.tsx`
- Test: `dashboard/frontend/src/components/sidebar/__tests__/SidebarItem.test.tsx`

- [ ] **Step 1: Create SidebarItem component**

```typescript
// dashboard/frontend/src/components/sidebar/SidebarItem.tsx
import type { Session } from '@dashboard/types';

function formatTokens(n: number): string {
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(0)}K`;
  return String(n);
}

function formatHeartbeatAge(lastHeartbeat: number): string {
  const ageMs = Date.now() - lastHeartbeat;
  const secs = Math.floor(ageMs / 1000);
  if (secs < 10) return 'just now';
  if (secs < 60) return `${secs}s ago`;
  const mins = Math.floor(secs / 60);
  return `${mins}m ago`;
}

const statusColors: Record<string, string> = {
  working: 'bg-green-500',
  idle: 'bg-yellow-500',
  stopped: 'bg-red-500',
};

const heartbeatColors: Record<string, (ms: number) => string> = {
  fresh: () => 'text-green-400',
  stale: () => 'text-yellow-400',
  dead: () => 'text-red-400',
};

function heartbeatColor(lastHeartbeat: number): string {
  const ageMs = Date.now() - lastHeartbeat;
  if (ageMs < 10_000) return 'text-green-400';
  if (ageMs < 30_000) return 'text-yellow-400';
  return 'text-red-400';
}

interface SidebarItemProps {
  session: Session;
  isSelected: boolean;
  onSelect: (id: string) => void;
}

export function SidebarItem({ session, isSelected, onSelect }: SidebarItemProps) {
  return (
    <div
      onClick={() => onSelect(session.id)}
      className={`px-3 py-2.5 cursor-pointer border-l-[3px] ${
        isSelected
          ? 'border-blue-500 bg-gray-800/80'
          : 'border-transparent hover:bg-gray-800/40'
      }`}
    >
      <div className="flex items-center gap-2 mb-1">
        <span className={`w-2 h-2 rounded-full flex-shrink-0 ${statusColors[session.status]}`} />
        <span className="font-medium text-xs truncate">{session.projectName}</span>
      </div>
      <div className="pl-4 text-[10px] text-gray-500 space-y-0.5">
        <div>{session.model} · {session.gitBranch ? `⎇ ${session.gitBranch}` : 'no branch'}</div>
        <div className={session.currentActivity.type !== 'idle' ? 'text-blue-400' : ''}>
          {session.currentActivity.type === 'tool_use'
            ? `${session.currentActivity.tool}: ${session.currentActivity.toolInput}`
            : 'idle'}
        </div>
        <div className="flex justify-between">
          <span>${session.costUsd.toFixed(2)} · {formatTokens(session.tokensOut)} out</span>
          <span className={heartbeatColor(session.lastHeartbeat)}>
            {formatHeartbeatAge(session.lastHeartbeat)}
          </span>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Write SidebarItem test**

```typescript
// dashboard/frontend/src/components/sidebar/__tests__/SidebarItem.test.tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { SidebarItem } from '../SidebarItem.js';
import type { Session } from '@dashboard/types';

function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    id: '123', pid: 123, projectName: 'test-proj', projectDir: '/tmp/test',
    gitBranch: 'main', model: 'Opus 4.6', costUsd: 5.5, tokensIn: 1000,
    tokensOut: 50000, memKb: 100000, status: 'working',
    startedAt: Date.now() - 60000, lastHeartbeat: Date.now() - 2000,
    tmux: { session: 's', window: '0', windowName: 'test', pane: '0', tty: '' },
    taskInfo: {}, currentActivity: { type: 'idle', since: Date.now() },
    recentActivity: [], dataSource: 'polling',
    ...overrides,
  } as Session;
}

describe('SidebarItem', () => {
  it('renders project name and model', () => {
    render(<SidebarItem session={makeSession()} isSelected={false} onSelect={() => {}} />);
    expect(screen.getByText('test-proj')).toBeDefined();
  });

  it('shows selected state with blue border', () => {
    const { container } = render(
      <SidebarItem session={makeSession()} isSelected={true} onSelect={() => {}} />
    );
    expect(container.firstChild).toHaveClass('border-blue-500');
  });

  it('calls onSelect when clicked', () => {
    const onSelect = vi.fn();
    render(<SidebarItem session={makeSession()} isSelected={false} onSelect={onSelect} />);
    fireEvent.click(screen.getByText('test-proj'));
    expect(onSelect).toHaveBeenCalledWith('123');
  });

  it('shows tool activity when working', () => {
    const session = makeSession({
      currentActivity: { type: 'tool_use', tool: 'Edit', toolInput: 'file.ts', since: Date.now() },
    });
    render(<SidebarItem session={session} isSelected={false} onSelect={() => {}} />);
    expect(screen.getByText('Edit: file.ts')).toBeDefined();
  });
});
```

- [ ] **Step 3: Run tests**

```bash
cd dashboard/frontend && pnpm test
```

- [ ] **Step 4: Commit**

```bash
git add dashboard/frontend/src/components/sidebar/
git commit -m "feat(dashboard): add SidebarItem component

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 2: Create Sidebar component

**Files:**
- Create: `dashboard/frontend/src/components/sidebar/Sidebar.tsx`
- Create: `dashboard/frontend/src/components/sidebar/index.ts`

- [ ] **Step 1: Create Sidebar component**

```typescript
// dashboard/frontend/src/components/sidebar/Sidebar.tsx
import { useSessionStore, useSortedSessions } from '../../store/session-store.js';
import { SidebarItem } from './SidebarItem.js';

export function Sidebar() {
  const sessions = useSortedSessions();
  const selectedId = useSessionStore(s => s.selectedId);
  const setSelected = useSessionStore(s => s.setSelected);
  const setFilter = useSessionStore(s => s.setFilter);
  const filter = useSessionStore(s => s.filter);
  const allSessions = useSessionStore(s => s.sessions);

  const counts = {
    all: allSessions.size,
    working: Array.from(allSessions.values()).filter(s => s.status === 'working').length,
    idle: Array.from(allSessions.values()).filter(s => s.status === 'idle').length,
    stopped: Array.from(allSessions.values()).filter(s => s.status === 'stopped').length,
  };

  const totalCost = Array.from(allSessions.values()).reduce((sum, s) => sum + s.costUsd, 0);

  return (
    <div className="w-[260px] border-r border-gray-800 flex flex-col bg-gray-950 flex-shrink-0">
      {/* Header */}
      <div className="px-4 py-3 border-b border-gray-800 flex items-center gap-2">
        <img src="/favicon.svg" alt="logo" width="18" height="18" style={{ imageRendering: 'pixelated' }} />
        <span className="font-bold text-sm text-blue-400">Claude Code Toolkit</span>
      </div>

      {/* Search */}
      <div className="px-3 py-2">
        <input
          type="text"
          placeholder="Search sessions..."
          value={filter.search}
          onChange={e => setFilter({ search: e.target.value })}
          className="w-full bg-gray-800 rounded px-3 py-1.5 text-xs text-gray-300 placeholder-gray-600 outline-none focus:ring-1 focus:ring-blue-500"
        />
      </div>

      {/* Filter pills */}
      <div className="px-3 pb-2 flex gap-1 flex-wrap">
        {([
          { key: null, label: `All ${counts.all}`, color: 'bg-blue-500/20 text-blue-400' },
          { key: 'working', label: `⚡ ${counts.working}`, color: 'bg-green-500/20 text-green-400' },
          { key: 'idle', label: `💤 ${counts.idle}`, color: 'bg-yellow-500/20 text-yellow-400' },
          { key: 'stopped', label: `⏹ ${counts.stopped}`, color: 'bg-red-500/20 text-red-400' },
        ] as const).map(f => (
          <button
            key={f.label}
            onClick={() => setFilter({ status: f.key })}
            className={`px-2 py-0.5 rounded-full text-[10px] ${
              filter.status === f.key ? f.color : 'bg-gray-800 text-gray-500'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Session list */}
      <div className="flex-1 overflow-y-auto">
        {sessions.map(session => (
          <SidebarItem
            key={session.id}
            session={session}
            isSelected={selectedId === session.id}
            onSelect={setSelected}
          />
        ))}
        {sessions.length === 0 && (
          <div className="text-center text-gray-600 text-xs py-8">No sessions found</div>
        )}
      </div>

      {/* Footer */}
      <div className="px-3 py-2 border-t border-gray-800 flex justify-between text-[10px] text-gray-600">
        <span>{counts.all} sessions</span>
        <span>Total: ${totalCost.toFixed(2)}</span>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Create barrel export**

```typescript
// dashboard/frontend/src/components/sidebar/index.ts
export { Sidebar } from './Sidebar.js';
export { SidebarItem } from './SidebarItem.js';
```

- [ ] **Step 3: Commit**

```bash
git add dashboard/frontend/src/components/sidebar/
git commit -m "feat(dashboard): add Sidebar component with search, filters, summary

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

## Chunk 2: App Layout Restructure

### Task 3: Add active tab to session store

**Files:**
- Modify: `dashboard/frontend/src/store/session-store.ts`

- [ ] **Step 1: Add `activeTab` to session store**

Add to `SessionStoreState` interface and store:

```typescript
// Add to interface:
activeTab: 'terminal' | 'activity' | 'git' | 'detail';
setActiveTab: (tab: SessionStoreState['activeTab']) => void;

// Add to store defaults:
activeTab: 'terminal',
setActiveTab: (tab) => set({ activeTab: tab }),
```

- [ ] **Step 2: Commit**

```bash
git add dashboard/frontend/src/store/session-store.ts
git commit -m "feat(dashboard): add activeTab to session store

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 4: Create TabBar component

**Files:**
- Create: `dashboard/frontend/src/components/TabBar.tsx`

- [ ] **Step 1: Create TabBar**

```typescript
// dashboard/frontend/src/components/TabBar.tsx
import { useSessionStore } from '../store/session-store.js';

const tabs = [
  { key: 'terminal' as const, label: 'Terminal' },
  { key: 'activity' as const, label: 'Activity' },
  { key: 'git' as const, label: 'Git' },
  { key: 'detail' as const, label: 'Detail' },
];

export function TabBar() {
  const activeTab = useSessionStore(s => s.activeTab);
  const setActiveTab = useSessionStore(s => s.setActiveTab);

  return (
    <div className="flex border-b border-gray-800 bg-gray-900/50">
      {tabs.map(tab => (
        <button
          key={tab.key}
          onClick={() => setActiveTab(tab.key)}
          className={`px-5 py-2.5 text-xs transition-colors ${
            activeTab === tab.key
              ? 'border-b-2 border-blue-500 text-blue-400'
              : 'text-gray-500 hover:text-gray-300'
          }`}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add dashboard/frontend/src/components/TabBar.tsx
git commit -m "feat(dashboard): add TabBar component for main area tabs

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 5: Rewrite App.tsx with sidebar layout

**Files:**
- Modify: `dashboard/frontend/src/App.tsx`
- Modify: `dashboard/frontend/src/components/Header.tsx`

- [ ] **Step 1: Rewrite App.tsx**

Replace entire file:

```typescript
// dashboard/frontend/src/App.tsx
import { BrowserRouter } from 'react-router-dom';
import { Sidebar } from './components/sidebar/index.js';
import { TabBar } from './components/TabBar.js';
import { SessionDetailPanel } from './components/SessionDetailPanel.js';
import { ActivityFeed } from './components/ActivityFeed.js';
import { TerminalContainer } from './components/terminal/TerminalContainer.js';
import { ErrorBoundary } from './components/ErrorBoundary.js';
import { ConnectionBanner } from './components/ConnectionBanner.js';
import { useSocket } from './hooks/use-socket.js';
import { useTerminalSocket } from './hooks/use-terminal-socket.js';
import { useSessionStore } from './store/session-store.js';
import { useTerminalStore } from './store/terminal-store.js';

function MainContent() {
  const selectedId = useSessionStore(s => s.selectedId);
  const activeTab = useSessionStore(s => s.activeTab);
  const layout = useTerminalStore(s => s.layout);
  const terminalError = useTerminalStore(s => s.error);

  if (!selectedId) {
    return (
      <div className="flex-1 flex items-center justify-center text-gray-600 text-sm">
        Select a session from the sidebar
      </div>
    );
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <TabBar />
      <div className="flex-1 overflow-auto">
        {activeTab === 'terminal' && (
          <div className="h-full flex flex-col">
            {terminalError && (
              <div className="bg-red-900/50 border-b border-red-700 px-4 py-2 text-sm text-red-200">
                Terminal error: {terminalError}
              </div>
            )}
            {layout ? (
              <div className="flex-1">
                <TerminalContainer />
              </div>
            ) : (
              <div className="flex-1 flex items-center justify-center text-gray-600 text-sm">
                Click "Open Terminal" on a session to connect
              </div>
            )}
          </div>
        )}
        {activeTab === 'activity' && <ActivityFeed />}
        {activeTab === 'git' && (
          <div className="flex-1 flex items-center justify-center text-gray-600 text-sm">
            Git integration coming in Phase 2b
          </div>
        )}
        {activeTab === 'detail' && <SessionDetailPanel />}
      </div>
    </div>
  );
}

export function App() {
  useSocket();
  useTerminalSocket();

  return (
    <BrowserRouter>
      <ErrorBoundary>
        <div className="h-screen flex flex-col bg-gray-950 text-gray-100">
          <ConnectionBanner />
          <div className="flex-1 flex overflow-hidden">
            <Sidebar />
            <MainContent />
          </div>
        </div>
      </ErrorBoundary>
    </BrowserRouter>
  );
}
```

- [ ] **Step 2: Simplify Header.tsx (no longer needed as standalone)**

Header is now integrated into Sidebar. Remove the standalone `Header.tsx` or make it minimal:

```typescript
// dashboard/frontend/src/components/Header.tsx
// This component is no longer used — header is in Sidebar.
// Keep as empty export for backward compatibility, remove in cleanup.
export function Header() {
  return null;
}
```

- [ ] **Step 3: Verify compilation**

```bash
cd dashboard/frontend && npx tsc --noEmit
```

- [ ] **Step 4: Build and test**

```bash
cd dashboard/frontend && pnpm build && pnpm test
```

- [ ] **Step 5: Commit**

```bash
git add dashboard/frontend/src/App.tsx dashboard/frontend/src/components/Header.tsx
git commit -m "feat(dashboard): restructure to sidebar + tabs layout

Replace card grid with sidebar session list and tabbed main area.
Terminal, Activity, Detail as tab contents. Git tab placeholder.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 6: Move Open Terminal button to sidebar or terminal tab

**Files:**
- Modify: `dashboard/frontend/src/components/sidebar/SidebarItem.tsx`

The "Open Terminal" button was on SessionCard. Now it needs to be accessible from the sidebar. Add a small terminal icon button on the sidebar item that appears on hover:

- [ ] **Step 1: Add terminal button to SidebarItem**

Add to SidebarItem, after the heartbeat line:

```typescript
// Inside SidebarItem, add at the end of the outer div, after the info block:
{session.status !== 'stopped' && session.tmux.session && (
  <button
    onClick={(e) => {
      e.stopPropagation();
      const { acquireSocket } = await import('../../hooks/socket.js');
      const socket = acquireSocket();
      socket.emit('terminal:open', { mode: 'attach', sessionPid: session.pid });
      const { useTerminalStore } = await import('../../store/terminal-store.js');
      useTerminalStore.getState().openPane(`pending-${session.pid}`);
      // Also switch to terminal tab
      const { useSessionStore } = await import('../../store/session-store.js');
      useSessionStore.getState().setActiveTab('terminal');
    }}
    className="mt-1.5 w-full py-1 rounded bg-gray-800/50 hover:bg-gray-700 text-gray-400 text-[10px] border border-gray-700/50"
  >
    Open Terminal
  </button>
)}
```

Note: Use static imports instead of dynamic imports. Move the imports to the top of the file:

```typescript
import { acquireSocket } from '../../hooks/socket.js';
import { useTerminalStore } from '../../store/terminal-store.js';
import { useSessionStore } from '../../store/session-store.js';
```

- [ ] **Step 2: Commit**

```bash
git add dashboard/frontend/src/components/sidebar/SidebarItem.tsx
git commit -m "feat(dashboard): add Open Terminal button to SidebarItem

Clicking opens terminal and switches to terminal tab.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 7: Update tests for new layout

**Files:**
- Modify: `dashboard/frontend/src/components/__tests__/SessionCard.test.tsx` (may need removal or update)
- Modify: `dashboard/frontend/src/store/__tests__/session-store.test.ts` (add activeTab tests)

- [ ] **Step 1: Add activeTab tests to session-store.test.ts**

```typescript
describe('activeTab', () => {
  it('defaults to terminal', () => {
    expect(useSessionStore.getState().activeTab).toBe('terminal');
  });

  it('can switch tabs', () => {
    useSessionStore.getState().setActiveTab('git');
    expect(useSessionStore.getState().activeTab).toBe('git');
  });
});
```

- [ ] **Step 2: Run all tests**

```bash
cd dashboard/frontend && pnpm test
cd dashboard/backend && pnpm test
```

Fix any broken tests due to layout changes (SessionCard tests may need adjustment since SessionCard is no longer used in App).

- [ ] **Step 3: Commit**

```bash
git add dashboard/frontend/src/
git commit -m "test(dashboard): update tests for sidebar layout

Add activeTab tests, fix broken SessionCard tests.

Co-authored-by: Claude <noreply@anthropic.com>"
```

---

### Task 8: End-to-end verification

- [ ] **Step 1: Build frontend**

```bash
cd dashboard/frontend && pnpm build
```

- [ ] **Step 2: Start server and verify**

```bash
cd dashboard/backend && node --experimental-strip-types --experimental-transform-types src/index.ts
```

Open http://127.0.0.1:3141 and verify:
- Sidebar shows all sessions with rich info
- Clicking a session selects it (blue border)
- Tab bar appears with Terminal / Activity / Git / Detail
- Terminal tab shows xterm.js when opened
- Activity tab shows activity feed
- Detail tab shows session details
- Git tab shows placeholder
- Search and filter pills work

- [ ] **Step 3: Final commit with .gitignore updates if needed**

```bash
git add -A && git status
# Only commit relevant changes
git commit -m "chore(dashboard): Phase 2a sidebar layout complete

Co-authored-by: Claude <noreply@anthropic.com>"
```
