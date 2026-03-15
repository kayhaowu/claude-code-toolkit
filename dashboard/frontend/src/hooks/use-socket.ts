import { useEffect } from 'react';
import { acquireSocket, releaseSocket } from './socket.js';
import { useSessionStore } from '../store/session-store.js';
import type { WSEvent } from '@dashboard/types';

export function useSocket() {
  const { setSnapshot, updateSession, removeSession } = useSessionStore();

  useEffect(() => {
    const socket = acquireSocket();

    const onSnapshot = (event: WSEvent & { type: 'sessions:snapshot' }) => {
      setSnapshot(event.sessions);
    };
    const onUpdated = (event: WSEvent & { type: 'session:updated' }) => {
      updateSession(event.session);
    };
    const onRemoved = (event: WSEvent & { type: 'session:removed' }) => {
      removeSession(event.id);
    };

    socket.on('sessions:snapshot', onSnapshot);
    socket.on('session:updated', onUpdated);
    socket.on('session:removed', onRemoved);

    return () => {
      socket.off('sessions:snapshot', onSnapshot);
      socket.off('session:updated', onUpdated);
      socket.off('session:removed', onRemoved);
      releaseSocket();
    };
  }, [setSnapshot, updateSession, removeSession]);
}
