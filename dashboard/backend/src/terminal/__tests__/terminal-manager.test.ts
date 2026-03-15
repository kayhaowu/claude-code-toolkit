import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { EventEmitter } from 'events';
import { TerminalManager } from '../terminal-manager.js';

// Mock node-pty
vi.mock('node-pty', () => ({
  spawn: vi.fn(() => {
    const pty = new EventEmitter() as any;
    pty.write = vi.fn();
    pty.resize = vi.fn();
    pty.kill = vi.fn();
    pty.pid = 9999;
    pty.onData = (cb: (data: string) => void) => {
      pty.on('data', cb);
      return { dispose: () => pty.removeListener('data', cb) };
    };
    pty.onExit = (cb: (e: { exitCode: number }) => void) => {
      pty.on('exit', cb);
      return { dispose: () => pty.removeListener('exit', cb) };
    };
    return pty;
  }),
}));

vi.mock('child_process', () => ({
  execFileSync: vi.fn(),
}));

function makeSessionStore(sessions: Record<number, { tmux?: { session: string; window: string; pane: string } }> = {}) {
  return {
    get(id: string) {
      const pid = Number(id);
      const session = sessions[pid];
      if (!session) return undefined;
      return { pid, tmux: session.tmux };
    },
    getAll() {
      return Object.entries(sessions).map(([pid, s]) => ({ pid: Number(pid), ...s }));
    },
  } as any;
}

describe('TerminalManager', () => {
  let manager: TerminalManager;

  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('open() — attach mode', () => {
    it('creates a grouped tmux session and attaches to it', async () => {
      const store = makeSessionStore({
        1234: { tmux: { session: 'main', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1234 });

      expect(session.mode).toBe('attach');
      expect(session.sessionPid).toBe(1234);
      expect(session.tmuxTarget).toBe('main:0.0');
      expect(session.status).toBe('connected');
      expect(session.id).toMatch(/^term-/);

      // Verify grouped session was created via execFileSync
      const cp = await import('child_process');
      const calls = (cp.execFileSync as any).mock.calls;
      const groupCall = calls.find(
        (c: any[]) => c[0] === 'tmux' && c[1][0] === 'new-session' && c[1].includes('-t'),
      );
      expect(groupCall).toBeDefined();
      // The grouped session name should follow claude-view-<id> pattern
      const sFlag = groupCall[1].indexOf('-s');
      const groupedName = groupCall[1][sFlag + 1];
      expect(groupedName).toMatch(/^claude-view-term-/);
      // The -t flag should point to the session's tmux session name
      const tFlag = groupCall[1].indexOf('-t');
      expect(groupCall[1][tFlag + 1]).toBe('main');

      // Verify pty.spawn attaches to the grouped session, not the original
      const nodePty = await import('node-pty');
      const spawnCall = (nodePty.spawn as any).mock.calls.at(-1);
      expect(spawnCall[1]).toContain(groupedName);
    });

    it('throws when session not found', async () => {
      const store = makeSessionStore({});
      manager = new TerminalManager(store);
      await expect(manager.open('socket-1', { mode: 'attach', sessionPid: 9999 }))
        .rejects.toThrow('Session 9999 not found');
    });

    it('throws when session has no tmux info', async () => {
      const store = makeSessionStore({ 1234: {} });
      manager = new TerminalManager(store);
      await expect(manager.open('socket-1', { mode: 'attach', sessionPid: 1234 }))
        .rejects.toThrow('Session 1234 has no tmux session');
    });

    it('selects the correct window and pane in the grouped session', async () => {
      const cp = await import('child_process');
      (cp.execFileSync as any).mockClear();

      const store = makeSessionStore({
        1234: { tmux: { session: 'main', window: '2', pane: '3' } },
      });
      manager = new TerminalManager(store);
      await manager.open('socket-1', { mode: 'attach', sessionPid: 1234 });

      const calls = (cp.execFileSync as any).mock.calls;

      // Find select-window call
      const selectWindowCall = calls.find(
        (c: any[]) => c[0] === 'tmux' && c[1][0] === 'select-window',
      );
      expect(selectWindowCall).toBeDefined();
      expect(selectWindowCall[1][2]).toMatch(/^claude-view-term-.*:2$/);

      // Find select-pane call
      const selectPaneCall = calls.find(
        (c: any[]) => c[0] === 'tmux' && c[1][0] === 'select-pane',
      );
      expect(selectPaneCall).toBeDefined();
      expect(selectPaneCall[1][2]).toMatch(/^claude-view-term-.*:2\.3$/);
    });

    it('rolls back grouped session if select-window fails', async () => {
      const cp = await import('child_process');
      (cp.execFileSync as any)
        .mockImplementationOnce(() => {}) // new-session succeeds
        .mockImplementationOnce(() => { throw new Error('window not found'); }); // select-window fails
      const store = makeSessionStore({
        1234: { tmux: { session: 'main', window: '2', pane: '1' } },
      });
      manager = new TerminalManager(store);
      await expect(manager.open('socket-1', { mode: 'attach', sessionPid: 1234 }))
        .rejects.toThrow('Failed to select pane 2.1');
      expect(manager.getBySocket('socket-1')).toHaveLength(0);

      // Verify cleanup was attempted (kill-session for the grouped session)
      const killCall = (cp.execFileSync as any).mock.calls.find(
        (c: any[]) => c[0] === 'tmux' && c[1][0] === 'kill-session',
      );
      expect(killCall).toBeDefined();
    });

    it('rolls back on execFileSync failure for grouped session', async () => {
      const cp = await import('child_process');
      (cp.execFileSync as any).mockImplementationOnce(() => {
        throw new Error('duplicate session');
      });
      const store = makeSessionStore({
        1234: { tmux: { session: 'main', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      await expect(manager.open('socket-1', { mode: 'attach', sessionPid: 1234 }))
        .rejects.toThrow('Failed to create grouped tmux session: duplicate session');
      // No session should have been registered
      expect(manager.getBySocket('socket-1')).toHaveLength(0);
    });
  });

  describe('open() — new mode', () => {
    it('creates a new tmux session and attaches', async () => {
      const store = makeSessionStore({});
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'new' });

      expect(session.mode).toBe('new');
      expect(session.sessionPid).toBeNull();
      expect(session.tmuxTarget).toMatch(/^claude-web-/);
      expect(session.status).toBe('connected');
      expect(session.title).toMatch(/^shell-/);
    });
  });

  describe('write()', () => {
    it('writes data to the PTY', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      manager.write(session.id, 'socket-1', 'hello');

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.write).toHaveBeenCalledWith('hello');
    });

    it('ignores writes to unknown sessions', () => {
      const store = makeSessionStore({});
      manager = new TerminalManager(store);
      expect(() => manager.write('nonexistent', 'socket-1', 'data')).not.toThrow();
    });

    it('ignores writes from a socket that does not own the session', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      manager.write(session.id, 'socket-evil', 'hack');

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.write).not.toHaveBeenCalled();
    });
  });

  describe('resize()', () => {
    it('resizes the PTY', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      manager.resize(session.id, 'socket-1', 120, 40);

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.resize).toHaveBeenCalledWith(120, 40);
    });

    it('ignores resize from a socket that does not own the session', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      manager.resize(session.id, 'socket-evil', 120, 40);

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.resize).not.toHaveBeenCalled();
    });
  });

  describe('close()', () => {
    it('kills the PTY, removes session, and cleans up grouped tmux session', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      const cp = await import('child_process');
      (cp.execFileSync as any).mockClear();

      manager.close(session.id, 'socket-1');

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.kill).toHaveBeenCalled();
      expect(manager.getBySocket('socket-1')).toHaveLength(0);

      // Verify grouped session cleanup via tmux kill-session
      const killCall = (cp.execFileSync as any).mock.calls.find(
        (c: any[]) => c[0] === 'tmux' && c[1][0] === 'kill-session',
      );
      expect(killCall).toBeDefined();
      expect(killCall[1][2]).toMatch(/^claude-view-term-/);
    });

    it('does not attempt grouped session cleanup for new-mode sessions', async () => {
      const store = makeSessionStore({});
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'new' });

      const cp = await import('child_process');
      (cp.execFileSync as any).mockClear();

      manager.close(session.id, 'socket-1');

      // Should not have called kill-session since there's no grouped session
      const killCall = (cp.execFileSync as any).mock.calls.find(
        (c: any[]) => c[0] === 'tmux' && c[1][0] === 'kill-session',
      );
      expect(killCall).toBeUndefined();
    });

    it('ignores close from a socket that does not own the session', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      manager.close(session.id, 'socket-evil');

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.kill).not.toHaveBeenCalled();
      expect(manager.getBySocket('socket-1')).toHaveLength(1);
    });
  });

  describe('handleDisconnect()', () => {
    it('starts linger timer and kills PTY after 30s', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      manager.handleDisconnect('socket-1');
      expect(manager.getBySocket('socket-1')).toHaveLength(0); // disconnected sessions excluded

      vi.advanceTimersByTime(30_000);

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.kill).toHaveBeenCalled();
    });

    it('does not kill PTY before 30s', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      manager.handleDisconnect('socket-1');
      vi.advanceTimersByTime(29_000);

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.kill).not.toHaveBeenCalled();
    });
  });

  describe('handleReconnect()', () => {
    it('cancels linger timer and rebinds socket', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      manager.handleDisconnect('socket-1');
      const result = manager.handleReconnect('socket-2', [session.id]);

      expect(result.restored).toContain(session.id);
      expect(result.lost).toHaveLength(0);
      expect(manager.getBySocket('socket-2')).toHaveLength(1);
      expect(manager.getBySocket('socket-2')[0].id).toBe(session.id);

      // Advancing past 30s should NOT kill PTY
      vi.advanceTimersByTime(30_000);
      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      expect(mockPty.kill).not.toHaveBeenCalled();
    });

    it('returns lost session IDs for unknown sessions', async () => {
      const store = makeSessionStore({});
      manager = new TerminalManager(store);
      const result = manager.handleReconnect('socket-2', ['unknown-id']);
      expect(result.lost).toContain('unknown-id');
      expect(result.restored).toHaveLength(0);
      expect(manager.getBySocket('socket-2')).toHaveLength(0);
    });

    it('ignores unknown session IDs without throwing', async () => {
      const store = makeSessionStore({});
      manager = new TerminalManager(store);
      expect(() => manager.handleReconnect('socket-2', ['unknown-id'])).not.toThrow();
      expect(manager.getBySocket('socket-2')).toHaveLength(0);
    });
  });

  describe('getBySocket()', () => {
    it('returns only connected sessions for the given socket', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
        2: { tmux: { session: 's', window: '0', pane: '1' } },
      });
      manager = new TerminalManager(store);
      await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });
      await manager.open('socket-2', { mode: 'attach', sessionPid: 2 });

      expect(manager.getBySocket('socket-1')).toHaveLength(1);
      expect(manager.getBySocket('socket-2')).toHaveLength(1);
      expect(manager.getBySocket('unknown')).toHaveLength(0);
    });
  });

  describe('stopAll()', () => {
    it('kills all PTYs and cleans up grouped tmux sessions', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
        2: { tmux: { session: 's', window: '0', pane: '1' } },
      });
      manager = new TerminalManager(store);
      await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });
      await manager.open('socket-1', { mode: 'attach', sessionPid: 2 });

      const cp = await import('child_process');
      (cp.execFileSync as any).mockClear();

      manager.stopAll();

      expect(manager.getBySocket('socket-1')).toHaveLength(0);

      // Verify grouped session cleanup was called for both sessions
      const killCalls = (cp.execFileSync as any).mock.calls.filter(
        (c: any[]) => c[0] === 'tmux' && c[1][0] === 'kill-session',
      );
      expect(killCalls).toHaveLength(2);
      for (const call of killCalls) {
        expect(call[1][2]).toMatch(/^claude-view-term-/);
      }
    });
  });

  describe('exited event', () => {
    it('emits exited with sessionId and socketId when PTY exits', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const handler = vi.fn();
      manager.on('exited', handler);

      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      mockPty.emit('exit', { exitCode: 0 });

      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({ sessionId: session.id, socketId: 'socket-1' })
      );
      expect(manager.getBySocket('socket-1')).toHaveLength(0);
    });
  });

  describe('openNew() tmux errors', () => {
    it('throws a friendly message when tmux is not installed', async () => {
      const { execFileSync } = await import('child_process');
      (execFileSync as any).mockImplementationOnce(() => {
        const err: any = new Error('tmux not found');
        err.code = 'ENOENT';
        throw err;
      });
      const store = makeSessionStore({});
      manager = new TerminalManager(store);
      await expect(manager.open('socket-1', { mode: 'new' }))
        .rejects.toThrow('tmux is not installed');
    });

    it('throws a descriptive message on other tmux failures', async () => {
      const { execFileSync } = await import('child_process');
      (execFileSync as any).mockImplementationOnce(() => {
        throw new Error('session already exists');
      });
      const store = makeSessionStore({});
      manager = new TerminalManager(store);
      await expect(manager.open('socket-1', { mode: 'new' }))
        .rejects.toThrow('Failed to create tmux session:');
    });
  });

  describe('output event', () => {
    it('emits output with sessionId, socketId, and data buffer', async () => {
      const store = makeSessionStore({
        1: { tmux: { session: 's', window: '0', pane: '0' } },
      });
      manager = new TerminalManager(store);
      const handler = vi.fn();
      manager.on('output', handler);

      const session = await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      // Trigger mock PTY data
      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      mockPty.emit('data', 'hello world');

      expect(handler).toHaveBeenCalledWith({
        sessionId: session.id,
        socketId: 'socket-1',
        data: Buffer.from('hello world'),
      });
    });
  });

  describe('PTY exit auto-cleanup', () => {
    it('removes session when PTY process exits', async () => {
      const manager = new TerminalManager(makeSessionStore({ 1: { tmux: { session: 's', window: '0', pane: '0' } } }));
      await manager.open('socket-1', { mode: 'attach', sessionPid: 1 });

      // Get the mock PTY and trigger exit
      const nodePty = await import('node-pty');
      const mockPty = (nodePty.spawn as any).mock.results.at(-1).value;
      mockPty.emit('exit', { exitCode: 0 });

      expect(manager.getBySocket('socket-1')).toEqual([]);
    });
  });

  describe('cwd forwarding', () => {
    it('passes cwd to tmux new-session command', async () => {
      const cp = await import('child_process');
      (cp.execFileSync as any).mockClear();

      const manager = new TerminalManager(makeSessionStore());
      await manager.open('socket-1', { mode: 'new', cwd: '/tmp/myproject' });

      const args = (cp.execFileSync as any).mock.calls[0];
      expect(args[1]).toContain('-c');
      expect(args[1]).toContain('/tmp/myproject');
    });
  });
});
