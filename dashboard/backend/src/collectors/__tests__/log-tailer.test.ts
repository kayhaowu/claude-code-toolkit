// packages/server/src/collectors/__tests__/log-tailer.test.ts
import { describe, it, expect } from 'vitest';
import { parseJsonlLine, findProjectSlugDir } from '../log-tailer.ts';

describe('parseJsonlLine', () => {
  it('extracts tool_use activity from assistant message', () => {
    const line = {
      type: 'assistant',
      message: {
        role: 'assistant',
        content: [
          {
            type: 'tool_use',
            name: 'Edit',
            input: { file_path: '/home/sonic/src/index.ts', old_string: 'a', new_string: 'b' },
          },
        ],
      },
      timestamp: '2026-03-10T07:58:49.112Z',
    };
    const result = parseJsonlLine(line);
    expect(result).toEqual({
      type: 'tool_use',
      tool: 'Edit',
      toolInput: '/home/sonic/src/index.ts',
      summary: 'Edit: /home/sonic/src/index.ts',
      timestamp: expect.any(Number),
    });
  });

  it('extracts Bash tool with command', () => {
    const line = {
      type: 'assistant',
      message: {
        role: 'assistant',
        content: [
          {
            type: 'tool_use',
            name: 'Bash',
            input: { command: 'ls -la /tmp', description: 'list temp files' },
          },
        ],
      },
      timestamp: '2026-03-10T08:00:00.000Z',
    };
    const result = parseJsonlLine(line);
    expect(result?.tool).toBe('Bash');
    expect(result?.toolInput).toBe('ls -la /tmp');
  });

  it('returns null for user messages', () => {
    const line = { type: 'user', message: { role: 'user', content: 'hello' } };
    expect(parseJsonlLine(line)).toBeNull();
  });
});

describe('findProjectSlugDir', () => {
  it('matches project dir against available slug dirs', () => {
    const slugDirs = [
      '-home-sonic-xcvr-cli-test-suite',
      '-home-sonic-claude-dev',
      '-home-sonic-ec-xcvr-tool-edgecore-xcvr-toolkit-web',
      '-home-sonic--claude-skills',
    ];
    expect(findProjectSlugDir('/home/sonic/xcvr-cli-test-suite', slugDirs))
      .toBe('-home-sonic-xcvr-cli-test-suite');
    expect(findProjectSlugDir('/home/sonic/.claude/skills', slugDirs))
      .toBe('-home-sonic--claude-skills');
  });

  it('returns null for unmatched project', () => {
    expect(findProjectSlugDir('/home/sonic/unknown', ['-home-sonic-claude-dev']))
      .toBeNull();
  });
});
