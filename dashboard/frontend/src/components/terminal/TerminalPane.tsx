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
        // Catppuccin Mocha palette
        background: '#1e1e2e',
        foreground: '#cdd6f4',
        cursor: '#f5e0dc',
        cursorAccent: '#1e1e2e',
        selectionBackground: '#585b70',
        selectionForeground: '#cdd6f4',
        black: '#45475a',
        red: '#f38ba8',
        green: '#a6e3a1',
        yellow: '#f9e2af',
        blue: '#89b4fa',
        magenta: '#f5c2e7',
        cyan: '#94e2d5',
        white: '#bac2de',
        brightBlack: '#585b70',
        brightRed: '#f38ba8',
        brightGreen: '#a6e3a1',
        brightYellow: '#f9e2af',
        brightBlue: '#89b4fa',
        brightMagenta: '#f5c2e7',
        brightCyan: '#94e2d5',
        brightWhite: '#a6adc8',
      },
      fontFamily: '"JetBrainsMono Nerd Font", "JetBrains Mono", "Fira Code", "Cascadia Code", monospace',
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
