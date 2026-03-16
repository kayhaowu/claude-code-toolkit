import { memo } from 'react';
import type { Session } from '@dashboard/types';
import { formatTokens, formatHeartbeatAge, heartbeatColor, statusColors } from '../../utils/format.js';

interface SidebarItemProps {
  session: Session;
  isSelected: boolean;
  onSelect: (id: string) => void;
  onOpenTerminal?: (pid: number) => void;
}

export const SidebarItem = memo(function SidebarItem({ session, isSelected, onSelect, onOpenTerminal }: SidebarItemProps) {
  const heartbeatAgeMs = Date.now() - session.lastHeartbeat;

  return (
    <div
      onClick={() => onSelect(session.id)}
      className={`px-3 py-2.5 cursor-pointer border-l-[3px] ${
        isSelected
          ? 'border-blue-500 bg-gray-800/80'
          : 'border-transparent hover:bg-gray-800/40'
      }`}
    >
      <div className="flex items-center gap-2 mb-1">
        <span className={`w-2 h-2 rounded-full flex-shrink-0 ${statusColors[session.status] ?? 'bg-gray-500'}`} />
        <span className="font-medium text-xs truncate">{session.projectName}</span>
      </div>
      <div className="pl-4 text-[10px] text-gray-500 space-y-0.5">
        <div>{session.model} · {session.gitBranch ? `⎇ ${session.gitBranch}` : 'no branch'}</div>
        <div className={session.currentActivity.type !== 'idle' ? 'text-blue-400' : ''}>
          {session.currentActivity.type === 'tool_use'
            ? `${session.currentActivity.tool}: ${session.currentActivity.toolInput}`
            : 'idle'}
        </div>
        <div className="flex justify-between">
          <span>${session.costUsd.toFixed(2)} · {formatTokens(session.tokensOut)} out</span>
          <span className={heartbeatColor(heartbeatAgeMs)}>
            {formatHeartbeatAge(heartbeatAgeMs)}
          </span>
        </div>
      </div>
      {session.status !== 'stopped' && session.tmux.session && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            onOpenTerminal?.(session.pid);
          }}
          className="mt-1.5 w-full py-1 rounded bg-gray-800/50 hover:bg-gray-700 text-gray-400 text-[10px] border border-gray-700/50"
        >
          Open Terminal
        </button>
      )}
    </div>
  );
});
