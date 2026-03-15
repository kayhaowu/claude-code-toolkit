import { describe, it, expect } from 'vitest';
import express from 'express';
import request from 'supertest';
import { SessionStore } from '../../store/session-store.js';
import { createApiRouter } from '../routes.js';
import { createHookRouter } from '../../collectors/hook-receiver.js';
import type { Session } from '../../../../types/src/index.js';

function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    id: '1000', pid: 1000, projectName: 'test', projectDir: '/tmp/test',
    gitBranch: null, model: 'Opus 4.6', costUsd: 5.0, tokensIn: 100, tokensOut: 200,
    memKb: 50000, tmux: { session: '0', window: '0', windowName: 'test', pane: '0', tty: '/dev/pts/0' },
    status: 'working', startedAt: Date.now(), lastHeartbeat: Date.now(),
    taskInfo: {},
    currentActivity: { type: 'idle', since: Date.now() },
    recentActivity: [], dataSource: 'polling',
    ...overrides,
  };
}

describe('API routes', () => {
  const store = new SessionStore();
  const app = express();
  app.use(express.json());
  app.use('/api', createApiRouter(store));
  app.use('/api/hooks', createHookRouter(store));

  it('GET /api/sessions returns empty array when no sessions', async () => {
    const res = await request(app).get('/api/sessions');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('GET /api/sessions returns session data after scan', async () => {
    store.updateFromScan([makeSession({ id: '1000', projectName: 'my-project' })]);
    const res = await request(app).get('/api/sessions');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].projectName).toBe('my-project');
    expect(res.body[0].pid).toBe(1000);
  });

  it('POST /api/hooks/event updates session activity', async () => {
    const res = await request(app)
      .post('/api/hooks/event')
      .send({
        event: 'PostToolUse',
        pid: 1000,
        tool: 'Bash',
        input: { command: 'ls -la' },
        timestamp: Date.now(),
      });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });

    const session = store.get('1000');
    expect(session?.currentActivity.tool).toBe('Bash');
  });

  it('POST /api/hooks/event returns 400 for invalid event', async () => {
    const res = await request(app)
      .post('/api/hooks/event')
      .send({ event: 'Invalid' });
    expect(res.status).toBe(400);
  });
});
