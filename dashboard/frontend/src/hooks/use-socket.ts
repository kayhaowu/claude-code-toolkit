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
