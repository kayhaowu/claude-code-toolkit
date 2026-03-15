import { describe, it, expect } from 'vitest';
import { parseSessionJson, parseHeartbeat, parseStatusFile } from '../session-scanner.ts';

describe('parseSessionJson', () => {
  it('parses a valid session.json into AgentSession fields', () => {
    const raw = {
      pid: 446521,
      epoch: 1773126970,
      model: 'Opus 4.6',
      project_dir: '/home/sonic/xcvr-cli-test-suite',
      project_name: 'xcvr-cli-test-suite',
      git_branch: 'main',
      status: 'idle',
      tokens_in: 45330,
      tokens_out: 707050,
      mem_kb: 655308,
      cost_usd: 99.34,
    };
    const result = parseSessionJson(raw);
    expect(result).toEqual({
      id: '446521',
      pid: 446521,
      projectName: 'xcvr-cli-test-suite',
      projectDir: '/home/sonic/xcvr-cli-test-suite',
      gitBranch: 'main',
      model: 'Opus 4.6',
      costUsd: 99.34,
      tokensIn: 45330,
      tokensOut: 707050,
      memKb: 655308,
      startedAt: 1773126970 * 1000,
    });
  });
});

describe('parseHeartbeat', () => {
  it('parses hb.dat JSON', () => {
    const raw = { heartbeat_at: 1773129523, mem_kb: 495564, status: 'idle' };
    const result = parseHeartbeat(raw);
    expect(result).toEqual({
      status: 'idle',
      lastHeartbeat: 1773129523 * 1000,
      memKb: 495564,
    });
  });

  it('maps "working" status correctly', () => {
    const raw = { heartbeat_at: 1773129523, mem_kb: 100000, status: 'working' };
    const result = parseHeartbeat(raw);
    expect(result.status).toBe('working');
  });
});

describe('parseStatusFile', () => {
  it('parses working status', () => {
    expect(parseStatusFile('working 1773129523')).toEqual({ status: 'working', epoch: 1773129523 });
  });

  it('parses idle status', () => {
    expect(parseStatusFile('idle 1773129500')).toEqual({ status: 'idle', epoch: 1773129500 });
  });

  it('treats unknown status as idle', () => {
    expect(parseStatusFile('done 1773129500')).toEqual({ status: 'idle', epoch: 1773129500 });
  });

  it('returns null for empty content', () => {
    expect(parseStatusFile('')).toBeNull();
  });

  it('returns null for invalid epoch', () => {
    expect(parseStatusFile('working abc')).toBeNull();
  });
});
