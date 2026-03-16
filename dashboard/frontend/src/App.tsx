import { BrowserRouter } from 'react-router-dom';
import { Sidebar } from './components/sidebar/index.js';
import { TabBar } from './components/TabBar.js';
import { SessionDetailPanel } from './components/SessionDetailPanel.js';
import { ActivityFeed } from './components/ActivityFeed.js';
import { TerminalContainer } from './components/terminal/TerminalContainer.js';
import { ErrorBoundary } from './components/ErrorBoundary.js';
import { ConnectionBanner } from './components/ConnectionBanner.js';
import { useSocket } from './hooks/use-socket.js';
import { useTerminalSocket } from './hooks/use-terminal-socket.js';
import { useSessionStore } from './store/session-store.js';
import { useTerminalStore } from './store/terminal-store.js';

function MainContent() {
  const selectedId = useSessionStore(s => s.selectedId);
  const activeTab = useSessionStore(s => s.activeTab);
  const layout = useTerminalStore(s => s.layout);
  const terminalError = useTerminalStore(s => s.error);

  if (!selectedId) {
    return (
      <div className="flex-1 flex items-center justify-center text-gray-600 text-sm">
        Select a session from the sidebar
      </div>
    );
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <TabBar />
      {activeTab === 'terminal' && (
        <div className="flex-1 overflow-hidden flex flex-col min-h-0">
          {terminalError && (
            <div className="bg-red-900/50 border-b border-red-700 px-4 py-2 text-sm text-red-200 flex-shrink-0">
              Terminal error: {terminalError}
            </div>
          )}
          {layout ? (
            <TerminalContainer />
          ) : (
            <div className="flex-1 flex items-center justify-center text-gray-600 text-sm">
              Click &quot;Open Terminal&quot; on a session to connect
            </div>
          )}
        </div>
      )}
      {activeTab === 'activity' && (
        <div className="flex-1 overflow-auto">
          <ActivityFeed />
        </div>
      )}
      {activeTab === 'git' && (
        <div className="flex-1 flex items-center justify-center text-gray-600 text-sm">
          Git integration coming in Phase 2b
        </div>
      )}
      {activeTab === 'detail' && (
        <div className="flex-1 overflow-auto">
          <SessionDetailPanel />
        </div>
      )}
    </div>
  );
}

export function App() {
  useSocket();
  useTerminalSocket();

  return (
    <BrowserRouter>
      <ErrorBoundary>
        <div className="h-screen flex flex-col bg-gray-950 text-gray-100">
          <ConnectionBanner />
          <div className="flex-1 flex overflow-hidden">
            <Sidebar />
            <MainContent />
          </div>
        </div>
      </ErrorBoundary>
    </BrowserRouter>
  );
}
