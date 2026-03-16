# Dashboard Git Integration Implementation Plan (Phase 2b)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full Git integration to the dashboard — view changes, stage/unstage, commit, push/pull, branch management, diff viewer, and git tree history.

**Architecture:** Backend: Express routes wrapping `execFile('git', ...)` (not exec — safe from shell injection) scoped to session's projectDir. Frontend: Git tab with three sub-views (Changes/History/Branches), Zustand store, diff viewer component. Prerequisite: Phase 2a sidebar layout must be completed first.

**Tech Stack:** Express 4, `child_process.execFile`, React 18, Zustand 5, Tailwind CSS 3, TypeScript 5.7+

**Spec:** `docs/superpowers/specs/2026-03-16-dashboard-ui-overhaul-design.md`

---

## Chunk 1: Backend — Git Service + Routes

### Task 1: Create Git service (`backend/src/services/git-service.ts`)

Wraps `execFile('git', args, { cwd })` with validation, parsing, and timeouts. See spec for full API. Key functions: `getStatus`, `getLog`, `getDiff`, `getFileDiff`, `getBranches`, `getRemoteStatus`, `stage`, `unstage`, `commit`, `push`, `pull`, `fetch_`, `stash`, `stashPop`, `stashList`, `checkout`, `createBranch`, `deleteBranch`, `merge`, `discard`, `revert`.

Security: `validatePaths()` rejects `..` and absolute paths. `validateBranchName()` rejects invalid chars. All operations use `execFile` (array args, no shell).

### Task 2: Create Git API routes (`backend/src/api/git-routes.ts`)

Express router with PID→projectDir middleware. 18+ endpoints matching spec. Mount in `index.ts` as `app.use('/api/git', createGitRouter(store))`. Block branch switch for working sessions (409).

### Task 3: Backend tests

Test git-service output parsing (mock execFile) and route middleware (mock git-service).

---

## Chunk 2: Frontend — Git Store

### Task 4: Create Git Zustand store (`frontend/src/store/git-store.ts`)

State: `status`, `log`, `branches`, `remoteStatus`, `selectedFile`, `diff`, `activeView`, `loading: Set<string>`, `error`. Fetch methods call REST API. Mutation methods auto-refetch affected data after success. `refreshAll()` fetches status + log + branches + remote in parallel.

### Task 5: Git store tests

---

## Chunk 3: Frontend — Git Components

### Task 6: DiffViewer (`frontend/src/components/git/DiffViewer.tsx`)

Parse unified diff format. Dual line numbers. Catppuccin colors (green additions, red deletions, blue headers). Truncation >1500 lines. Wrap toggle.

### Task 7: ChangesView (`frontend/src/components/git/ChangesView.tsx`)

Left panel: staged/unstaged file lists with checkboxes, status badges, discard buttons. `FileChangeItem.tsx` for each file. `CommitComposer.tsx` fixed at bottom with textarea + Commit / Commit & Push buttons + Ctrl+Enter shortcut. Right panel: DiffViewer for selected file.

### Task 8: HistoryView (`frontend/src/components/git/HistoryView.tsx`)

Git tree visualization. `CommitItem.tsx` with expandable details. Parse parent SHAs to determine merge commits. Vertical lines, colored dots (HEAD=green, regular=blue, merge=pink). Load more on scroll.

### Task 9: BranchesView (`frontend/src/components/git/BranchesView.tsx`)

Local/remote sections. Current branch highlight. Ahead/behind counts. Switch/Delete actions. `ConfirmModal.tsx` for destructive operations. New Branch modal.

### Task 10: GitPanel + GitHeader + GitViewTabs

`GitPanel.tsx`: main container, triggers `refreshAll` on mount/session change. `GitHeader.tsx`: branch dropdown + remote status + action buttons (Fetch/Pull/Push/Stash). `GitViewTabs.tsx`: Changes/History/Branches sub-tabs with badge counter.

---

## Chunk 4: Integration + Verification

### Task 11: Wire GitPanel into App.tsx

Replace "Git coming in Phase 2b" placeholder with `<GitPanel />`. Import and render when `activeTab === 'git'`.

### Task 12: End-to-end verification

Build frontend, start server, verify:
- Changes view: stage/unstage files, view diffs, commit with message
- History view: git tree renders, click commit to see diff
- Branches view: switch branch, create new, delete
- Header: pull/push/fetch work, stash/pop
- Error states: non-git directory, merge conflicts, auth failures
- All existing features still work (terminal, activity, session monitor)

### Task 13: Update spec and docs

Mark Phase 2b as completed in spec. Update README if needed.
