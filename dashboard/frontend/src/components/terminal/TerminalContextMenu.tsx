import { useState, useEffect, useRef } from 'react';
import type { TerminalOpenPayload } from '@dashboard/types';

interface Agent {
  pid: number;
  projectName?: string;
  tmux?: { session: string; window: string; pane: string };
}

interface TerminalContextMenuProps {
  x: number;
  y: number;
  paneId: string;
  availableAgents: Agent[];
  attachedPids: Set<number>;
  onSplit: (paneId: string, direction: 'horizontal' | 'vertical', payload: TerminalOpenPayload) => void;
  onClose: (paneId: string) => void;
  onDismiss: () => void;
}

export function TerminalContextMenu({
  x,
  y,
  paneId,
  availableAgents,
  attachedPids,
  onSplit,
  onClose,
  onDismiss,
}: TerminalContextMenuProps) {
  const [hoveredDirection, setHoveredDirection] = useState<'horizontal' | 'vertical' | null>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        onDismiss();
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [onDismiss]);

  const unattachedAgents = availableAgents.filter(
    (a) => a.tmux && !attachedPids.has(a.pid),
  );

  const renderSubMenu = (direction: 'horizontal' | 'vertical') => {
    if (hoveredDirection !== direction) return null;
    return (
      <div className="absolute left-full top-0 bg-gray-800 border border-gray-700 rounded shadow-lg min-w-[180px] py-1 z-50">
        {unattachedAgents.map((agent) => (
          <button
            key={agent.pid}
            className="w-full text-left px-3 py-1.5 text-sm text-gray-300 hover:bg-gray-700"
            onClick={() => onSplit(paneId, direction, { mode: 'attach', sessionPid: agent.pid })}
          >
            session-{agent.pid} ({agent.projectName || 'unknown'})
          </button>
        ))}
        <div className="border-t border-gray-700 my-1" />
        <button
          className="w-full text-left px-3 py-1.5 text-sm text-green-400 hover:bg-gray-700"
          onClick={() => onSplit(paneId, direction, { mode: 'new' })}
        >
          New Terminal
        </button>
      </div>
    );
  };

  return (
    <div
      ref={menuRef}
      className="fixed bg-gray-800 border border-gray-700 rounded shadow-lg min-w-[160px] py-1 z-50"
      style={{ left: x, top: y }}
    >
      <div
        className="relative px-3 py-1.5 text-sm text-gray-300 hover:bg-gray-700 cursor-pointer flex justify-between"
        onMouseEnter={() => setHoveredDirection('horizontal')}
      >
        <span>Split Horizontal</span>
        <span className="text-gray-500">▸</span>
        {renderSubMenu('horizontal')}
      </div>
      <div
        className="relative px-3 py-1.5 text-sm text-gray-300 hover:bg-gray-700 cursor-pointer flex justify-between"
        onMouseEnter={() => setHoveredDirection('vertical')}
      >
        <span>Split Vertical</span>
        <span className="text-gray-500">▸</span>
        {renderSubMenu('vertical')}
      </div>
      <div className="border-t border-gray-700 my-1" />
      <button
        className="w-full text-left px-3 py-1.5 text-sm text-red-400 hover:bg-gray-700"
        onClick={() => onClose(paneId)}
        onMouseEnter={() => setHoveredDirection(null)}
      >
        Close Pane
      </button>
    </div>
  );
}
