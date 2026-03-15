export interface TmuxInfo {
  session: string;
  window: string;
  windowName: string;
  pane: string;
  tty: string;
}

/** Generic task context for a session (replaces TicketInfo) */
export interface TaskInfo {
  /** Latest git commit message (from git tool use events) */
  commitMessage?: string;
  /** Current task subject (from TaskCreate/TaskUpdate events) */
  taskSubject?: string;
}

export interface CurrentActivity {
  type: 'tool_use' | 'thinking' | 'responding' | 'idle';
  tool?: string;
  toolInput?: string;
  since: number;
}

export interface ActivityEntry {
  timestamp: number;
  type: string;
  summary: string;
}

export interface Session {
  id: string;
  pid: number;
  projectName: string;
  projectDir: string;
  gitBranch: string | null;
  model: string;
  costUsd: number;
  tokensIn: number;
  tokensOut: number;
  memKb: number;
  tmux: TmuxInfo;
  status: 'working' | 'idle' | 'stopped';
  startedAt: number;
  lastHeartbeat: number;
  taskInfo: TaskInfo;
  currentActivity: CurrentActivity;
  recentActivity: ActivityEntry[];
  dataSource: 'polling' | 'hooks' | 'both';
}

export type WSEvent =
  | { type: 'sessions:snapshot'; sessions: Session[] }
  | { type: 'session:updated'; session: Session }
  | { type: 'session:removed'; id: string };

// ── Terminal types ──

export type TerminalSession =
  | { id: string; mode: 'attach'; sessionPid: number; tmuxTarget: string; title: string; status: 'connected' | 'disconnected'; createdAt: number }
  | { id: string; mode: 'new'; sessionPid: null; tmuxTarget: string; title: string; status: 'connected' | 'disconnected'; createdAt: number };

export type TerminalOpenPayload =
  | { mode: 'attach'; sessionPid: number }
  | { mode: 'new'; cwd?: string };

export interface TerminalInputPayload {
  sessionId: string;
  data: string;
}

export interface TerminalResizePayload {
  sessionId: string;
  cols: number;
  rows: number;
}

export interface TerminalReconnectPayload {
  sessionIds: string[];
}

export type TerminalWSEvent =
  | { type: 'terminal:sessions'; sessions: TerminalSession[] }
  | { type: 'terminal:opened'; session: TerminalSession }
  | { type: 'terminal:closed'; sessionId: string }
  | { type: 'terminal:error'; sessionId?: string; message: string };

export const MAX_RECENT_ACTIVITY = 50;
export const SCAN_INTERVAL_MS = 2000;
export const PHANTOM_TTL_MS = 30_000;
export const ACTIVITY_STALENESS_MS = 120_000;
