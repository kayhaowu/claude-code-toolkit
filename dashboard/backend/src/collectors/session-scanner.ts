import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import type { Session, TmuxInfo } from '@dashboard/types';
import { getTmuxMap as defaultGetTmuxMap, readPidTty as defaultReadPidTty } from './tmux-mapper.js';

interface RawSessionJson {
  pid: number;
  epoch: number;
  model: string;
  project_dir: string;
  project_name: string;
  git_branch: string;
  status: string;
  tokens_in: number;
  tokens_out: number;
  mem_kb: number;
  cost_usd: number;
}

interface RawHeartbeat {
  heartbeat_at: number;
  mem_kb: number;
  status: string;
}

export function parseSessionJson(raw: RawSessionJson): Pick<
  Session,
  'id' | 'pid' | 'projectName' | 'projectDir' | 'gitBranch' | 'model' | 'costUsd' | 'tokensIn' | 'tokensOut' | 'memKb' | 'startedAt'
> {
  return {
    id: String(raw.pid),
    pid: raw.pid,
    projectName: raw.project_name,
    projectDir: raw.project_dir,
    gitBranch: raw.git_branch || null,
    model: raw.model,
    costUsd: raw.cost_usd,
    tokensIn: raw.tokens_in,
    tokensOut: raw.tokens_out,
    memKb: raw.mem_kb,
    startedAt: raw.epoch,
  };
}

export function parseHeartbeat(raw: RawHeartbeat): {
  status: 'working' | 'idle';
  lastHeartbeat: number;
  memKb: number;
} {
  return {
    status: raw.status === 'working' ? 'working' : 'idle',
    lastHeartbeat: raw.heartbeat_at,
    memKb: raw.mem_kb,
  };
}

const SESSIONS_DIR = join(process.env.HOME ?? '', '.claude', 'sessions');

export interface ScanDeps {
  listSessionFiles: () => Promise<string[]>;
  readJson: (path: string) => Promise<unknown>;
  isProcessAlive: (pid: number) => boolean;
  getTmuxMap: () => Promise<Map<string, TmuxInfo>>;
  readPidTty: (pid: number) => Promise<string | null>;
}

const defaultDeps: ScanDeps = {
  async listSessionFiles() {
    const files = await readdir(SESSIONS_DIR);
    return files.filter((f) => f.endsWith('.json'));
  },
  async readJson(path: string) {
    const data = await readFile(path, 'utf-8');
    return JSON.parse(data);
  },
  isProcessAlive(pid: number) {
    try { process.kill(pid, 0); return true; } catch { return false; }
  },
  getTmuxMap: defaultGetTmuxMap,
  readPidTty: defaultReadPidTty,
};

export async function scanSessions(deps: ScanDeps = defaultDeps): Promise<Session[]> {
  const [sessionFiles, tmuxMap] = await Promise.all([
    deps.listSessionFiles(),
    deps.getTmuxMap(),
  ]);

  const sessions: Session[] = [];

  for (const file of sessionFiles) {
    const pid = parseInt(file.replace('.json', ''), 10);
    if (isNaN(pid)) continue;

    try {
      const raw = await deps.readJson(join(SESSIONS_DIR, file)) as any;
      const parsed = parseSessionJson(raw);
      const alive = deps.isProcessAlive(pid);

      let status: Session['status'] = 'stopped';
      let lastHeartbeat = parsed.startedAt;
      let memKb = parsed.memKb;

      if (alive) {
        try {
          const hb = await deps.readJson(join(SESSIONS_DIR, `${pid}.hb.dat`)) as any;
          const hbParsed = parseHeartbeat(hb);
          status = hbParsed.status;
          lastHeartbeat = hbParsed.lastHeartbeat;
          memKb = hbParsed.memKb;
        } catch (err: any) {
          if (err?.code !== 'ENOENT') {
            console.warn(`[scan] Failed to read heartbeat for PID ${pid}:`, err);
          }
          status = 'idle';
        }
      }

      const tty = await deps.readPidTty(pid);
      const tmux = tty ? tmuxMap.get(tty) ?? null : null;

      sessions.push({
        ...parsed,
        memKb,
        status,
        lastHeartbeat,
        tmux: tmux ?? { session: '', window: '', windowName: '', pane: '', tty: '' },
        taskInfo: {},
        currentActivity: { type: 'idle', since: Date.now() },
        recentActivity: [],
        dataSource: 'polling',
      });
    } catch (err) {
      console.warn(`[scan] Skipping session file ${file}:`, err);
    }
  }

  return sessions;
}
