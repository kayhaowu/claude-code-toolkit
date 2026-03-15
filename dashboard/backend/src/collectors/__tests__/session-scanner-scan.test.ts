import { describe, it, expect, vi } from 'vitest';
import { scanSessions } from '../session-scanner.ts';

describe('scanSessions', () => {
  it('returns AgentSession array from file system data', async () => {
    const mockDeps = {
      listSessionFiles: vi.fn().mockResolvedValue(['446521.json']),
      readJson: vi.fn().mockImplementation((path: string) => {
        if (path.endsWith('446521.json')) {
          return Promise.resolve({
            pid: 446521, epoch: 1773126970, model: 'Opus 4.6',
            project_dir: '/home/sonic/test', project_name: 'test',
            git_branch: 'main', status: 'idle',
            tokens_in: 100, tokens_out: 200, mem_kb: 50000, cost_usd: 1.5,
          });
        }
        if (path.endsWith('446521.hb.dat')) {
          return Promise.resolve({ heartbeat_at: 1773129523, mem_kb: 50000, status: 'working' });
        }
        return Promise.reject(new Error('not found'));
      }),
      isProcessAlive: vi.fn().mockReturnValue(true),
      getTmuxMap: vi.fn().mockResolvedValue(new Map([
        ['/dev/pts/6', { session: '0', window: '0', windowName: 'test', pane: '0', tty: '/dev/pts/6' }],
      ])),
      readPidTty: vi.fn().mockResolvedValue('/dev/pts/6'),
    };

    const sessions = await scanSessions(mockDeps);
    expect(sessions).toHaveLength(1);
    expect(sessions[0].pid).toBe(446521);
    expect(sessions[0].status).toBe('working');
    expect(sessions[0].tmux.windowName).toBe('test');
  });

  it('marks session as stopped when process is dead', async () => {
    const mockDeps = {
      listSessionFiles: vi.fn().mockResolvedValue(['99999.json']),
      readJson: vi.fn().mockImplementation((path: string) => {
        if (path.endsWith('99999.json')) {
          return Promise.resolve({
            pid: 99999, epoch: 1773126970, model: 'Opus 4.6',
            project_dir: '/tmp/dead', project_name: 'dead',
            git_branch: '', status: 'idle',
            tokens_in: 0, tokens_out: 0, mem_kb: 0, cost_usd: 0,
          });
        }
        return Promise.reject(new Error('not found'));
      }),
      isProcessAlive: vi.fn().mockReturnValue(false),
      getTmuxMap: vi.fn().mockResolvedValue(new Map()),
      readPidTty: vi.fn().mockResolvedValue(null),
    };

    const sessions = await scanSessions(mockDeps);
    expect(sessions).toHaveLength(1);
    expect(sessions[0].status).toBe('stopped');
  });
});
