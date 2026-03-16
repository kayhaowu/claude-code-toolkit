import { useCallback, useMemo } from 'react';
import { useSessionStore, useSortedSessions } from '../../store/session-store.js';
import { useTerminalStore } from '../../store/terminal-store.js';
import { acquireSocket, releaseSocket } from '../../hooks/socket.js';
import { SidebarItem } from './SidebarItem.js';

export function Sidebar() {
  const sessions = useSortedSessions();
  const selectedId = useSessionStore(s => s.selectedId);
  const setSelected = useSessionStore(s => s.setSelected);
  const setFilter = useSessionStore(s => s.setFilter);
  const filter = useSessionStore(s => s.filter);
  const allSessions = useSessionStore(s => s.sessions);

  const { counts, totalCost } = useMemo(() => {
    let working = 0, idle = 0, stopped = 0, cost = 0;
    for (const s of allSessions.values()) {
      if (s.status === 'working') working++;
      else if (s.status === 'idle') idle++;
      else if (s.status === 'stopped') stopped++;
      cost += s.costUsd;
    }
    return {
      counts: { all: allSessions.size, working, idle, stopped },
      totalCost: cost,
    };
  }, [allSessions]);

  const handleOpenTerminal = useCallback((pid: number) => {
    const socket = acquireSocket();
    socket.emit('terminal:open', { mode: 'attach', sessionPid: pid });
    releaseSocket(); // emit is enqueued synchronously, safe to release
    useTerminalStore.getState().openPane(`pending-${pid}`);
    useSessionStore.getState().setActiveTab('terminal');
  }, []);

  return (
    <div className="w-[260px] border-r border-gray-800 flex flex-col bg-gray-950 flex-shrink-0">
      {/* Header */}
      <div className="px-4 py-3 border-b border-gray-800 flex items-center gap-2">
        <img src="/favicon.svg" alt="logo" width="18" height="18" style={{ imageRendering: 'pixelated' }} />
        <span className="font-bold text-sm text-blue-400">Claude Code Toolkit</span>
      </div>

      {/* Search */}
      <div className="px-3 py-2">
        <input
          type="text"
          placeholder="Search sessions..."
          value={filter.search}
          onChange={e => setFilter({ search: e.target.value })}
          className="w-full bg-gray-800 rounded px-3 py-1.5 text-xs text-gray-300 placeholder-gray-600 outline-none focus:ring-1 focus:ring-blue-500"
        />
      </div>

      {/* Filter pills */}
      <div className="px-3 pb-2 flex gap-1 flex-wrap">
        {([
          { key: null, label: `All ${counts.all}`, color: 'bg-blue-500/20 text-blue-400' },
          { key: 'working', label: `⚡ ${counts.working}`, color: 'bg-green-500/20 text-green-400' },
          { key: 'idle', label: `💤 ${counts.idle}`, color: 'bg-yellow-500/20 text-yellow-400' },
          { key: 'stopped', label: `⏹ ${counts.stopped}`, color: 'bg-red-500/20 text-red-400' },
        ] as const).map(f => (
          <button
            key={f.label}
            onClick={() => setFilter({ status: f.key })}
            className={`px-2 py-0.5 rounded-full text-[10px] ${
              filter.status === f.key ? f.color : 'bg-gray-800 text-gray-500'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Session list */}
      <div className="flex-1 overflow-y-auto">
        {sessions.map(session => (
          <SidebarItem
            key={session.id}
            session={session}
            isSelected={selectedId === session.id}
            onSelect={setSelected}
            onOpenTerminal={handleOpenTerminal}
          />
        ))}
        {sessions.length === 0 && (
          <div className="text-center text-gray-600 text-xs py-8">No sessions found</div>
        )}
      </div>

      {/* Footer */}
      <div className="px-3 py-2 border-t border-gray-800 flex justify-between text-[10px] text-gray-600">
        <span>{counts.all} sessions</span>
        <span>Total: ${totalCost.toFixed(2)}</span>
      </div>
    </div>
  );
}
