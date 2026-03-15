import { io, type Socket } from 'socket.io-client';

let socket: Socket | null = null;
let refCount = 0;

export function acquireSocket(): Socket {
  if (!socket) {
    socket = io({ transports: ['websocket'] });
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
