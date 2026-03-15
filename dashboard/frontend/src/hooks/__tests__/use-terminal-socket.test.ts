import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { EventEmitter } from 'node:events';
import { useTerminalStore } from '../../store/terminal-store.js';
import type { TerminalSession } from '@dashboard/types';

// ---------------------------------------------------------------------------
// Mock socket module — must be called before static imports of the module
// that depends on it. Vitest hoists vi.mock() calls to the top of the file.
// ---------------------------------------------------------------------------

let mockSocket: EventEmitter & {
  emit: (...args: any[]) => boolean;
  off: (event: string, listener: (...args: any[]) => void) => any;
};

vi.mock('../socket.js', () => ({
  acquireSocket: vi.fn(() => mockSocket),
  releaseSocket: vi.fn(),
}));

import { useTerminalSocket } from '../use-terminal-socket.js';
import { acquireSocket, releaseSocket } from '../socket.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const STORAGE_KEY = 'terminal:sessionIds';

function makeSession(overrides: Partial<TerminalSession> = {}): TerminalSession {
  return {
    id: 'term-1',
    mode: 'new',
    sessionPid: null,
    tmuxTarget: 'claude-web-term-1',
    title: 'shell-1',
    status: 'connected',
    createdAt: Date.now(),
    ...overrides,
  } as TerminalSession;
}

function resetStore() {
  useTerminalStore.setState({
    sessions: new Map(),
    layout: null,
    activePaneId: null,
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('useTerminalSocket', () => {
  beforeEach(() => {
    // Fresh mock socket for each test
    mockSocket = new EventEmitter() as any;

    // Reset store
    resetStore();

    // Reset localStorage
    localStorage.clear();

    // Reset module mocks (re-point acquireSocket to the new mockSocket)
    vi.clearAllMocks();
    (acquireSocket as ReturnType<typeof vi.fn>).mockReturnValue(mockSocket);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('acquires the socket on mount and releases on unmount', () => {
    const { unmount } = renderHook(() => useTerminalSocket());

    expect(acquireSocket).toHaveBeenCalledOnce();
    unmount();
    expect(releaseSocket).toHaveBeenCalledOnce();
  });

  it('terminal:sessions event calls store.setSessions() with correct data', () => {
    const session1 = makeSession({ id: 'term-1' });
    const session2 = makeSession({ id: 'term-2' });

    renderHook(() => useTerminalSocket());

    act(() => {
      mockSocket.emit('terminal:sessions', { sessions: [session1, session2] });
    });

    const { sessions } = useTerminalStore.getState();
    expect(sessions.size).toBe(2);
    expect(sessions.get('term-1')).toEqual(session1);
    expect(sessions.get('term-2')).toEqual(session2);
  });

  it('terminal:sessions event persists session IDs to localStorage', () => {
    const session1 = makeSession({ id: 'term-1' });
    const session2 = makeSession({ id: 'term-2' });

    renderHook(() => useTerminalSocket());

    act(() => {
      mockSocket.emit('terminal:sessions', { sessions: [session1, session2] });
    });

    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY)!);
    expect(stored).toContain('term-1');
    expect(stored).toContain('term-2');
  });

  it('terminal:opened event calls store.addSession() and persists to localStorage', () => {
    const session = makeSession({ id: 'term-open-1' });

    renderHook(() => useTerminalSocket());

    act(() => {
      mockSocket.emit('terminal:opened', { session });
    });

    const { sessions } = useTerminalStore.getState();
    expect(sessions.get('term-open-1')).toEqual(session);

    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY)!);
    expect(stored).toContain('term-open-1');
  });

  it('terminal:closed event calls store.removeSession() and persists to localStorage', () => {
    // Pre-populate the store with a session
    const session = makeSession({ id: 'term-close-1' });
    useTerminalStore.getState().addSession(session);

    renderHook(() => useTerminalSocket());

    act(() => {
      mockSocket.emit('terminal:closed', { sessionId: 'term-close-1' });
    });

    const { sessions } = useTerminalStore.getState();
    expect(sessions.has('term-close-1')).toBe(false);

    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]');
    expect(stored).not.toContain('term-close-1');
  });

  it('connect event with stored session IDs emits terminal:reconnect', () => {
    // Pre-store session IDs in localStorage
    localStorage.setItem(STORAGE_KEY, JSON.stringify(['term-a', 'term-b']));

    // Spy on socket.emit
    const emitSpy = vi.spyOn(mockSocket, 'emit');

    renderHook(() => useTerminalSocket());

    act(() => {
      mockSocket.emit('connect');
    });

    // emitSpy records the 'connect' emit too; find 'terminal:reconnect'
    const reconnectCall = emitSpy.mock.calls.find((c: unknown[]) => c[0] === 'terminal:reconnect');
    expect(reconnectCall).toBeDefined();
    expect(reconnectCall![1]).toEqual({ sessionIds: ['term-a', 'term-b'] });
  });

  it('connect event with no stored session IDs does NOT emit terminal:reconnect', () => {
    const emitSpy = vi.spyOn(mockSocket, 'emit');

    renderHook(() => useTerminalSocket());

    act(() => {
      mockSocket.emit('connect');
    });

    const reconnectCall = emitSpy.mock.calls.find((c: unknown[]) => c[0] === 'terminal:reconnect');
    expect(reconnectCall).toBeUndefined();
  });

  it('cleanup unregisters all socket listeners on unmount', () => {
    const offSpy = vi.spyOn(mockSocket, 'off');

    const { unmount } = renderHook(() => useTerminalSocket());

    unmount();

    const removedEvents = offSpy.mock.calls.map((c: unknown[]) => c[0]);
    expect(removedEvents).toContain('terminal:sessions');
    expect(removedEvents).toContain('terminal:opened');
    expect(removedEvents).toContain('terminal:closed');
    expect(removedEvents).toContain('terminal:error');
    expect(removedEvents).toContain('connect');
  });

  it('returns a socketRef whose current is set after mount', () => {
    const { result } = renderHook(() => useTerminalSocket());

    // After useEffect runs, socketRef.current should be the mock socket
    expect(result.current.current).toBe(mockSocket);
  });
});
