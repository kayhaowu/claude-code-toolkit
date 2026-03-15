// packages/server/src/collectors/log-tailer.ts
import { readdir, readFile } from 'node:fs/promises';
import { watch, statSync, createReadStream } from 'node:fs';
import { join } from 'node:path';
import { createInterface } from 'node:readline';
import { MAX_RECENT_ACTIVITY } from '../../types/src/index.js';
import type { ActivityEntry } from '../../types/src/index.js';
import { EventEmitter } from 'node:events';

const PROJECTS_DIR = join(process.env.HOME ?? '', '.claude', 'projects');

interface ParsedActivity {
  type: 'tool_use';
  tool: string;
  toolInput: string;
  summary: string;
  timestamp: number;
}

export function parseJsonlLine(line: any): ParsedActivity | null {
  if (line.type !== 'assistant') return null;
  const content = line.message?.content;
  if (!Array.isArray(content)) return null;

  const toolUse = content.find((c: any) => c.type === 'tool_use');
  if (!toolUse) return null;

  const tool = toolUse.name;
  let toolInput = '';
  if (toolUse.input) {
    toolInput = toolUse.input.file_path
      ?? toolUse.input.command
      ?? toolUse.input.pattern
      ?? toolUse.input.prompt
      ?? '';
  }

  return {
    type: 'tool_use',
    tool,
    toolInput,
    summary: `${tool}: ${toolInput}`.slice(0, 200),
    timestamp: line.timestamp ? new Date(line.timestamp).getTime() : Date.now(),
  };
}

const TICKET_REGEX = /\b[A-Z]{2,}-\d+\b/;

export function detectTicket(text: string): string | null {
  const match = text.match(TICKET_REGEX);
  return match ? match[0] : null;
}

export function findProjectSlugDir(projectDir: string, slugDirs: string[]): string | null {
  const segments = projectDir.split('/').filter(Boolean);

  for (const slug of slugDirs) {
    const slugBody = slug.startsWith('-') ? slug.slice(1) : slug;
    const parts = slugBody.split('-');

    let segIdx = 0;
    let partIdx = 0;
    while (segIdx < segments.length && partIdx < parts.length) {
      const seg = segments[segIdx];
      const segParts = seg.replace(/\./g, '-').split('-').filter(Boolean);

      let allMatch = true;
      for (let i = 0; i < segParts.length; i++) {
        if (partIdx + i >= parts.length || parts[partIdx + i] !== segParts[i]) {
          allMatch = false;
          break;
        }
      }

      if (allMatch) {
        partIdx += segParts.length;
        segIdx++;
      } else {
        partIdx++;
      }
    }

    if (segIdx === segments.length) {
      return slug;
    }
  }

  return null;
}

export class LogTailer extends EventEmitter {
  private watchers = new Map<string, ReturnType<typeof watch>>();
  private filePositions = new Map<string, number>();
  private pidToFile = new Map<number, string>();

  async startTailing(pid: number, projectDir: string): Promise<void> {
    const slugDirs = await readdir(PROJECTS_DIR).catch(() => []);
    const slugDir = findProjectSlugDir(projectDir, slugDirs);
    if (!slugDir) return;

    const fullDir = join(PROJECTS_DIR, slugDir);
    const jsonlFiles = (await readdir(fullDir)).filter(f => f.endsWith('.jsonl'));

    const claimedFiles = new Set(this.pidToFile.values());
    const availableFiles: Array<{ name: string; mtimeMs: number }> = [];
    let latestOverall = { name: '', mtimeMs: 0 };

    for (const f of jsonlFiles) {
      const filePath = join(fullDir, f);
      const stat = statSync(filePath);
      if (stat.mtimeMs > latestOverall.mtimeMs) {
        latestOverall = { name: f, mtimeMs: stat.mtimeMs };
      }
      if (!claimedFiles.has(filePath)) {
        availableFiles.push({ name: f, mtimeMs: stat.mtimeMs });
      }
    }

    let targetFile = '';
    if (availableFiles.length > 0) {
      availableFiles.sort((a, b) => b.mtimeMs - a.mtimeMs);
      targetFile = availableFiles[0].name;
    } else {
      targetFile = latestOverall.name;
    }

    if (!targetFile) return;

    const filePath = join(fullDir, targetFile);
    this.pidToFile.set(pid, filePath);
    this.tailFile(pid, filePath);
  }

  private tailFile(pid: number, filePath: string): void {
    if (this.watchers.has(filePath)) return;

    const stat = statSync(filePath);
    this.filePositions.set(filePath, stat.size);

    const watcher = watch(filePath, (eventType) => {
      if (eventType === 'rename') {
        this.handleFileRotation(pid, filePath);
        return;
      }
      this.readNewLines(pid, filePath);
    });
    this.watchers.set(filePath, watcher);
  }

  private handleFileRotation(pid: number, oldPath: string): void {
    const watcher = this.watchers.get(oldPath);
    if (watcher) {
      watcher.close();
      this.watchers.delete(oldPath);
    }
    this.filePositions.delete(oldPath);
    this.pidToFile.delete(pid);
    this.emit('file-rotated', { pid });
  }

  private async readNewLines(pid: number, filePath: string): Promise<void> {
    const pos = this.filePositions.get(filePath) ?? 0;
    let size: number;
    try {
      const stat = statSync(filePath);
      size = stat.size;
    } catch {
      this.handleFileRotation(pid, filePath);
      return;
    }
    if (size <= pos) return;

    const stream = createReadStream(filePath, { start: pos, encoding: 'utf-8' });
    const rl = createInterface({ input: stream });

    for await (const line of rl) {
      try {
        const parsed = JSON.parse(line);
        const activity = parseJsonlLine(parsed);
        if (activity) {
          this.emit('activity', { pid, activity });
        }

        // Extract task info from tool use events
        if (parsed.type === 'assistant') {
          const content = parsed.message?.content;
          if (Array.isArray(content)) {
            for (const block of content) {
              if (block.type === 'tool_use' && block.name === 'TaskCreate') {
                this.emit('taskInfo', { pid, taskSubject: block.input?.subject });
              }
              if (block.type === 'tool_use' && block.name === 'TaskUpdate' && block.input?.subject) {
                this.emit('taskInfo', { pid, taskSubject: block.input.subject });
              }
            }
          }
        }
        // Detect git commit messages from tool results
        if (parsed.type === 'result') {
          const text = typeof parsed.result === 'string' ? parsed.result : '';
          const commitMatch = text.match(/\[[\w/-]+\s+[\da-f]+\]\s+(.+)/);
          if (commitMatch) {
            this.emit('taskInfo', { pid, commitMessage: commitMatch[1] });
          }
        }
      } catch {
        // skip malformed lines
      }
    }

    this.filePositions.set(filePath, size);
  }

  isTailing(pid: number): boolean {
    return this.pidToFile.has(pid);
  }

  stopAll(): void {
    for (const watcher of this.watchers.values()) {
      watcher.close();
    }
    this.watchers.clear();
    this.filePositions.clear();
    this.pidToFile.clear();
  }
}
