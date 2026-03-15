import { useConnectionStore } from '../store/connection-store.js';

export function ConnectionBanner() {
  const connected = useConnectionStore(s => s.connected);
  const error = useConnectionStore(s => s.error);

  if (connected) return null;

  return (
    <div className="bg-yellow-900/50 border-b border-yellow-700 px-4 py-2 text-sm text-yellow-200 text-center">
      {error
        ? `Connection error: ${error}`
        : 'Disconnected from server. Reconnecting...'}
    </div>
  );
}
