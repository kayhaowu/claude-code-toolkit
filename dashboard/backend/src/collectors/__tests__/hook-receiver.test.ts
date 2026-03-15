import { describe, it, expect } from 'vitest';
import { parseHookEvent } from '../hook-receiver.ts';

describe('parseHookEvent', () => {
  it('parses a PostToolUse hook event', () => {
    const body = {
      event: 'PostToolUse',
      pid: 446521,
      tool: 'Edit',
      input: { file_path: '/home/sonic/src/index.ts' },
      timestamp: 1773129523000,
    };
    const result = parseHookEvent(body);
    expect(result).toEqual({
      type: 'activity',
      pid: 446521,
      activity: {
        type: 'tool_use',
        tool: 'Edit',
        toolInput: '/home/sonic/src/index.ts',
        summary: 'Edit: /home/sonic/src/index.ts',
        timestamp: 1773129523000,
      },
    });
  });

  it('parses a Stop hook event', () => {
    const body = { event: 'Stop', pid: 446521, timestamp: 1773129600000 };
    const result = parseHookEvent(body);
    expect(result).toEqual({
      type: 'stop',
      pid: 446521,
      timestamp: 1773129600000,
    });
  });

  it('returns null for invalid events', () => {
    expect(parseHookEvent({})).toBeNull();
    expect(parseHookEvent({ event: 'Unknown', pid: 123 })).toBeNull();
    expect(parseHookEvent({ event: 'PostToolUse' })).toBeNull(); // no pid
  });
});
