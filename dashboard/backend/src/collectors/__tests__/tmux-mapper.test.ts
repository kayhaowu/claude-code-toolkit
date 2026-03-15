import { describe, it, expect } from 'vitest';
import { parseTmuxOutput, mapPidToTmux } from '../tmux-mapper.ts';

describe('parseTmuxOutput', () => {
  it('parses tmux list-panes output into a tty map', () => {
    const output = [
      '0:0:cli-test /dev/pts/6 1371716',
      '0:1:k8s /dev/pts/13 992033',
      '0:2:edgecore-xcvr-tool /dev/pts/7 3036720',
      '0:2:edgecore-xcvr-tool /dev/pts/0 1911663',
    ].join('\n');

    const result = parseTmuxOutput(output);
    expect(result.get('/dev/pts/6')).toEqual({
      session: '0',
      window: '0',
      windowName: 'cli-test',
      pane: '0',
      tty: '/dev/pts/6',
    });
    expect(result.get('/dev/pts/7')).toEqual({
      session: '0',
      window: '2',
      windowName: 'edgecore-xcvr-tool',
      pane: '0',
      tty: '/dev/pts/7',
    });
    // second pane in same window
    expect(result.get('/dev/pts/0')).toEqual({
      session: '0',
      window: '2',
      windowName: 'edgecore-xcvr-tool',
      pane: '1',
      tty: '/dev/pts/0',
    });
  });
});

describe('mapPidToTmux', () => {
  it('returns null for unknown tty', () => {
    const tmuxMap = new Map();
    const result = mapPidToTmux(99999, tmuxMap, () => null);
    expect(result).toBeNull();
  });

  it('maps pid to tmux info via tty lookup', () => {
    const tmuxMap = new Map([
      ['/dev/pts/6', { session: '0', window: '0', windowName: 'cli-test', pane: '0', tty: '/dev/pts/6' }],
    ]);
    const result = mapPidToTmux(446521, tmuxMap, () => '/dev/pts/6');
    expect(result).toEqual({
      session: '0',
      window: '0',
      windowName: 'cli-test',
      pane: '0',
      tty: '/dev/pts/6',
    });
  });
});
