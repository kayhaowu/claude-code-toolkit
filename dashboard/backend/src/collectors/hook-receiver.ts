import { Router } from 'express';
import type { SessionStore } from '../store/session-store.js';

interface HookEventBody {
  event?: string;
  pid?: number;
  tool?: string;
  input?: Record<string, unknown>;
  timestamp?: number;
}

type HookResult =
  | { type: 'activity'; pid: number; activity: { type: 'tool_use'; tool: string; toolInput: string; summary: string; timestamp: number } }
  | { type: 'stop'; pid: number; timestamp: number }
  | null;

export function parseHookEvent(body: HookEventBody): HookResult {
  if (!body.event || !body.pid) return null;

  if (body.event === 'PostToolUse') {
    const tool = body.tool ?? 'unknown';
    const input = body.input ?? {};
    const toolInput = (input.file_path ?? input.command ?? input.pattern ?? input.prompt ?? '') as string;
    return {
      type: 'activity',
      pid: body.pid,
      activity: {
        type: 'tool_use',
        tool,
        toolInput,
        summary: `${tool}: ${toolInput}`.slice(0, 200),
        timestamp: body.timestamp ?? Date.now(),
      },
    };
  }

  if (body.event === 'Stop') {
    return {
      type: 'stop',
      pid: body.pid,
      timestamp: body.timestamp ?? Date.now(),
    };
  }

  return null;
}

export function createHookRouter(store: SessionStore): Router {
  const router = Router();

  router.post('/event', (req, res) => {
    const parsed = parseHookEvent(req.body);
    if (!parsed) {
      res.status(400).json({ error: 'invalid event' });
      return;
    }
    if (parsed.type === 'activity') {
      store.updateActivity(parsed.pid, parsed.activity);
    }
    res.json({ ok: true });
  });

  return router;
}
