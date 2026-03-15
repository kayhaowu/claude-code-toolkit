import { describe, it, expect, beforeEach } from 'vitest';
import { useTerminalStore } from '../terminal-store.js';
import type { TerminalSession } from '@dashboard/types';

function makeSession(overrides: Record<string, unknown> = {}): TerminalSession {
  return {
    id: 'term-1',
    tmuxTarget: 'main:0.0',
    mode: 'attach',
    sessionPid: 1,
    title: 'session-1',
    status: 'connected',
    createdAt: Date.now(),
    ...overrides,
  } as TerminalSession;
}

describe('useTerminalStore', () => {
  beforeEach(() => {
    const store = useTerminalStore.getState();
    store.setSessions([]);
  });

  describe('sessions', () => {
    it('setSessions replaces all sessions', () => {
      const s1 = makeSession({ id: 'term-1' });
      const s2 = makeSession({ id: 'term-2' });
      useTerminalStore.getState().setSessions([s1, s2]);
      expect(useTerminalStore.getState().sessions.size).toBe(2);
    });

    it('addSession upserts a session', () => {
      const s = makeSession({ id: 'term-1' });
      useTerminalStore.getState().addSession(s);
      expect(useTerminalStore.getState().sessions.get('term-1')).toEqual(s);
    });

    it('removeSession deletes a session', () => {
      const s = makeSession({ id: 'term-1' });
      useTerminalStore.getState().addSession(s);
      useTerminalStore.getState().removeSession('term-1');
      expect(useTerminalStore.getState().sessions.has('term-1')).toBe(false);
    });
  });

  describe('layout — splitPane', () => {
    it('splits a single terminal pane horizontally', () => {
      const { splitPane } = useTerminalStore.getState();
      useTerminalStore.getState().addSession(makeSession({ id: 's1' }));
      useTerminalStore.setState({
        layout: { type: 'terminal', paneId: 'p1', sessionId: 's1' },
        activePaneId: 'p1',
      });

      splitPane('p1', 'horizontal', 's2');

      const layout = useTerminalStore.getState().layout;
      expect(layout).not.toBeNull();
      expect(layout!.type).toBe('split');
      if (layout!.type === 'split') {
        expect(layout!.direction).toBe('horizontal');
        expect(layout!.ratio).toBe(0.5);
        expect(layout!.splitId).toBeTruthy();
        expect(layout!.children[0]).toEqual({ type: 'terminal', paneId: 'p1', sessionId: 's1' });
        expect(layout!.children[1].type).toBe('terminal');
        if (layout!.children[1].type === 'terminal') {
          expect(layout!.children[1].sessionId).toBe('s2');
        }
      }
    });
  });

  describe('layout — closePane', () => {
    it('closing one child of a split returns the other child', () => {
      useTerminalStore.setState({
        layout: {
          type: 'split',
          splitId: 'test-split-1',
          direction: 'horizontal',
          ratio: 0.5,
          children: [
            { type: 'terminal', paneId: 'p1', sessionId: 's1' },
            { type: 'terminal', paneId: 'p2', sessionId: 's2' },
          ],
        },
        activePaneId: 'p1',
        sessions: new Map(),
      });

      useTerminalStore.getState().closePane('p1');

      const layout = useTerminalStore.getState().layout;
      expect(layout).toEqual({ type: 'terminal', paneId: 'p2', sessionId: 's2' });
    });

    it('closing the only pane sets layout to null', () => {
      useTerminalStore.setState({
        layout: { type: 'terminal', paneId: 'p1', sessionId: 's1' },
        activePaneId: 'p1',
        sessions: new Map(),
      });

      useTerminalStore.getState().closePane('p1');
      expect(useTerminalStore.getState().layout).toBeNull();
    });
  });

  describe('layout — resizePane', () => {
    it('updates the ratio of a split by splitId', () => {
      useTerminalStore.setState({
        layout: {
          type: 'split',
          splitId: 'test-split-1',
          direction: 'horizontal',
          ratio: 0.5,
          children: [
            { type: 'terminal', paneId: 'p1', sessionId: 's1' },
            { type: 'terminal', paneId: 'p2', sessionId: 's2' },
          ],
        },
        activePaneId: 'p1',
        sessions: new Map(),
      });

      useTerminalStore.getState().resizePane('test-split-1', 0.7);

      const layout = useTerminalStore.getState().layout;
      if (layout?.type === 'split') {
        expect(layout.ratio).toBe(0.7);
      }
    });

    it('correctly resizes nested splits without ambiguity', () => {
      useTerminalStore.setState({
        layout: {
          type: 'split',
          splitId: 'outer',
          direction: 'horizontal',
          ratio: 0.5,
          children: [
            {
              type: 'split',
              splitId: 'inner',
              direction: 'vertical',
              ratio: 0.5,
              children: [
                { type: 'terminal', paneId: 'p1', sessionId: 's1' },
                { type: 'terminal', paneId: 'p2', sessionId: 's2' },
              ],
            },
            { type: 'terminal', paneId: 'p3', sessionId: 's3' },
          ],
        },
        activePaneId: 'p1',
        sessions: new Map(),
      });

      // Resize inner split — should NOT affect outer
      useTerminalStore.getState().resizePane('inner', 0.3);

      const layout = useTerminalStore.getState().layout;
      expect(layout?.type).toBe('split');
      if (layout?.type === 'split') {
        expect(layout.ratio).toBe(0.5); // outer unchanged
        expect(layout.children[0].type).toBe('split');
        if (layout.children[0].type === 'split') {
          expect(layout.children[0].ratio).toBe(0.3); // inner changed
        }
      }
    });
  });

  describe('openPane', () => {
    beforeEach(() => {
      useTerminalStore.setState({ layout: null, activePaneId: null });
    });

    it('creates initial layout when no layout exists', () => {
      useTerminalStore.getState().openPane('sess-1');

      const { layout, activePaneId } = useTerminalStore.getState();
      expect(layout).not.toBeNull();
      expect(layout?.type).toBe('terminal');
      if (layout?.type === 'terminal') {
        expect(layout.sessionId).toBe('sess-1');
        expect(activePaneId).toBe(layout.paneId);
      }
    });

    it('splits existing layout when layout already exists', () => {
      // First pane
      useTerminalStore.getState().openPane('sess-1');
      const firstLayout = useTerminalStore.getState().layout;
      expect(firstLayout?.type).toBe('terminal');

      // Second pane — should split
      useTerminalStore.getState().openPane('sess-2');
      const { layout } = useTerminalStore.getState();
      expect(layout?.type).toBe('split');
      if (layout?.type === 'split') {
        expect(layout.direction).toBe('horizontal');
        expect(layout.children[0].type).toBe('terminal');
        expect(layout.children[1].type).toBe('terminal');
        if (layout.children[0].type === 'terminal' && layout.children[1].type === 'terminal') {
          expect(layout.children[0].sessionId).toBe('sess-1');
          expect(layout.children[1].sessionId).toBe('sess-2');
        }
      }
    });
  });

  describe('replacePaneSession', () => {
    beforeEach(() => {
      useTerminalStore.setState({ layout: null, activePaneId: null });
    });

    it('replaces sessionId in a single terminal layout', () => {
      useTerminalStore.getState().openPane('pending-123');
      useTerminalStore.getState().replacePaneSession('pending-123', 'real-abc');

      const { layout } = useTerminalStore.getState();
      expect(layout?.type).toBe('terminal');
      if (layout?.type === 'terminal') {
        expect(layout.sessionId).toBe('real-abc');
      }
    });

    it('replaces sessionId in a split layout', () => {
      useTerminalStore.getState().openPane('sess-1');
      useTerminalStore.getState().openPane('pending-456');
      useTerminalStore.getState().replacePaneSession('pending-456', 'real-def');

      const { layout } = useTerminalStore.getState();
      expect(layout?.type).toBe('split');
      if (layout?.type === 'split') {
        const second = layout.children[1];
        expect(second.type).toBe('terminal');
        if (second.type === 'terminal') {
          expect(second.sessionId).toBe('real-def');
        }
      }
    });

    it('does nothing when oldSessionId not found', () => {
      useTerminalStore.getState().openPane('sess-1');
      const before = useTerminalStore.getState().layout;

      useTerminalStore.getState().replacePaneSession('nonexistent', 'new-id');

      const after = useTerminalStore.getState().layout;
      expect(after).toEqual(before);
    });
  });
});
