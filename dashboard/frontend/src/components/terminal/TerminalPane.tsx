import { useEffect, useRef, useCallback } from 'react';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import '@xterm/xterm/css/xterm.css';
import { acquireSocket, releaseSocket } from '../../hooks/socket.js';
import { useTerminalStore } from '../../store/terminal-store.js';

interface TerminalPaneProps {
  paneId: string;
  sessionId: string;
  onContextMenu: (e: React.MouseEvent, paneId: string) => void;
}

export function TerminalPane({ paneId, sessionId, onContextMenu }: TerminalPaneProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const termRef = useRef<Terminal | null>(null);
  const fitRef = useRef<FitAddon | null>(null);
  const setActivePane = useTerminalStore((s) => s.setActivePane);

  useEffect(() => {
    if (!containerRef.current) return;

    const socket = acquireSocket();
    const term = new Terminal({
      scrollback: 5000,
      theme: {
        background: '#111827',
        foreground: '#d1d5db',
        cursor: '#d1d5db',
      },
      fontFamily: 'monospace',
      fontSize: 14,
    });
    const fit = new FitAddon();
    term.loadAddon(fit);
    term.open(containerRef.current);
    fit.fit();

    termRef.current = term;
    fitRef.current = fit;

    // Binary output from server
    const outputEvent = `terminal:output:${sessionId}`;
    const onOutput = (data: ArrayBuffer | string) => {
      if (data instanceof ArrayBuffer) {
        term.write(new Uint8Array(data));
      } else {
        term.write(data);
      }
    };
    socket.on(outputEvent, onOutput);

    // Input to server
    const dataDisposable = term.onData((data: string) => {
      socket.emit('terminal:input', { sessionId, data });
    });

    // Resize handling (debounced)
    let resizeTimer: ReturnType<typeof setTimeout>;
    const observer = new ResizeObserver(() => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => {
        fit.fit();
        socket.emit('terminal:resize', {
          sessionId,
          cols: term.cols,
          rows: term.rows,
        });
      }, 100);
    });
    observer.observe(containerRef.current);

    return () => {
      observer.disconnect();
      clearTimeout(resizeTimer);
      socket.off(outputEvent, onOutput);
      dataDisposable.dispose();
      term.dispose();
      releaseSocket();
    };
  }, [sessionId]);

  const handleContextMenu = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      onContextMenu(e, paneId);
    },
    [paneId, onContextMenu],
  );

  const handleFocus = useCallback(() => {
    setActivePane(paneId);
  }, [paneId, setActivePane]);

  return (
    <div
      ref={containerRef}
      className="h-full w-full"
      onContextMenu={handleContextMenu}
      onFocus={handleFocus}
      onClick={handleFocus}
    />
  );
}
