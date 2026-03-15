import type { TmuxInfo } from '../types/index.ts';
import { readlink } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { platform } from 'node:os';

const execFileAsync = promisify(execFile);

export function parseTmuxOutput(output: string): Map<string, TmuxInfo> {
  const map = new Map<string, TmuxInfo>();
  const paneCountPerWindow = new Map<string, number>();

  for (const line of output.trim().split('\n')) {
    if (!line) continue;
    // format: "session\twindow\twindowName\t/dev/ttyXXX\tpanePid" (tab-delimited)
    const parts = line.split('\t');
    if (parts.length < 5) continue;
    const [session, window, windowName, tty, _pid] = parts;
    if (!tty?.startsWith('/dev/')) continue;

    const windowKey = `${session}:${window}`;
    const paneIndex = paneCountPerWindow.get(windowKey) ?? 0;
    paneCountPerWindow.set(windowKey, paneIndex + 1);

    map.set(tty, {
      session,
      window,
      windowName,
      pane: String(paneIndex),
      tty,
    });
  }
  return map;
}

export function mapPidToTmux(
  pid: number,
  tmuxMap: Map<string, TmuxInfo>,
  readTty: (pid: number) => string | null,
): TmuxInfo | null {
  const tty = readTty(pid);
  if (!tty) return null;
  return tmuxMap.get(tty) ?? null;
}

export async function getTmuxMap(): Promise<Map<string, TmuxInfo>> {
  try {
    const { stdout } = await execFileAsync('tmux', [
      'list-panes', '-a', '-F', '#{session_name}\t#{window_index}\t#{window_name}\t#{pane_tty}\t#{pane_pid}',
    ], { timeout: 3000 });
    return parseTmuxOutput(stdout);
  } catch (err: any) {
    if (err?.code !== 'ENOENT') {
      console.warn('[tmux-mapper] Failed to list tmux panes:', err?.message ?? err);
    }
    return new Map();
  }
}

export async function readPidTty(pid: number): Promise<string | null> {
  try {
    if (platform() === 'linux') {
      return await readlink(`/proc/${pid}/fd/0`);
    }
    // macOS fallback: use lsof to find the controlling TTY
    const { stdout } = await execFileAsync('lsof', ['-p', String(pid), '-a', '-d', '0', '-Fn'], { timeout: 3000 });
    // lsof output format: p<pid>\nn<path>
    const match = stdout.match(/\nn(.+)/);
    return match ? match[1] : null;
  } catch (err: any) {
    if (err?.code !== 'ENOENT' && err?.code !== 'EACCES') {
      console.warn(`[tmux-mapper] readPidTty(${pid}):`, err?.message ?? err);
    }
    return null;
  }
}
