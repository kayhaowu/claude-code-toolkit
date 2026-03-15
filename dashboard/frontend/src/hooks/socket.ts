import { io, type Socket } from 'socket.io-client';
import { useConnectionStore } from '../store/connection-store.js';

let socket: Socket | null = null;
let refCount = 0;

export function acquireSocket(): Socket {
  if (!socket) {
    socket = io({ transports: ['websocket'] });
    socket.on('connect', () => {
      useConnectionStore.getState().setConnected(true);
    });
    socket.on('disconnect', () => {
      useConnectionStore.getState().setConnected(false);
    });
    socket.on('connect_error', (err) => {
      console.error('[socket] Connection error:', err.message);
      useConnectionStore.getState().setError(err.message);
    });
  }
  refCount++;
  return socket;
}

export function releaseSocket(): void {
  refCount--;
  if (refCount <= 0 && socket) {
    socket.disconnect();
    socket = null;
    refCount = 0;
  }
}
