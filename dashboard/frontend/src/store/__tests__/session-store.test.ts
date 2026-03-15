import { describe, it, expect, beforeEach } from 'vitest';
import { useSessionStore } from '../session-store.js';
import type { Session } from '@dashboard/types';

function makeSession(overrides: Partial<Session>): Session {
  return {
    id: '1', pid: 1, projectName: 'test', projectDir: '/tmp',
    gitBranch: null, model: 'Opus 4.6', costUsd: 0, tokensIn: 0, tokensOut: 0,
    memKb: 0, tmux: { session: '0', window: '0', windowName: 'test', pane: '0', tty: '' },
    status: 'idle', startedAt: Date.now(), lastHeartbeat: Date.now(),
    taskInfo: { taskSubject: 'Fix auth bug' },
    currentActivity: { type: 'idle', since: Date.now() },
    recentActivity: [], dataSource: 'polling',
    ...overrides,
  };
}

describe('useSessionStore', () => {
  beforeEach(() => {
    useSessionStore.getState().setSnapshot([]);
  });

  it('setSnapshot replaces all sessions', () => {
    const { setSnapshot } = useSessionStore.getState();
    setSnapshot([makeSession({ id: '1' }), makeSession({ id: '2' })]);
    expect(useSessionStore.getState().sessions.size).toBe(2);
  });

  it('updateSession adds or updates a single session', () => {
    const { setSnapshot, updateSession } = useSessionStore.getState();
    setSnapshot([makeSession({ id: '1', costUsd: 10 })]);
    updateSession(makeSession({ id: '1', costUsd: 20 }));
    expect(useSessionStore.getState().sessions.get('1')?.costUsd).toBe(20);
  });

  it('removeSession deletes a session', () => {
    const { setSnapshot, removeSession } = useSessionStore.getState();
    setSnapshot([makeSession({ id: '1' })]);
    removeSession('1');
    expect(useSessionStore.getState().sessions.size).toBe(0);
  });

  it('setFilter updates filter state', () => {
    const { setFilter } = useSessionStore.getState();
    setFilter({ search: 'test', status: 'working' });
    const { filter } = useSessionStore.getState();
    expect(filter.search).toBe('test');
    expect(filter.status).toBe('working');
  });
});
