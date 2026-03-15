import { create } from 'zustand';
import type { TerminalSession } from '@dashboard/types';

export type SplitLayout =
  | { type: 'terminal'; paneId: string; sessionId: string }
  | {
      type: 'split';
      splitId: string;
      direction: 'horizontal' | 'vertical';
      ratio: number;
      children: [SplitLayout, SplitLayout];
    };

interface TerminalStoreState {
  sessions: Map<string, TerminalSession>;
  layout: SplitLayout | null;
  activePaneId: string | null;
  error: string | null;

  setSessions: (sessions: TerminalSession[]) => void;
  addSession: (session: TerminalSession) => void;
  removeSession: (id: string) => void;
  splitPane: (paneId: string, direction: 'horizontal' | 'vertical', sessionId: string) => void;
  closePane: (paneId: string) => void;
  setActivePane: (paneId: string) => void;
  resizePane: (splitId: string, ratio: number) => void;
  setError: (error: string | null) => void;
  clearError: () => void;
}

let paneCounter = 0;
function nextPaneId(): string {
  return `p${++paneCounter}`;
}

let splitCounter = 0;
function nextSplitId(): string {
  return `s${++splitCounter}`;
}

function splitNode(
  node: SplitLayout,
  targetPaneId: string,
  direction: 'horizontal' | 'vertical',
  sessionId: string,
): SplitLayout | null {
  if (node.type === 'terminal') {
    if (node.paneId === targetPaneId) {
      return {
        type: 'split',
        splitId: nextSplitId(),
        direction,
        ratio: 0.5,
        children: [node, { type: 'terminal', paneId: nextPaneId(), sessionId }],
      };
    }
    return null;
  }
  const leftResult = splitNode(node.children[0], targetPaneId, direction, sessionId);
  if (leftResult) return { ...node, children: [leftResult, node.children[1]] };

  const rightResult = splitNode(node.children[1], targetPaneId, direction, sessionId);
  if (rightResult) return { ...node, children: [node.children[0], rightResult] };

  return null;
}

function removePane(node: SplitLayout, targetPaneId: string): SplitLayout | null | 'removed' {
  if (node.type === 'terminal') {
    return node.paneId === targetPaneId ? 'removed' : null;
  }
  const leftResult = removePane(node.children[0], targetPaneId);
  if (leftResult === 'removed') return node.children[1];

  const rightResult = removePane(node.children[1], targetPaneId);
  if (rightResult === 'removed') return node.children[0];

  if (leftResult !== null) return { ...node, children: [leftResult as SplitLayout, node.children[1]] };
  if (rightResult !== null) return { ...node, children: [node.children[0], rightResult as SplitLayout] };

  return null;
}

function updateRatio(node: SplitLayout, targetSplitId: string, ratio: number): SplitLayout | null {
  if (node.type === 'terminal') return null;

  if (node.splitId === targetSplitId) {
    return { ...node, ratio };
  }

  const leftResult = updateRatio(node.children[0], targetSplitId, ratio);
  if (leftResult) return { ...node, children: [leftResult, node.children[1]] };

  const rightResult = updateRatio(node.children[1], targetSplitId, ratio);
  if (rightResult) return { ...node, children: [node.children[0], rightResult] };

  return null;
}

function findFirstPaneId(node: SplitLayout): string {
  if (node.type === 'terminal') return node.paneId;
  return findFirstPaneId(node.children[0]);
}

export const useTerminalStore = create<TerminalStoreState>((set, get) => ({
  sessions: new Map(),
  layout: null,
  activePaneId: null,
  error: null,

  setSessions: (sessions) => {
    const map = new Map<string, TerminalSession>();
    for (const s of sessions) map.set(s.id, s);
    set({ sessions: map });
  },

  addSession: (session) => {
    set((state) => {
      const sessions = new Map(state.sessions);
      sessions.set(session.id, session);
      return { sessions };
    });
  },

  removeSession: (id) => {
    set((state) => {
      const sessions = new Map(state.sessions);
      sessions.delete(id);
      return { sessions };
    });
  },

  splitPane: (paneId, direction, sessionId) => {
    const { layout } = get();
    if (!layout) return;
    const result = splitNode(layout, paneId, direction, sessionId);
    if (result) set({ layout: result });
  },

  closePane: (paneId) => {
    const { layout, activePaneId } = get();
    if (!layout) return;
    if (layout.type === 'terminal' && layout.paneId === paneId) {
      set({ layout: null, activePaneId: null });
      return;
    }
    const result = removePane(layout, paneId);
    if (result && result !== 'removed') {
      const newActive = activePaneId === paneId ? findFirstPaneId(result) : activePaneId;
      set({ layout: result, activePaneId: newActive });
    }
  },

  setActivePane: (paneId) => set({ activePaneId: paneId }),

  setError: (error) => set({ error }),
  clearError: () => set({ error: null }),

  resizePane: (splitId, ratio) => {
    const { layout } = get();
    if (!layout) return;
    const clamped = Math.max(0.1, Math.min(0.9, ratio));
    const result = updateRatio(layout, splitId, clamped);
    if (result) set({ layout: result });
  },
}));
