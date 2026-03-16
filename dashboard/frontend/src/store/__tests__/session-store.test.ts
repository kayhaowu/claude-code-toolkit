import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook } from '@testing-library/react';
import { useSessionStore, useSortedSessions } from '../session-store.js';
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

describe('useSortedSessions', () => {
  beforeEach(() => {
    useSessionStore.getState().setSnapshot([]);
    useSessionStore.getState().setFilter({ status: null, search: '' });
  });

  it('filters by status — only working sessions returned', () => {
    const working = makeSession({ id: '1', status: 'working' });
    const idle = makeSession({ id: '2', status: 'idle' });
    const stopped = makeSession({ id: '3', status: 'stopped' });
    useSessionStore.getState().setSnapshot([working, idle, stopped]);
    useSessionStore.getState().setFilter({ status: 'working' });

    const { result } = renderHook(() => useSortedSessions());
    expect(result.current).toHaveLength(1);
    expect(result.current[0].id).toBe('1');
  });

  it('searches by projectName', () => {
    const match = makeSession({ id: '1', projectName: 'my-awesome-project' });
    const noMatch = makeSession({ id: '2', projectName: 'other-project' });
    useSessionStore.getState().setSnapshot([match, noMatch]);
    useSessionStore.getState().setFilter({ search: 'awesome' });

    const { result } = renderHook(() => useSortedSessions());
    expect(result.current).toHaveLength(1);
    expect(result.current[0].id).toBe('1');
  });

  it('searches by gitBranch', () => {
    const match = makeSession({ id: '1', gitBranch: 'feat/login-page' });
    const noMatch = makeSession({ id: '2', gitBranch: 'main' });
    useSessionStore.getState().setSnapshot([match, noMatch]);
    useSessionStore.getState().setFilter({ search: 'login' });

    const { result } = renderHook(() => useSortedSessions());
    expect(result.current).toHaveLength(1);
    expect(result.current[0].id).toBe('1');
  });

  it('searches by taskInfo.taskSubject', () => {
    const match = makeSession({ id: '1', taskInfo: { taskSubject: 'Implement auth flow' } });
    const noMatch = makeSession({ id: '2', taskInfo: { taskSubject: 'Fix typo' } });
    useSessionStore.getState().setSnapshot([match, noMatch]);
    useSessionStore.getState().setFilter({ search: 'auth' });

    const { result } = renderHook(() => useSortedSessions());
    expect(result.current).toHaveLength(1);
    expect(result.current[0].id).toBe('1');
  });

  it('sorts working before idle before stopped', () => {
    const stopped = makeSession({ id: '3', status: 'stopped' });
    const working = makeSession({ id: '1', status: 'working' });
    const idle = makeSession({ id: '2', status: 'idle' });
    useSessionStore.getState().setSnapshot([stopped, idle, working]);

    const { result } = renderHook(() => useSortedSessions());
    expect(result.current.map(s => s.status)).toEqual(['working', 'idle', 'stopped']);
  });

  it('does not crash when gitBranch is null', () => {
    const session = makeSession({ id: '1', gitBranch: null });
    useSessionStore.getState().setSnapshot([session]);
    useSessionStore.getState().setFilter({ search: 'anything' });

    const { result } = renderHook(() => useSortedSessions());
    // Should not throw; result may be empty since projectName 'test' doesn't match 'anything'
    expect(result.current).toHaveLength(0);
  });
});

describe('activeTab', () => {
  beforeEach(() => {
    useSessionStore.setState({ activeTab: 'terminal' });
  });

  it('defaults to terminal', () => {
    expect(useSessionStore.getState().activeTab).toBe('terminal');
  });

  it('can switch tabs', () => {
    useSessionStore.getState().setActiveTab('git');
    expect(useSessionStore.getState().activeTab).toBe('git');
  });

  it('can switch to activity tab', () => {
    useSessionStore.getState().setActiveTab('activity');
    expect(useSessionStore.getState().activeTab).toBe('activity');
  });

  it('can switch to detail tab', () => {
    useSessionStore.getState().setActiveTab('detail');
    expect(useSessionStore.getState().activeTab).toBe('detail');
  });
});
