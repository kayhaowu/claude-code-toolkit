import { useSortedSessions, useSessionStore } from '../store/session-store.js';
import { SessionCard } from './SessionCard.js';

export function SessionGrid() {
  const sessions = useSortedSessions();
  const setFilter = useSessionStore(s => s.setFilter);
  const filter = useSessionStore(s => s.filter);

  return (
    <div className="p-6">
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <input
          type="text"
          placeholder="Filter by project, task, branch, or window name..."
          value={filter.search}
          onChange={e => setFilter({ search: e.target.value })}
          className="w-full max-w-md px-3 py-2 bg-gray-900 border border-gray-700 rounded text-sm text-gray-100 placeholder-gray-500 focus:outline-none focus:border-blue-500"
        />
        <div className="flex items-center gap-1">
          {(['all', 'working', 'idle', 'stopped'] as const).map((s) => {
            const active = s === 'all' ? filter.status === null : filter.status === s;
            return (
              <button
                key={s}
                onClick={() => setFilter({ status: s === 'all' ? null : s })}
                className={`px-3 py-1.5 rounded text-xs font-medium transition-colors ${
                  active
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-800 text-gray-400 hover:bg-gray-700 hover:text-gray-200'
                }`}
              >
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </button>
            );
          })}
        </div>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {sessions.map(session => (
          <SessionCard key={session.id} session={session} />
        ))}
        {sessions.length === 0 && (
          <p className="text-gray-500 col-span-full">No active Claude sessions found.</p>
        )}
      </div>
    </div>
  );
}
