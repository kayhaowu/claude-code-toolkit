import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { TerminalContextMenu } from '../TerminalContextMenu.js';
import type { TerminalSession } from '@dashboard/types';

describe('TerminalContextMenu', () => {
  afterEach(() => {
    cleanup();
  });

  const defaultProps = {
    x: 100,
    y: 200,
    paneId: 'p1',
    availableSessions: [
      { pid: 1, projectName: 'test-project', tmux: { session: 's', window: '0', pane: '0' } },
      { pid: 2, projectName: 'api-server', tmux: { session: 's', window: '0', pane: '1' } },
    ] as any[],
    attachedPids: new Set<number>(),
    onSplit: vi.fn(),
    onClose: vi.fn(),
    onDismiss: vi.fn(),
  };

  it('renders Split Horizontal and Split Vertical options', () => {
    render(<TerminalContextMenu {...defaultProps} />);
    expect(screen.getByText('Split Horizontal')).toBeTruthy();
    expect(screen.getByText('Split Vertical')).toBeTruthy();
    expect(screen.getByText('Close Pane')).toBeTruthy();
  });

  it('shows session sub-menu on Split Horizontal hover', () => {
    render(<TerminalContextMenu {...defaultProps} />);
    fireEvent.mouseEnter(screen.getByText('Split Horizontal'));
    expect(screen.getByText('session-1 (test-project)')).toBeTruthy();
    expect(screen.getByText('session-2 (api-server)')).toBeTruthy();
    expect(screen.getByText('New Terminal')).toBeTruthy();
  });

  it('excludes already-attached sessions from sub-menu', () => {
    render(<TerminalContextMenu {...defaultProps} attachedPids={new Set([1])} />);
    fireEvent.mouseEnter(screen.getByText('Split Horizontal'));
    expect(screen.queryByText('session-1 (test-project)')).toBeNull();
    expect(screen.getByText('session-2 (api-server)')).toBeTruthy();
  });

  it('calls onSplit with direction and session info', () => {
    render(<TerminalContextMenu {...defaultProps} />);
    fireEvent.mouseEnter(screen.getByText('Split Horizontal'));
    fireEvent.click(screen.getByText('session-1 (test-project)'));
    expect(defaultProps.onSplit).toHaveBeenCalledWith('p1', 'horizontal', { mode: 'attach', sessionPid: 1 });
  });

  it('calls onSplit with new mode for New Terminal', () => {
    render(<TerminalContextMenu {...defaultProps} />);
    fireEvent.mouseEnter(screen.getByText('Split Horizontal'));
    fireEvent.click(screen.getByText('New Terminal'));
    expect(defaultProps.onSplit).toHaveBeenCalledWith('p1', 'horizontal', { mode: 'new' });
  });

  it('calls onClose when Close Pane clicked', () => {
    render(<TerminalContextMenu {...defaultProps} />);
    fireEvent.click(screen.getByText('Close Pane'));
    expect(defaultProps.onClose).toHaveBeenCalledWith('p1');
  });
});
