import { describe, it, expect, afterEach } from 'vitest';
import { render, screen, cleanup } from '@testing-library/react';
import { SessionCard } from '../SessionCard.js';
import type { Session } from '@dashboard/types';

const mockSession: Session = {
  id: '1000', pid: 1000, projectName: 'test-project', projectDir: '/tmp/test',
  gitBranch: 'main', model: 'Opus 4.6', costUsd: 42.5, tokensIn: 1500, tokensOut: 50000,
  memKb: 100000, tmux: { session: '0', window: '0', windowName: 'test', pane: '0', tty: '/dev/pts/0' },
  status: 'working', startedAt: Math.floor(Date.now() / 1000) - 3600, lastHeartbeat: Date.now(),
  taskInfo: { taskSubject: 'Fix auth bug' },
  currentActivity: { type: 'tool_use', tool: 'Edit', toolInput: 'src/index.ts', since: Date.now() },
  recentActivity: [], dataSource: 'polling',
};

describe('SessionCard', () => {
  afterEach(() => {
    cleanup();
  });

  it('renders project name', () => {
    render(<SessionCard session={mockSession} />);
    expect(screen.getByText('test-project')).toBeDefined();
  });

  it('renders task info', () => {
    render(<SessionCard session={mockSession} />);
    expect(screen.getByText(/Fix auth bug/)).toBeDefined();
  });

  it('renders current tool activity', () => {
    render(<SessionCard session={mockSession} />);
    expect(screen.getByText(/Edit: src\/index.ts/)).toBeDefined();
  });

  it('renders cost', () => {
    render(<SessionCard session={mockSession} />);
    expect(screen.getByText(/\$42\.50/)).toBeDefined();
  });

  it('renders idle state when no tool use', () => {
    const idleSession = { ...mockSession, currentActivity: { type: 'idle' as const, since: Date.now() } };
    render(<SessionCard session={idleSession} />);
    expect(screen.getByText('idle')).toBeDefined();
  });
});
