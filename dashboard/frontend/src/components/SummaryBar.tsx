import { useSessionStore } from '../store/session-store.js';

export function SummaryBar() {
  const sessions = useSessionStore(s => s.sessions);
  const list = Array.from(sessions.values());
  const working = list.filter(s => s.status === 'working').length;
  const idle = list.filter(s => s.status === 'idle').length;
  const stopped = list.filter(s => s.status === 'stopped').length;
  const totalCost = list.reduce((sum, s) => sum + s.costUsd, 0);
  const tasks = list.filter(s => s.taskInfo.taskSubject).length;

  return (
    <div className="flex flex-wrap gap-6 px-6 py-3 bg-gray-900 border-b border-gray-800 text-sm">
      <span className="flex items-center gap-1.5">
        <span className="w-2 h-2 rounded-full bg-green-500" /> Active: {working}
      </span>
      <span className="flex items-center gap-1.5">
        <span className="w-2 h-2 rounded-full bg-yellow-500" /> Idle: {idle}
      </span>
      <span className="flex items-center gap-1.5">
        <span className="w-2 h-2 rounded-full bg-red-500" /> Stopped: {stopped}
      </span>
      <span className="text-gray-400">Total Cost: ${totalCost.toFixed(2)}</span>
      <span className="text-gray-400">Tasks: {tasks} in progress</span>
    </div>
  );
}
