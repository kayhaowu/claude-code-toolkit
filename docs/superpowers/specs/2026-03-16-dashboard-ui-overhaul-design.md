# Dashboard UI Overhaul — Sidebar + Git Integration

**Date**: 2026-03-16
**Status**: Draft
**Scope**: Phase 2 — Restructure dashboard layout and add Git integration

## Overview

Restructure the dashboard from a card grid layout to a sidebar-based layout (inspired by CloudCLI UI), and add full Git integration. The sidebar shows all sessions with rich info; the main area uses tabs (Terminal / Activity / Git / Detail) for the selected session.

## Goals

- Sidebar navigation with rich session info (replaces card grid)
- Full Git integration: changes, history, branches, diff viewer
- Git operations: stage/unstage, commit, push/pull, fetch, stash, merge, branch management
- Maintain existing functionality (terminal, activity feed, session detail)

## Non-Goals

- Chat UI (terminal attach already provides prompt access)
- File explorer / code editor
- MCP server management
- Plugin system
- Mobile responsive (deferred)

## Layout Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ [Logo]  Claude Code Toolkit                [Session Monitor]│
├──────────┬──────────────────────────────────────────────────┤
│ Sidebar  │  Tab bar: [Terminal] [Activity] [Git] [Detail]  │
│ 260px    │──────────────────────────────────────────────────│
│          │                                                  │
│ [Search] │  Main content area                               │
│ [Filters]│  (changes based on active tab)                   │
│          │                                                  │
│ Session1 │                                                  │
│ Session2 │                                                  │
│ Session3 │                                                  │
│ ...      │                                                  │
│          │                                                  │
│──────────│                                                  │
│ Summary  │                                                  │
└──────────┴──────────────────────────────────────────────────┘
```

### Sidebar (260px, left)

Replaces the current `SessionGrid` + `SummaryBar` + `SessionCard` components.

**Header**: Logo + title
**Search**: Text input filtering sessions
**Filter pills**: All (count) / Working / Idle / Stopped
**Session list**: Scrollable list of session items, each showing:
  - Status dot (green/yellow/red)
  - Project name (bold)
  - Model + git branch
  - Current activity (tool:input or "idle")
  - Cost + token count + heartbeat age
  - Selected item: left blue border + darker background
**Footer**: Session count + total cost

### Main Area (flex, right)

**Tab bar**: Terminal / Activity / Git / Detail
- Only one tab visible at a time
- Terminal tab: existing xterm.js with "Open Terminal" button (explicit action, not auto-triggered on select)
- Activity tab: existing ActivityFeed component
- Git tab: new Git panel (see below)
- Detail tab: existing SessionDetailPanel content

## Git Tab Design

### Header Bar

```
┌──────────────────────────────────────────────────────────┐
│ ⎇ main ▼    ↑0 ↓0    [Fetch] [Pull] [Push] [Stash]     │
└──────────────────────────────────────────────────────────┘
```

- Branch selector dropdown (switch branches)
- Remote status: ahead/behind counts
- Action buttons: Fetch, Pull, Push, Stash

### Sub-tabs

Three views within the Git tab:

#### Changes View (default)

```
┌────────────────────┬─────────────────────────────────────┐
│ STAGED             │ Diff viewer                         │
│ ☑ M scanner.ts +15 │ src/store/session-store.ts          │
│                    │ +7 -3                    [Wrap]     │
│ CHANGES            │─────────────────────────────────────│
│ ☑ M session-store  │ 61  61   for (const session ...) {  │
│ ☐ A GitPanel.tsx   │ 64      - const merged: Session = { │
│                    │     64  + const status = (current... │
│────────────────────│     ...                              │
│ [Commit message..] │                                     │
│ [Commit][Commit+Push]                                    │
│ Ctrl+Enter · 1 staged                                    │
└────────────────────┴─────────────────────────────────────┘
```

**Left panel (320px)**:
- Staged files section (with Unstage All)
- Changes/unstaged files section (with Stage All)
- Each file: checkbox + status badge (M/A/D) + filename + +/- line counts + discard button
- Clicking a file shows its diff on the right
- Selected file has left blue border

**Commit composer (fixed bottom)**:
- Textarea for commit message
- Commit / Commit & Push buttons
- Keyboard shortcut: Ctrl+Enter to commit
- Shows staged file count

**Right panel (flex)**:
- Diff viewer with dual line numbers (old/new)
- Color-coded: green additions, red deletions, blue headers
- Text wrap toggle
- Large diff truncation (>200K chars or >1500 lines)

#### History View

Git tree visualization:
- Vertical lines connecting commit nodes
- HEAD commit: large green dot + HEAD/branch labels
- Regular commits: blue dots
- Merge commits: pink dots with branch lines + merge label
- Click to expand: shows commit details, stats, changed files, diff
- Fading colors for older commits

#### Branches View

- New Branch button with modal dialog
- Local branches section: current branch highlighted, ahead/behind counts, Switch/Delete actions
- Remote branches section: tracking info
- Confirmation modals for delete operations

### Confirmation Modals

Destructive or remote operations show confirmation dialogs:
- Discard changes (red)
- Delete untracked file (red)
- Revert commit (red)
- Pull (blue)
- Push (green)
- Force push (red)
- Delete branch (red)
- Merge (purple)

## Backend API

### New REST Endpoints

All git endpoints use `execFile('git', args, { cwd: projectDir })` — safe from shell injection.

```
GET  /api/git/status/:pid        # git status (staged, unstaged, branch)
GET  /api/git/log/:pid           # git log (recent commits)
GET  /api/git/diff/:pid          # git diff (unstaged changes)
GET  /api/git/diff-staged/:pid   # git diff --staged
GET  /api/git/diff-file/:pid     # git diff for specific file (query: path, staged=0|1)
GET  /api/git/stash-list/:pid    # git stash list
GET  /api/git/branches/:pid      # git branch -a (local + remote)
GET  /api/git/remote-status/:pid # ahead/behind counts
GET  /api/git/show/:pid/:sha     # git show (commit details + diff)

POST /api/git/stage/:pid         # git add (body: { paths: string[] })
POST /api/git/unstage/:pid       # git reset HEAD (body: { paths: string[] })
POST /api/git/commit/:pid        # git commit (body: { message: string })
POST /api/git/push/:pid          # git push
POST /api/git/pull/:pid          # git pull
POST /api/git/fetch/:pid         # git fetch
POST /api/git/stash/:pid         # git stash
POST /api/git/stash-pop/:pid     # git stash pop
POST /api/git/checkout/:pid      # git checkout (body: { branch: string })
POST /api/git/create-branch/:pid # git checkout -b (body: { name: string })
POST /api/git/delete-branch/:pid # git branch -d (body: { name: string })
POST /api/git/merge/:pid         # git merge (body: { branch: string })
POST /api/git/discard/:pid       # git checkout -- (body: { paths: string[] })
POST /api/git/revert/:pid        # git revert (body: { sha: string })
```

The `:pid` parameter identifies which session's project to operate on. Backend resolves PID → `projectDir` via SessionStore.

### Git Service (Backend)

New file: `backend/src/services/git-service.ts`

Uses `execFile` (not `exec`) to prevent shell injection:
```typescript
import { execFile } from 'node:child_process';
const result = await execFileAsync('git', ['status', '--porcelain'], { cwd: projectDir, timeout: 10000 });
```

Features:
- Timeout: 10s default, 30s for push/pull/fetch
- Error parsing: extract git error messages from stderr
- Output parsing: structured data for status, log, diff, branches
- Security: validate `projectDir` exists and is a git repo before executing

### Git Router (Backend)

New file: `backend/src/api/git-routes.ts`

Express router mounting all git endpoints. Uses `SessionStore` to resolve PID → projectDir.

## Frontend Components

### New Components

| Component | Description |
|-----------|-------------|
| `Sidebar.tsx` | Session list sidebar (replaces SessionGrid + SummaryBar) |
| `SidebarItem.tsx` | Individual session item in sidebar |
| `GitPanel.tsx` | Main Git tab container, manages sub-tab state |
| `GitHeader.tsx` | Branch selector + remote status + action buttons |
| `GitViewTabs.tsx` | Changes / History / Branches sub-tab bar |
| `ChangesView.tsx` | Staged/unstaged file lists + commit composer + diff |
| `CommitComposer.tsx` | Commit message textarea + buttons |
| `FileChangeItem.tsx` | Single file in changes list (checkbox, status, actions) |
| `DiffViewer.tsx` | Dual line-number diff viewer with syntax coloring |
| `HistoryView.tsx` | Git tree visualization with expandable commits |
| `CommitItem.tsx` | Single commit in history (expandable details + diff) |
| `BranchesView.tsx` | Branch list with switch/delete/create |
| `ConfirmModal.tsx` | Confirmation dialog for destructive/remote actions |

### Modified Components

| Component | Changes |
|-----------|---------|
| `App.tsx` | Replace grid layout with sidebar + main area |
| `Header.tsx` | Simplify (sidebar handles session nav) |

### Removed Components

| Component | Reason |
|-----------|--------|
| `SessionCard.tsx` | Replaced by SidebarItem |
| `SessionGrid.tsx` | Replaced by Sidebar |
| `SummaryBar.tsx` | Integrated into Sidebar footer |

### Frontend State

New Zustand store: `git-store.ts`

```typescript
interface GitStoreState {
  status: GitStatus | null;
  log: GitCommit[];
  branches: GitBranch[];
  remoteStatus: RemoteStatus;
  selectedFile: string | null;
  diff: string | null;
  activeView: 'changes' | 'history' | 'branches';
  loading: Set<string>;            // per-operation: 'status', 'log', 'commit', etc.
  error: string | null;

  fetchStatus: (pid: number) => Promise<void>;
  fetchLog: (pid: number, limit?: number) => Promise<void>;  // default 50
  fetchBranches: (pid: number) => Promise<void>;
  fetchDiff: (pid: number, path: string, staged: boolean) => Promise<void>;
  stage: (pid: number, paths: string[]) => Promise<void>;
  unstage: (pid: number, paths: string[]) => Promise<void>;
  commit: (pid: number, message: string) => Promise<void>;
  push: (pid: number) => Promise<void>;
  pull: (pid: number) => Promise<void>;
  // ... other operations
}
```

### Refresh Strategy

- **On tab open**: fetch status + log + branches in parallel
- **After mutation**: auto-refetch affected data (e.g., after commit → refetch status + log)
- **No polling**: Git data is on-demand only (unlike session data which polls every 2s)
- **Manual refresh**: button in Git header to force refetch all

### Log Pagination

`GET /api/git/log/:pid` accepts `?limit=50&skip=0`. Default: 50 commits. History view loads more on scroll.

### Data Flow

```
User clicks session in Sidebar
  → session-store.setSelected(id)
  → App renders main area tabs for selected session
  → If Git tab active:
      → git-store.fetchStatus(pid)
      → git-store.fetchLog(pid)
      → git-store.fetchBranches(pid)
      → Backend: execFile('git', ...) in projectDir
      → Response populates git-store
      → React components render from store
```

## Security

- All git operations use `execFile` (not `exec`) — prevents shell injection
- Operations scoped to session's `projectDir`
- Backend validates PID exists in SessionStore before executing
- Backend validates `projectDir` is a git repo (`git rev-parse --git-dir`)
- **Path validation**: all `paths` array parameters must be relative paths without `..` components. Backend rejects paths containing `..`, absolute paths, or paths starting with `/`
- **Branch name validation**: `create-branch` validates names against git's rules (no spaces, no `..`, no control chars, no `~^:?*[`)
- **Commit message validation**: reject empty messages, pass via `-m` argument (safe with `execFile`)
- Force push requires explicit confirmation
- Delete branch requires confirmation
- Branch switching blocked for sessions with status `working` (prevents corruption)
- Dashboard binds to 127.0.0.1 (no remote access by default)

## Error Handling

- Git errors parsed and surfaced in UI (e.g., merge conflicts, auth failures)
- Network errors show in Git header as dismissable banner
- Operations show loading spinners during execution
- Timeout: 10s default, 30s for push/pull/fetch
- Non-git directories show "Not a git repository" state

## Testing

- `git-service.test.ts`: Unit tests for git CLI wrapper (mock execFile)
- `git-routes.test.ts`: API endpoint tests
- `git-store.test.ts`: Frontend store tests
- `Sidebar.test.tsx`: Component tests for session list
- `ChangesView.test.tsx`: File list and staging interaction
- `DiffViewer.test.tsx`: Diff rendering

## Migration

Non-breaking UI refactor — same data flows through different components. Existing backend (SessionStore, LogTailer, TerminalManager) unchanged. New git endpoints are additive.

### Phased Approach

1. **Phase 2a**: Sidebar layout (replace grid with sidebar, restructure tabs)
2. **Phase 2b**: Git integration (add Git tab with all sub-views and backend)

Each phase is independently deployable and testable.
