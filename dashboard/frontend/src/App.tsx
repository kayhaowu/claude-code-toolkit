import { BrowserRouter } from 'react-router-dom';
import { Header } from './components/Header.js';
import { SummaryBar } from './components/SummaryBar.js';
import { SessionGrid } from './components/SessionGrid.js';
import { SessionDetailPanel } from './components/SessionDetailPanel.js';
import { ActivityFeed } from './components/ActivityFeed.js';
import { TerminalContainer } from './components/terminal/TerminalContainer.js';
import { useSocket } from './hooks/use-socket.js';
import { useTerminalSocket } from './hooks/use-terminal-socket.js';
import { useTerminalStore } from './store/terminal-store.js';

function SessionMonitorPage() {
  const layout = useTerminalStore(s => s.layout);

  return (
    <div className="flex flex-col flex-1 overflow-hidden">
      <div className={`flex-1 overflow-auto ${layout ? 'max-h-[60vh]' : ''}`}>
        <SummaryBar />
        <SessionGrid />
        <SessionDetailPanel />
        <ActivityFeed />
      </div>
      {layout && (
        <div className="border-t border-gray-800 min-h-[200px] flex-shrink-0" style={{ height: '40vh' }}>
          <TerminalContainer />
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
      <div className="min-h-screen flex flex-col bg-gray-950 text-gray-100">
        <Header />
        <SessionMonitorPage />
      </div>
    </BrowserRouter>
  );
}
