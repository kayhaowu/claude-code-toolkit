import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { EventEmitter } from 'node:events';
import { useSessionStore } from '../../store/session-store.js';
import type { Session } from '@dashboard/types';

// ---------------------------------------------------------------------------
// Mock socket module — must be called before static imports of the module
// that depends on it. Vitest hoists vi.mock() calls to the top of the file.
// ---------------------------------------------------------------------------

let mockSocket: EventEmitter & {
  emit: (...args: any[]) => boolean;
  off: (event: string, listener?: (...args: any[]) => void) => any;
};

vi.mock('../socket.js', () => ({
  acquireSocket: vi.fn(() => mockSocket),
  releaseSocket: vi.fn(),
}));

import { useSocket } from '../use-socket.js';
import { acquireSocket, releaseSocket } from '../socket.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    id: '1',
    pid: 1,
    projectName: 'test-project',
    projectDir: '/tmp/test',
    gitBranch: 'main',
    model: 'Opus 4.6',
    costUsd: 0,
    tokensIn: 0,
    tokensOut: 0,
    memKb: 0,
    tmux: { session: '0', window: '0', windowName: 'test', pane: '0', tty: '' },
    status: 'idle',
    startedAt: Date.now(),
    lastHeartbeat: Date.now(),
    taskInfo: { taskSubject: 'Test task' },
    currentActivity: { type: 'idle', since: Date.now() },
    recentActivity: [],
    dataSource: 'polling',
    ...overrides,
  } as Session;
}

function resetStore() {
  useSessionStore.getState().setSnapshot([]);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('useSocket', () => {
  beforeEach(() => {
    // Fresh mock socket for each test
    mockSocket = new EventEmitter() as any;

    // Reset store
    resetStore();

    // Reset module mocks
    vi.clearAllMocks();
    (acquireSocket as ReturnType<typeof vi.fn>).mockReturnValue(mockSocket);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('acquires the socket on mount and releases on unmount', () => {
    const { unmount } = renderHook(() => useSocket());

    expect(acquireSocket).toHaveBeenCalledOnce();
    unmount();
    expect(releaseSocket).toHaveBeenCalledOnce();
  });

  it('sessions:snapshot event calls setSnapshot with sessions', () => {
    const session1 = makeSession({ id: '1' });
    const session2 = makeSession({ id: '2' });

    renderHook(() => useSocket());

    act(() => {
      mockSocket.emit('sessions:snapshot', { type: 'sessions:snapshot', sessions: [session1, session2] });
    });

    const { sessions } = useSessionStore.getState();
    expect(sessions.size).toBe(2);
    expect(sessions.get('1')).toEqual(session1);
    expect(sessions.get('2')).toEqual(session2);
  });

  it('session:updated event calls updateSession', () => {
    const session = makeSession({ id: '1', costUsd: 10 });
    useSessionStore.getState().setSnapshot([session]);

    renderHook(() => useSocket());

    const updated = makeSession({ id: '1', costUsd: 99 });
    act(() => {
      mockSocket.emit('session:updated', { type: 'session:updated', session: updated });
    });

    expect(useSessionStore.getState().sessions.get('1')?.costUsd).toBe(99);
  });

  it('session:removed event calls removeSession', () => {
    const session = makeSession({ id: '1' });
    useSessionStore.getState().setSnapshot([session]);

    renderHook(() => useSocket());

    act(() => {
      mockSocket.emit('session:removed', { type: 'session:removed', id: '1' });
    });

    expect(useSessionStore.getState().sessions.has('1')).toBe(false);
  });

  it('cleanup calls socket.off for all 3 events and releaseSocket on unmount', () => {
    const offSpy = vi.spyOn(mockSocket, 'off');

    const { unmount } = renderHook(() => useSocket());

    unmount();

    const removedEvents = offSpy.mock.calls.map((c: unknown[]) => c[0]);
    expect(removedEvents).toContain('sessions:snapshot');
    expect(removedEvents).toContain('session:updated');
    expect(removedEvents).toContain('session:removed');
    expect(releaseSocket).toHaveBeenCalledOnce();
  });
});
