import { useSessionStore } from '../store/session-store.js';

const tabs = [
  { key: 'terminal' as const, label: 'Terminal' },
  { key: 'activity' as const, label: 'Activity' },
  { key: 'git' as const, label: 'Git' },
  { key: 'detail' as const, label: 'Detail' },
];

export function TabBar() {
  const activeTab = useSessionStore(s => s.activeTab);
  const setActiveTab = useSessionStore(s => s.setActiveTab);

  return (
    <div className="flex border-b border-gray-800 bg-gray-900/50">
      {tabs.map(tab => (
        <button
          key={tab.key}
          onClick={() => setActiveTab(tab.key)}
          className={`px-5 py-2.5 text-xs transition-colors ${
            activeTab === tab.key
              ? 'border-b-2 border-blue-500 text-blue-400'
              : 'text-gray-500 hover:text-gray-300'
          }`}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
