import { useState, useCallback } from 'react';
import type { SplitLayout } from '../../store/terminal-store.js';
import { useTerminalStore } from '../../store/terminal-store.js';
import { useSessionStore } from '../../store/session-store.js';
import type { TerminalOpenPayload } from '@dashboard/types';
import { acquireSocket } from '../../hooks/socket.js';
import { TerminalPane } from './TerminalPane.js';
import { SplitDivider } from './SplitDivider.js';
import { TerminalContextMenu } from './TerminalContextMenu.js';

interface ContextMenuState {
  x: number;
  y: number;
  paneId: string;
}

interface TerminalNodeProps {
  layout: SplitLayout;
  onContextMenu: (e: React.MouseEvent, paneId: string) => void;
}

function TerminalNode({ layout, onContextMenu }: TerminalNodeProps) {
  const resizePane = useTerminalStore((s) => s.resizePane);

  if (layout.type === 'terminal') {
    return (
      <TerminalPane
        paneId={layout.paneId}
        sessionId={layout.sessionId}
        onContextMenu={onContextMenu}
      />
    );
  }

  const isHorizontal = layout.direction === 'horizontal';
  const firstStyle = isHorizontal
    ? { width: `${layout.ratio * 100}%` }
    : { height: `${layout.ratio * 100}%` };
  const secondStyle = isHorizontal
    ? { width: `${(1 - layout.ratio) * 100}%` }
    : { height: `${(1 - layout.ratio) * 100}%` };

  const { splitId } = layout;

  return (
    <div className={`flex ${isHorizontal ? 'flex-row' : 'flex-col'} h-full w-full`}>
      <div style={firstStyle} className="overflow-hidden">
        <TerminalNode layout={layout.children[0]} onContextMenu={onContextMenu} />
      </div>
      <SplitDivider
        direction={layout.direction}
        onResize={(ratio) => resizePane(splitId, ratio)}
      />
      <div style={secondStyle} className="overflow-hidden">
        <TerminalNode layout={layout.children[1]} onContextMenu={onContextMenu} />
      </div>
    </div>
  );
}

export function TerminalContainer() {
  const layout = useTerminalStore((s) => s.layout);
  const splitPane = useTerminalStore((s) => s.splitPane);
  const closePane = useTerminalStore((s) => s.closePane);
  const sessions = useSessionStore((s) => s.sessions);
  const terminalSessions = useTerminalStore((s) => s.sessions);

  const [contextMenu, setContextMenu] = useState<ContextMenuState | null>(null);

  const handleContextMenu = useCallback((e: React.MouseEvent, paneId: string) => {
    setContextMenu({ x: e.clientX, y: e.clientY, paneId });
  }, []);

  const handleSplit = useCallback(
    (paneId: string, direction: 'horizontal' | 'vertical', payload: TerminalOpenPayload) => {
      const socket = acquireSocket();
      socket.emit('terminal:open', payload, (sessionId: string) => {
        splitPane(paneId, direction, sessionId);
      });
      setContextMenu(null);
    },
    [splitPane],
  );

  const handleClose = useCallback(
    (paneId: string) => {
      closePane(paneId);
      setContextMenu(null);
    },
    [closePane],
  );

  if (!layout) return null;

  const availableSessions = Array.from(sessions.values()).map((s) => ({
    pid: s.pid,
    projectName: s.projectName,
    tmux: s.tmux,
  }));

  const attachedPids = new Set(
    Array.from(terminalSessions.values())
      .filter((ts) => ts.mode === 'attach')
      .map((ts) => (ts as Extract<typeof ts, { mode: 'attach' }>).sessionPid),
  );

  return (
    <div className="h-full w-full relative">
      <TerminalNode layout={layout} onContextMenu={handleContextMenu} />
      {contextMenu && (
        <TerminalContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          paneId={contextMenu.paneId}
          availableAgents={availableSessions}
          attachedPids={attachedPids}
          onSplit={handleSplit}
          onClose={handleClose}
          onDismiss={() => setContextMenu(null)}
        />
      )}
    </div>
  );
}
