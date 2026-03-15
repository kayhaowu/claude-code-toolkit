import { describe, it, expect, vi } from 'vitest';
import { SessionStore } from '../session-store.ts';
import type { Session } from '../../types/index.ts';
import { PHANTOM_TTL_MS, ACTIVITY_STALENESS_MS } from '../../types/index.ts';

function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    id: '1000', pid: 1000, projectName: 'test', projectDir: '/tmp/test',
    gitBranch: null, model: 'Opus 4.6', costUsd: 0, tokensIn: 0, tokensOut: 0,
    memKb: 0, tmux: { session: '0', window: '0', windowName: 'test', pane: '0', tty: '/dev/pts/0' },
    status: 'idle', startedAt: Date.now(), lastHeartbeat: Date.now(),
    taskInfo: {},
    currentActivity: { type: 'idle', since: Date.now() },
    recentActivity: [], dataSource: 'polling',
    ...overrides,
  };
}

describe('SessionStore', () => {
  it('updates sessions and emits events for new sessions', () => {
    const store = new SessionStore();
    const handler = vi.fn();
    store.on('session:updated', handler);

    store.updateFromScan([makeSession({ id: '1000', pid: 1000 })]);
    expect(handler).toHaveBeenCalledTimes(1);
    expect(store.getAll()).toHaveLength(1);
  });

  it('emits session:removed when session disappears after phantom TTL', () => {
    const store = new SessionStore();
    const removedHandler = vi.fn();
    const updatedHandler = vi.fn();
    store.on('session:removed', removedHandler);
    store.on('session:updated', updatedHandler);

    const now = 1000000;
    store.updateFromScan([makeSession({ id: '1000' })], now);
    updatedHandler.mockClear();

    // First scan without session — marks as stopped, does NOT remove
    store.updateFromScan([], now + 1000);
    expect(removedHandler).not.toHaveBeenCalled();
    expect(store.get('1000')?.status).toBe('stopped');
    expect(updatedHandler).toHaveBeenCalledTimes(1);

    // Scan before TTL — still present
    store.updateFromScan([], now + 1000 + PHANTOM_TTL_MS - 1);
    expect(removedHandler).not.toHaveBeenCalled();
    expect(store.getAll()).toHaveLength(1);

    // Scan at TTL — removed
    store.updateFromScan([], now + 1000 + PHANTOM_TTL_MS);
    expect(removedHandler).toHaveBeenCalledWith('1000');
    expect(store.getAll()).toHaveLength(0);
  });

  it('resurrects session if it reappears before phantom TTL expires', () => {
    const store = new SessionStore();
    const removedHandler = vi.fn();
    store.on('session:removed', removedHandler);

    const now = 1000000;
    store.updateFromScan([makeSession({ id: '1000' })], now);

    // Goes missing
    store.updateFromScan([], now + 1000);
    expect(store.get('1000')?.status).toBe('stopped');

    // Reappears before TTL
    store.updateFromScan([makeSession({ id: '1000', status: 'working' })], now + 5000);
    expect(removedHandler).not.toHaveBeenCalled();
    expect(store.get('1000')?.status).toBe('working');

    // Later disappears again — TTL resets from new disappearance
    store.updateFromScan([], now + 10000);
    expect(store.get('1000')?.status).toBe('stopped');

    // Old TTL would have expired, but since it's a fresh disappearance, still present
    store.updateFromScan([], now + 10000 + PHANTOM_TTL_MS - 1);
    expect(store.getAll()).toHaveLength(1);

    // Now TTL expires from second disappearance
    store.updateFromScan([], now + 10000 + PHANTOM_TTL_MS);
    expect(removedHandler).toHaveBeenCalledWith('1000');
  });

  it('merges activity from LogTailer', () => {
    const store = new SessionStore();
    store.updateFromScan([makeSession({ id: '1000' })]);

    store.updateActivity(1000, {
      type: 'tool_use', tool: 'Edit', toolInput: 'src/index.ts',
      summary: 'Edit: src/index.ts', timestamp: Date.now(),
    });

    const session = store.get('1000');
    expect(session?.currentActivity.tool).toBe('Edit');
    expect(session?.recentActivity).toHaveLength(1);
  });

  it('caps recentActivity at MAX_RECENT_ACTIVITY', () => {
    const store = new SessionStore();
    store.updateFromScan([makeSession({ id: '1000' })]);

    for (let i = 0; i < 60; i++) {
      store.updateActivity(1000, {
        type: 'tool_use', tool: 'Bash', toolInput: `cmd-${i}`,
        summary: `Bash: cmd-${i}`, timestamp: Date.now() + i,
      });
    }

    const session = store.get('1000');
    expect(session?.recentActivity.length).toBe(50);
  });

  // ── Task 7: Staleness & merge tests ──

  it('resets stale currentActivity to idle after ACTIVITY_STALENESS_MS', () => {
    const store = new SessionStore();
    const now = 1000000;

    store.updateFromScan([makeSession({ id: '1000' })], now);

    // Set a tool_use activity
    store.updateActivity(1000, {
      type: 'tool_use', tool: 'Edit', toolInput: 'foo.ts',
      summary: 'Edit: foo.ts', timestamp: now,
    });

    expect(store.get('1000')?.currentActivity.type).toBe('tool_use');

    // Scan again within staleness window — activity preserved
    store.updateFromScan(
      [makeSession({ id: '1000' })],
      now + ACTIVITY_STALENESS_MS - 1,
    );
    expect(store.get('1000')?.currentActivity.type).toBe('tool_use');

    // Scan at staleness boundary — activity reset to idle
    store.updateFromScan(
      [makeSession({ id: '1000' })],
      now + ACTIVITY_STALENESS_MS,
    );
    expect(store.get('1000')?.currentActivity.type).toBe('idle');
  });

  it('preserves hook-sourced taskInfo over empty scanned taskInfo', () => {
    const store = new SessionStore();
    store.updateFromScan([makeSession({ id: '1000' })]);

    // Simulate hook setting taskInfo
    store.updateTaskInfo(1000, {
      taskSubject: 'Fix bug',
    });
    expect(store.get('1000')?.taskInfo.taskSubject).toBe('Fix bug');

    // Scan comes back with empty taskInfo — hook taskInfo preserved
    store.updateFromScan([makeSession({ id: '1000', taskInfo: {} })]);
    expect(store.get('1000')?.taskInfo.taskSubject).toBe('Fix bug');
  });

  it('cleans stoppedAt entries when sessions vanish from store', () => {
    const store = new SessionStore();
    const now = 1000000;

    store.updateFromScan([makeSession({ id: '1000' }), makeSession({ id: '2000', pid: 2000 })], now);

    // Both disappear
    store.updateFromScan([], now + 1000);
    expect(store.getAll()).toHaveLength(2);
    expect(store.get('1000')?.status).toBe('stopped');
    expect(store.get('2000')?.status).toBe('stopped');

    // TTL expires — both removed
    store.updateFromScan([], now + 1000 + PHANTOM_TTL_MS);
    expect(store.getAll()).toHaveLength(0);

    // Verify no leftover state by adding a new session with same id
    store.updateFromScan([makeSession({ id: '1000', status: 'working' })], now + 100000);
    expect(store.get('1000')?.status).toBe('working');

    // Disappears again — should start fresh TTL
    store.updateFromScan([], now + 100001);
    expect(store.get('1000')?.status).toBe('stopped');
    store.updateFromScan([], now + 100001 + PHANTOM_TTL_MS - 1);
    expect(store.getAll()).toHaveLength(1); // still within TTL
  });
});
