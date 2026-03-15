import { EventEmitter } from 'node:events';
import type { Session, ActivityEntry, TaskInfo, CurrentActivity } from '@dashboard/types';
import { MAX_RECENT_ACTIVITY, PHANTOM_TTL_MS, ACTIVITY_STALENESS_MS } from '@dashboard/types';

export class SessionStore extends EventEmitter {
  private sessions = new Map<string, Session>();
  /** Tracks when a stopped session was first noticed as gone from scan */
  private stoppedAt = new Map<string, number>();

  getAll(): Session[] {
    return Array.from(this.sessions.values());
  }

  get(id: string): Session | undefined {
    return this.sessions.get(id);
  }

  updateFromScan(scanned: Session[], now = Date.now()): void {
    const scannedIds = new Set(scanned.map(s => s.id));

    // Mark gone sessions as stopped (phantom) or remove if past TTL
    for (const id of this.sessions.keys()) {
      if (!scannedIds.has(id)) {
        if (!this.stoppedAt.has(id)) {
          // First scan where this session is missing — mark as stopped
          this.stoppedAt.set(id, now);
          const updated = { ...this.sessions.get(id)!, status: 'stopped' as const };
          this.sessions.set(id, updated);
          this.emit('session:updated', updated);
        } else {
          const elapsed = now - this.stoppedAt.get(id)!;
          if (elapsed >= PHANTOM_TTL_MS) {
            this.sessions.delete(id);
            this.stoppedAt.delete(id);
            this.emit('session:removed', id);
          }
        }
      }
    }

    // Clean stoppedAt entries for sessions that reappear in scan
    for (const session of scanned) {
      if (this.stoppedAt.has(session.id)) {
        this.stoppedAt.delete(session.id);
      }
    }

    // Update or add sessions
    for (const session of scanned) {
      const existing = this.sessions.get(session.id);
      if (existing) {
        // Apply activity staleness: if currentActivity is too old, reset to idle
        let currentActivity = existing.currentActivity;
        if (
          currentActivity.type !== 'idle' &&
          now - currentActivity.since >= ACTIVITY_STALENESS_MS
        ) {
          currentActivity = { type: 'idle', since: now };
        }

        const merged: Session = {
          ...session,
          currentActivity,
          recentActivity: existing.recentActivity,
          taskInfo: { ...existing.taskInfo, ...session.taskInfo },
          dataSource: existing.dataSource === 'hooks' ? 'both' : session.dataSource,
        };
        this.sessions.set(session.id, merged);
        this.emit('session:updated', merged);
      } else {
        this.sessions.set(session.id, session);
        this.emit('session:updated', session);
      }
    }
  }

  updateActivity(pid: number, activity: {
    type: 'tool_use'; tool: string; toolInput: string; summary: string; timestamp: number;
  }): void {
    const id = String(pid);
    const existing = this.sessions.get(id);
    if (!existing) return;

    const newActivity: CurrentActivity = {
      type: activity.type,
      tool: activity.tool,
      toolInput: activity.toolInput,
      since: activity.timestamp,
    };

    const entry: ActivityEntry = {
      timestamp: activity.timestamp,
      type: activity.type,
      summary: activity.summary,
    };

    let recentActivity = [...existing.recentActivity, entry];
    if (recentActivity.length > MAX_RECENT_ACTIVITY) {
      recentActivity = recentActivity.slice(-MAX_RECENT_ACTIVITY);
    }

    const updated: Session = {
      ...existing,
      currentActivity: newActivity,
      recentActivity,
      dataSource: existing.dataSource === 'polling' ? 'polling' : 'both',
    };
    this.sessions.set(id, updated);
    this.emit('session:updated', updated);
  }

  updateTaskInfo(pid: number, taskInfo: Partial<TaskInfo>): void {
    const id = String(pid);
    const existing = this.sessions.get(id);
    if (!existing) return;
    const updated: Session = {
      ...existing,
      taskInfo: { ...existing.taskInfo, ...taskInfo },
    };
    this.sessions.set(id, updated);
    this.emit('session:updated', updated);
  }
}
