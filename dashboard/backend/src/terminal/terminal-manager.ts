import { EventEmitter } from 'events';
import { execFileSync } from 'child_process';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { homedir } from 'node:os';
import * as pty from 'node-pty';
import type { TerminalSession, TerminalOpenPayload } from '../types/index.ts';
import type { SessionStore } from '../store/session-store.ts';

interface SessionEntry {
  pty: pty.IPty;
  meta: TerminalSession;
  socketId: string;
  lingerTimer?: NodeJS.Timeout;
  groupedSessionName?: string;
}

function generateId(): string {
  return `term-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export class TerminalManager extends EventEmitter {
  private sessions = new Map<string, SessionEntry>();

  constructor(private sessionStore: SessionStore) {
    super();
  }

  async open(socketId: string, payload: TerminalOpenPayload): Promise<TerminalSession> {
    if (payload.mode === 'attach') {
      return this.openAttach(socketId, payload.sessionPid);
    }
    return this.openNew(socketId, payload.cwd);
  }

  private openAttach(socketId: string, sessionPid: number): TerminalSession {
    const session = this.sessionStore.get(String(sessionPid));
    if (!session) throw new Error(`Session ${sessionPid} not found`);
    if (!session.tmux) throw new Error(`Session ${sessionPid} has no tmux session`);

    const tmuxTarget = `${session.tmux.session}:${session.tmux.window}.${session.tmux.pane}`;
    const id = generateId();
    const title = `session-${sessionPid}`;
    const groupedSessionName = `claude-view-${id}`;

    // Create a grouped session so each viewer gets an independent view
    // of the session's tmux session without stealing focus.
    try {
      execFileSync('tmux', [
        'new-session', '-d', '-s', groupedSessionName, '-t', session.tmux.session,
      ]);
    } catch (err: any) {
      if (err.code === 'ENOENT') {
        throw new Error('tmux is not installed. Please install tmux to use web terminals.');
      }
      throw new Error(`Failed to create grouped tmux session: ${err.message}`);
    }

    // Select the specific window and pane the session is running in.
    // Without this, the grouped session defaults to whichever window/pane
    // was last active — all sessions in the same session would show the same view.
    try {
      execFileSync('tmux', ['select-window', '-t', `${groupedSessionName}:${session.tmux.window}`]);
      execFileSync('tmux', ['select-pane', '-t', `${groupedSessionName}:${session.tmux.window}.${session.tmux.pane}`]);
    } catch (err: any) {
      // Rollback: destroy the grouped session we just created
      this.cleanupGroupedSession(groupedSessionName);
      throw new Error(`Failed to select pane ${session.tmux.window}.${session.tmux.pane}: ${err.message}`);
    }

    const proc = pty.spawn('tmux', ['-T', '256,RGB,mouse,title', 'attach-session', '-t', groupedSessionName], {
      name: 'xterm-256color',
      cols: 80,
      rows: 24,
      env: {
        ...process.env,
        COLORTERM: 'truecolor',
      },
    });

    const meta: TerminalSession = {
      id,
      tmuxTarget,
      mode: 'attach',
      sessionPid,
      title,
      status: 'connected',
      createdAt: Date.now(),
    };

    proc.onData((data: string) => {
      const current = this.sessions.get(id);
      if (current) {
        this.emit('output', { sessionId: id, socketId: current.socketId, data: Buffer.from(data) });
      }
    });

    proc.onExit(({ exitCode }) => {
      const current = this.sessions.get(id);
      if (current) {
        this.sessions.delete(id);
        this.cleanupGroupedSession(current.groupedSessionName);
        this.emit('exited', { sessionId: id, socketId: current.socketId, exitCode });
      }
    });

    this.sessions.set(id, { pty: proc, meta, socketId, groupedSessionName });
    return meta;
  }

  private openNew(socketId: string, cwd?: string): TerminalSession {
    const id = generateId();
    const tmuxSessionName = `claude-web-${id}`;

    const args = ['new-session', '-d', '-s', tmuxSessionName];
    if (cwd) {
      const resolved = resolve(cwd);
      const home = homedir();
      const homePrefix = home.endsWith('/') ? home : home + '/';
      if (resolved !== home && !resolved.startsWith(homePrefix) && resolved !== '/tmp' && !resolved.startsWith('/tmp/') && resolved !== '/private/tmp' && !resolved.startsWith('/private/tmp/')) {
        throw new Error(`cwd must be under home directory or /tmp: ${resolved}`);
      }
      if (!existsSync(resolved)) {
        throw new Error(`cwd does not exist: ${resolved}`);
      }
      args.push('-c', resolved);
    }

    try {
      execFileSync('tmux', args);
    } catch (err: any) {
      if (err.code === 'ENOENT') {
        throw new Error('tmux is not installed. Please install tmux to use web terminals.');
      }
      throw new Error(`Failed to create tmux session: ${err.message}`);
    }

    const proc = pty.spawn('tmux', ['-T', '256,RGB,mouse,title', 'attach-session', '-t', tmuxSessionName], {
      name: 'xterm-256color',
      cols: 80,
      rows: 24,
      env: {
        ...process.env,
        COLORTERM: 'truecolor',
      },
    });

    const meta: TerminalSession = {
      id,
      tmuxTarget: tmuxSessionName,
      mode: 'new',
      sessionPid: null,
      title: `shell-${id.slice(-4)}`,
      status: 'connected',
      createdAt: Date.now(),
    };

    proc.onData((data: string) => {
      const current = this.sessions.get(id);
      if (current) {
        this.emit('output', { sessionId: id, socketId: current.socketId, data: Buffer.from(data) });
      }
    });

    proc.onExit(({ exitCode }) => {
      const current = this.sessions.get(id);
      if (current) {
        this.sessions.delete(id);
        this.emit('exited', { sessionId: id, socketId: current.socketId, exitCode });
      }
    });

    this.sessions.set(id, { pty: proc, meta, socketId });
    return meta;
  }

  write(sessionId: string, socketId: string, data: string): void {
    const entry = this.sessions.get(sessionId);
    if (!entry || entry.socketId !== socketId) return;
    entry.pty.write(data);
  }

  resize(sessionId: string, socketId: string, cols: number, rows: number): void {
    const entry = this.sessions.get(sessionId);
    if (!entry || entry.socketId !== socketId) return;
    entry.pty.resize(cols, rows);
  }

  close(sessionId: string, socketId: string): void {
    const entry = this.sessions.get(sessionId);
    if (!entry || entry.socketId !== socketId) return;
    entry.pty.kill();
    this.sessions.delete(sessionId);
    this.cleanupGroupedSession(entry.groupedSessionName);
  }

  private static LINGER_MS = 30_000;

  handleDisconnect(socketId: string): void {
    for (const entry of this.sessions.values()) {
      if (entry.socketId !== socketId) continue;
      entry.meta.status = 'disconnected';
      entry.lingerTimer = setTimeout(() => {
        if (entry.meta.status !== 'disconnected') return;
        entry.pty.kill();
        this.sessions.delete(entry.meta.id);
        this.cleanupGroupedSession(entry.groupedSessionName);
      }, TerminalManager.LINGER_MS);
    }
  }

  handleReconnect(socketId: string, sessionIds: string[]): { restored: string[]; lost: string[] } {
    const restored: string[] = [];
    const lost: string[] = [];
    for (const sessionId of sessionIds) {
      const entry = this.sessions.get(sessionId);
      if (!entry) {
        lost.push(sessionId);
        continue;
      }
      if (entry.lingerTimer) {
        clearTimeout(entry.lingerTimer);
        entry.lingerTimer = undefined;
      }
      entry.socketId = socketId;
      entry.meta.status = 'connected';
      restored.push(sessionId);
    }
    return { restored, lost };
  }

  getBySocket(socketId: string): TerminalSession[] {
    return [...this.sessions.values()]
      .filter(e => e.socketId === socketId && e.meta.status === 'connected')
      .map(e => e.meta);
  }

  stopAll(): void {
    for (const entry of this.sessions.values()) {
      entry.pty.kill();
      this.cleanupGroupedSession(entry.groupedSessionName);
    }
    this.sessions.clear();
  }

  private cleanupGroupedSession(sessionName?: string): void {
    if (!sessionName) return;
    try {
      execFileSync('tmux', ['kill-session', '-t', sessionName]);
    } catch (err: any) {
      const msg = err.stderr?.toString?.() ?? err.message ?? '';
      if (!msg.includes('session not found') && !msg.includes('no server running')) {
        console.error(`[terminal] failed to cleanup grouped session ${sessionName}:`, msg);
      }
    }
  }
}
