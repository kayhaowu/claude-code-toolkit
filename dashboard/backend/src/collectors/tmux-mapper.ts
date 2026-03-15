import type { TmuxInfo } from '@dashboard/types';
import { readlink } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export function parseTmuxOutput(output: string): Map<string, TmuxInfo> {
  const map = new Map<string, TmuxInfo>();
  const paneCountPerWindow = new Map<string, number>();

  for (const line of output.trim().split('\n')) {
    if (!line) continue;
    // format: "session:window:windowName /dev/pts/X panePid"
    const match = line.match(/^(\S+):(\S+):(\S+)\s+(\/dev\/pts\/\d+)\s+(\d+)$/);
    if (!match) continue;
    const [, session, window, windowName, tty] = match;
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
      'list-panes', '-a', '-F', '#{session_name}:#{window_index}:#{window_name} #{pane_tty} #{pane_pid}',
    ], { timeout: 3000 });
    return parseTmuxOutput(stdout);
  } catch {
    return new Map();
  }
}

export async function readPidTty(pid: number): Promise<string | null> {
  try {
    return await readlink(`/proc/${pid}/fd/0`);
  } catch {
    return null;
  }
}
