import { useSessionStore } from '../store/session-store.js';
import type { Session } from '@dashboard/types';

function formatTime(ts: number): string {
  return new Date(ts).toLocaleTimeString('en-US', { hour12: false });
}

export function ActivityFeed() {
  const sessions = useSessionStore(s => s.sessions);
  const selectedId = useSessionStore(s => s.selectedId);

  const entries: Array<{ sessionName: string; timestamp: number; summary: string }> = [];

  const targetSessions: Session[] = selectedId
    ? [sessions.get(selectedId)].filter(Boolean) as Session[]
    : Array.from(sessions.values());

  for (const session of targetSessions) {
    for (const entry of session.recentActivity) {
      entries.push({
        sessionName: session.projectName,
        timestamp: entry.timestamp,
        summary: entry.summary,
      });
    }
  }

  entries.sort((a, b) => b.timestamp - a.timestamp);
  const display = entries.slice(0, 100);

  return (
    <div className="border-t border-gray-800 p-6">
      <h2 className="text-sm font-semibold text-gray-400 mb-3">
        Activity Feed {selectedId ? `(${sessions.get(selectedId)?.projectName})` : '(all)'}
      </h2>
      <div className="space-y-1 font-mono text-xs max-h-64 overflow-y-auto">
        {display.map((e, i) => (
          <div key={i} className="flex gap-3 text-gray-300">
            <span className="text-gray-500 shrink-0">{formatTime(e.timestamp)}</span>
            <span className="text-blue-400 shrink-0">[{e.sessionName}]</span>
            <span className="truncate">{e.summary}</span>
          </div>
        ))}
        {display.length === 0 && (
          <p className="text-gray-600">No activity yet.</p>
        )}
      </div>
    </div>
  );
}
