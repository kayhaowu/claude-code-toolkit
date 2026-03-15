import { describe, it, expect } from 'vitest';
import { extractTaskInfo } from '../log-tailer.js';

describe('extractTaskInfo', () => {
  it('extracts taskSubject from TaskCreate tool use', () => {
    const parsed = {
      type: 'assistant',
      message: {
        content: [{
          type: 'tool_use',
          name: 'TaskCreate',
          input: { subject: 'Implement login page' }
        }]
      }
    };
    expect(extractTaskInfo(parsed)).toEqual({ taskSubject: 'Implement login page' });
  });

  it('extracts taskSubject from TaskUpdate with subject', () => {
    const parsed = {
      type: 'assistant',
      message: {
        content: [{
          type: 'tool_use',
          name: 'TaskUpdate',
          input: { taskId: '1', status: 'completed', subject: 'Updated task' }
        }]
      }
    };
    expect(extractTaskInfo(parsed)).toEqual({ taskSubject: 'Updated task' });
  });

  it('returns null for TaskUpdate without subject', () => {
    const parsed = {
      type: 'assistant',
      message: {
        content: [{
          type: 'tool_use',
          name: 'TaskUpdate',
          input: { taskId: '1', status: 'completed' }
        }]
      }
    };
    expect(extractTaskInfo(parsed)).toBeNull();
  });

  it('extracts commitMessage from git commit result', () => {
    const parsed = {
      type: 'result',
      result: '[main abc1234] feat: add login page'
    };
    expect(extractTaskInfo(parsed)).toEqual({ commitMessage: 'feat: add login page' });
  });

  it('extracts commitMessage from branch with slashes', () => {
    const parsed = {
      type: 'result',
      result: '[feat/auth abc1234] fix: auth token refresh'
    };
    expect(extractTaskInfo(parsed)).toEqual({ commitMessage: 'fix: auth token refresh' });
  });

  it('returns null for non-matching result', () => {
    const parsed = {
      type: 'result',
      result: 'some random output'
    };
    expect(extractTaskInfo(parsed)).toBeNull();
  });

  it('returns null for user messages', () => {
    const parsed = {
      type: 'user',
      message: { content: 'hello' }
    };
    expect(extractTaskInfo(parsed)).toBeNull();
  });

  it('returns null for assistant message without tool use', () => {
    const parsed = {
      type: 'assistant',
      message: {
        content: [{ type: 'text', text: 'Hello' }]
      }
    };
    expect(extractTaskInfo(parsed)).toBeNull();
  });
});
