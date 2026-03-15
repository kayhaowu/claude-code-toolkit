import { useState, useEffect } from 'react';
import type { Session } from '@dashboard/types';
import { useSessionStore } from '../store/session-store.js';

const statusColors = {
  working: 'bg-green-500',
  idle: 'bg-yellow-500',
  stopped: 'bg-red-500',
};

function formatUptime(startedAt: number): string {
  const diff = Date.now() - startedAt * 1000;
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}m`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ${mins % 60}m`;
  const days = Math.floor(hours / 24);
  return `${days}d ${hours % 24}h`;
}

function formatTokens(n: number): string {
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(0)}K`;
  return String(n);
}

/** Returns how long ago the heartbeat was, in human-readable form */
function formatHeartbeatAge(lastHeartbeat: number): string {
  const ageMs = Date.now() - lastHeartbeat * 1000;
  const secs = Math.floor(ageMs / 1000);
  if (secs < 10) return 'just now';
  if (secs < 60) return `${secs}s ago`;
  const mins = Math.floor(secs / 60);
  return `${mins}m ago`;
}

/** Returns a color class based on heartbeat freshness */
function heartbeatColor(lastHeartbeat: number): string {
  const ageMs = Date.now() - lastHeartbeat * 1000;
  if (ageMs < 10_000) return 'text-green-400';
  if (ageMs < 30_000) return 'text-yellow-400';
  return 'text-red-400';
}

export function SessionCard({ session }: { session: Session }) {
  const selectedId = useSessionStore(s => s.selectedId);
  const setSelected = useSessionStore(s => s.setSelected);
  const isSelected = selectedId === session.id;

  // Re-render periodically so heartbeat age stays fresh
  const [, setTick] = useState(0);
  useEffect(() => {
    const interval = setInterval(() => setTick(t => t + 1), 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div
      onClick={() => setSelected(isSelected ? null : session.id)}
      className={`rounded-lg border p-4 cursor-pointer transition-colors ${
        isSelected
          ? 'border-blue-500 bg-gray-800'
          : 'border-gray-800 bg-gray-900 hover:border-gray-700'
      }`}
    >
      <div className="flex items-center gap-2 mb-2">
        <span className={`w-2.5 h-2.5 rounded-full ${statusColors[session.status]}`} />
        <span className="font-medium truncate">{session.projectName}</span>
      </div>

      <div className="text-xs text-gray-400 space-y-1">
        <div>PID: {session.pid} &middot; tmux: {session.tmux.windowName || '—'}</div>
        <div>{session.model}</div>
        <div>${session.costUsd.toFixed(2)} &middot; {formatTokens(session.tokensIn)}/{formatTokens(session.tokensOut)}</div>

        <div className="border-t border-gray-800 my-1.5" />

        {session.currentActivity.type === 'tool_use' ? (
          <div className="text-blue-300 truncate">
            {session.currentActivity.tool}: {session.currentActivity.toolInput}
          </div>
        ) : (
          <div className="text-gray-500">idle</div>
        )}

        {session.taskInfo.taskSubject ? (
          <div className="text-purple-300">{session.taskInfo.taskSubject}</div>
        ) : (
          <div className="text-gray-600">no task</div>
        )}

        <div className="flex items-center justify-between">
          <span className="text-gray-500">uptime: {formatUptime(session.startedAt)}</span>
          <span className={`${heartbeatColor(session.lastHeartbeat)}`} title={`Last heartbeat: ${formatHeartbeatAge(session.lastHeartbeat)}`}>
            {formatHeartbeatAge(session.lastHeartbeat)}
          </span>
        </div>
      </div>
    </div>
  );
}
