import { useSessionStore } from '../store/session-store.js';

function formatTime(ts: number): string {
  return new Date(ts).toLocaleTimeString('en-US', { hour12: false });
}

export function SessionDetailPanel() {
  const sessions = useSessionStore(s => s.sessions);
  const selectedId = useSessionStore(s => s.selectedId);
  const setSelected = useSessionStore(s => s.setSelected);

  if (!selectedId) return null;
  const session = sessions.get(selectedId);
  if (!session) return null;

  return (
    <div className="border-t border-gray-800 bg-gray-900 p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-gray-200">
          {session.projectName} — Detail
        </h2>
        <button
          onClick={() => setSelected(null)}
          className="text-gray-500 hover:text-gray-300 text-sm"
        >
          Close
        </button>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 text-xs text-gray-400 mb-4">
        <div>
          <span className="text-gray-500">PID:</span> {session.pid}
        </div>
        <div>
          <span className="text-gray-500">Model:</span> {session.model}
        </div>
        <div>
          <span className="text-gray-500">Branch:</span> {session.gitBranch || '—'}
        </div>
        <div>
          <span className="text-gray-500">Memory:</span> {(session.memKb / 1024).toFixed(0)} MB
        </div>
        <div>
          <span className="text-gray-500">Cost:</span> ${session.costUsd.toFixed(2)}
        </div>
        <div>
          <span className="text-gray-500">Tokens:</span> {session.tokensIn.toLocaleString()} in / {session.tokensOut.toLocaleString()} out
        </div>
        <div>
          <span className="text-gray-500">tmux:</span> {session.tmux.session}:{session.tmux.window} ({session.tmux.windowName})
        </div>
        <div>
          <span className="text-gray-500">Data source:</span> {session.dataSource}
        </div>
      </div>

      {session.taskInfo.taskSubject && (
        <div className="mb-4 p-3 bg-gray-800 rounded text-xs">
          <span className="text-purple-300 font-medium">{session.taskInfo.taskSubject}</span>
          {session.taskInfo.commitMessage && (
            <span className="text-gray-400 ml-2">{session.taskInfo.commitMessage}</span>
          )}
        </div>
      )}

      <h3 className="text-xs font-semibold text-gray-500 mb-2">Activity Timeline</h3>
      <div className="space-y-1 font-mono text-xs max-h-48 overflow-y-auto">
        {session.recentActivity.slice().reverse().map((entry, i) => (
          <div key={i} className="flex gap-3 text-gray-300">
            <span className="text-gray-500 shrink-0">{formatTime(entry.timestamp)}</span>
            <span className="truncate">{entry.summary}</span>
          </div>
        ))}
        {session.recentActivity.length === 0 && (
          <p className="text-gray-600">No activity recorded yet.</p>
        )}
      </div>
    </div>
  );
}
