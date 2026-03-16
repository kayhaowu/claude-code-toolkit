import type { Session } from '@dashboard/types';
import { acquireSocket } from '../../hooks/socket.js';
import { useTerminalStore } from '../../store/terminal-store.js';
import { useSessionStore } from '../../store/session-store.js';

function formatTokens(n: number): string {
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(0)}K`;
  return String(n);
}

function formatHeartbeatAge(lastHeartbeat: number): string {
  const ageMs = Date.now() - lastHeartbeat;
  const secs = Math.floor(ageMs / 1000);
  if (secs < 10) return 'just now';
  if (secs < 60) return `${secs}s ago`;
  const mins = Math.floor(secs / 60);
  return `${mins}m ago`;
}

const statusColors: Record<string, string> = {
  working: 'bg-green-500',
  idle: 'bg-yellow-500',
  stopped: 'bg-red-500',
};

function heartbeatColor(lastHeartbeat: number): string {
  const ageMs = Date.now() - lastHeartbeat;
  if (ageMs < 10_000) return 'text-green-400';
  if (ageMs < 30_000) return 'text-yellow-400';
  return 'text-red-400';
}

interface SidebarItemProps {
  session: Session;
  isSelected: boolean;
  onSelect: (id: string) => void;
}

export function SidebarItem({ session, isSelected, onSelect }: SidebarItemProps) {
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
          <span className={heartbeatColor(session.lastHeartbeat)}>
            {formatHeartbeatAge(session.lastHeartbeat)}
          </span>
        </div>
      </div>
      {session.status !== 'stopped' && session.tmux.session && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            const socket = acquireSocket();
            socket.emit('terminal:open', { mode: 'attach', sessionPid: session.pid });
            useTerminalStore.getState().openPane(`pending-${session.pid}`);
            useSessionStore.getState().setActiveTab('terminal');
          }}
          className="mt-1.5 w-full py-1 rounded bg-gray-800/50 hover:bg-gray-700 text-gray-400 text-[10px] border border-gray-700/50"
        >
          Open Terminal
        </button>
      )}
    </div>
  );
}
