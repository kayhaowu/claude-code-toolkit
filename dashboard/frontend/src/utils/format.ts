export function formatDuration(ms: number | null): string {
  if (!ms) return '';
  const secs = Math.floor(ms / 1000);
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

export function formatTime(ts: number): string {
  return new Date(ts).toLocaleTimeString('en-US', { hour12: false });
}

export function formatTokens(n: number): string {
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(0)}K`;
  return String(n);
}

/** Returns how long ago the heartbeat was, in human-readable form */
export function formatHeartbeatAge(ageMs: number): string {
  const secs = Math.floor(ageMs / 1000);
  if (secs < 10) return 'just now';
  if (secs < 60) return `${secs}s ago`;
  const mins = Math.floor(secs / 60);
  return `${mins}m ago`;
}

/** Returns a color class based on heartbeat freshness */
export function heartbeatColor(ageMs: number): string {
  if (ageMs < 10_000) return 'text-green-400';
  if (ageMs < 30_000) return 'text-yellow-400';
  return 'text-red-400';
}

export const statusColors: Record<string, string> = {
  working: 'bg-green-500',
  idle: 'bg-yellow-500',
  stopped: 'bg-red-500',
};
