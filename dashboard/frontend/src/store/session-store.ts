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

// Derived selectors — memoized to prevent unnecessary re-renders
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
