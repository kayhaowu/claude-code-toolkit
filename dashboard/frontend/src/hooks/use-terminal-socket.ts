import { useEffect, useRef } from 'react';
import type React from 'react';
import { acquireSocket, releaseSocket } from './socket.js';
import { useTerminalStore } from '../store/terminal-store.js';
import type { TerminalSession } from '@dashboard/types';

const STORAGE_KEY = 'terminal:sessionIds';

function getStoredSessionIds(): string[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch (err) {
    console.warn('[terminal] Failed to read stored session IDs:', err);
    return [];
  }
}

function persistSessionIds(sessions: Map<string, TerminalSession>): void {
  try {
    const ids = [...sessions.keys()];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(ids));
  } catch (err) {
    console.warn('[terminal] Failed to persist session IDs:', err);
  }
}

export function useTerminalSocket(): React.RefObject<ReturnType<typeof acquireSocket> | null> {
  const socketRef = useRef<ReturnType<typeof acquireSocket> | null>(null);

  useEffect(() => {
    socketRef.current = acquireSocket();
    const socket = socketRef.current;
    const store = useTerminalStore.getState();

    const onSessions = (event: { sessions: TerminalSession[] }) => {
      store.setSessions(event.sessions);
      persistSessionIds(useTerminalStore.getState().sessions);
    };

    const onOpened = (event: { session: TerminalSession }) => {
      store.addSession(event.session);
      persistSessionIds(useTerminalStore.getState().sessions);
    };

    const onClosed = (event: { sessionId: string }) => {
      store.removeSession(event.sessionId);
      persistSessionIds(useTerminalStore.getState().sessions);
    };

    let errorTimer: ReturnType<typeof setTimeout> | null = null;
    const onError = (event: { sessionId?: string; message: string }) => {
      console.error('[terminal]', event.message);
      useTerminalStore.getState().setError(event.message);
      if (errorTimer) clearTimeout(errorTimer);
      errorTimer = setTimeout(() => useTerminalStore.getState().clearError(), 5000);
    };

    socket.on('terminal:sessions', onSessions);
    socket.on('terminal:opened', onOpened);
    socket.on('terminal:closed', onClosed);
    socket.on('terminal:error', onError);

    const onConnect = () => {
      const sessionIds = getStoredSessionIds();
      if (sessionIds.length > 0) {
        socket.emit('terminal:reconnect', { sessionIds });
      }
    };
    socket.on('connect', onConnect);

    return () => {
      socket.off('terminal:sessions', onSessions);
      socket.off('terminal:opened', onOpened);
      socket.off('terminal:closed', onClosed);
      socket.off('terminal:error', onError);
      socket.off('connect', onConnect);
      releaseSocket();
    };
  }, []);

  return socketRef;
}
