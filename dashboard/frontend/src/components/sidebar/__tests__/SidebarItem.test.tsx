import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { SidebarItem } from '../SidebarItem.js';
import type { Session } from '@dashboard/types';

afterEach(() => {
  cleanup();
});

function makeSession(overrides: Partial<Session> = {}): Session {
  return {
    id: '123', pid: 123, projectName: 'test-proj', projectDir: '/tmp/test',
    gitBranch: 'main', model: 'Opus 4.6', costUsd: 5.5, tokensIn: 1000,
    tokensOut: 50000, memKb: 100000, status: 'working',
    startedAt: Date.now() - 60000, lastHeartbeat: Date.now() - 2000,
    tmux: { session: 's', window: '0', windowName: 'test', pane: '0', tty: '' },
    taskInfo: {}, currentActivity: { type: 'idle', since: Date.now() },
    recentActivity: [], dataSource: 'polling',
    ...overrides,
  } as Session;
}

describe('SidebarItem', () => {
  it('renders project name and model', () => {
    render(<SidebarItem session={makeSession()} isSelected={false} onSelect={() => {}} />);
    expect(screen.getByText('test-proj')).toBeDefined();
  });

  it('shows selected state with blue border', () => {
    const { container } = render(
      <SidebarItem session={makeSession()} isSelected={true} onSelect={() => {}} />
    );
    const el = container.firstChild as HTMLElement;
    expect(el.className).toContain('border-blue-500');
  });

  it('calls onSelect when clicked', () => {
    const onSelect = vi.fn();
    render(<SidebarItem session={makeSession()} isSelected={false} onSelect={onSelect} />);
    fireEvent.click(screen.getByText('test-proj'));
    expect(onSelect).toHaveBeenCalledWith('123');
  });

  it('shows tool activity when working', () => {
    const session = makeSession({
      currentActivity: { type: 'tool_use', tool: 'Edit', toolInput: 'file.ts', since: Date.now() },
    });
    render(<SidebarItem session={session} isSelected={false} onSelect={() => {}} />);
    expect(screen.getByText('Edit: file.ts')).toBeDefined();
  });
});
