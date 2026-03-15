import express from 'express';
import { createServer } from 'node:http';
import { Server as SocketIO } from 'socket.io';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';
import { SessionStore } from './store/session-store.js';
import { scanSessions } from './collectors/session-scanner.js';
import { LogTailer } from './collectors/log-tailer.js';
import { createHookRouter } from './collectors/hook-receiver.js';
import { createApiRouter } from './api/routes.js';
import { SCAN_INTERVAL_MS } from '../../types/src/index.js';
import { TerminalManager } from './terminal/terminal-manager.js';

const PORT = parseInt(process.env.PORT ?? '3141', 10);
const HOST = process.env.HOST ?? '127.0.0.1';
const app = express();
const http = createServer(app);
const io = new SocketIO(http, {
  cors: { origin: [`http://127.0.0.1:${PORT}`, `http://localhost:${PORT}`] },
});

const __dirname = dirname(fileURLToPath(import.meta.url));

app.use(express.json());

const store = new SessionStore();
const logTailer = new LogTailer();
const terminalManager = new TerminalManager(store);

// API routes
app.use('/api', createApiRouter(store));
app.use('/api/hooks', createHookRouter(store));

// Static file serving for production
const staticDir = join(__dirname, '../../frontend/dist');
if (existsSync(staticDir)) {
  app.use(express.static(staticDir));
  app.get('*', (_req, res) => {
    res.sendFile(join(staticDir, 'index.html'));
  });
}

// WebSocket
io.on('connection', (socket) => {
  socket.emit('sessions:snapshot', { type: 'sessions:snapshot', sessions: store.getAll() });

  // ── Terminal ──
  socket.emit('terminal:sessions', {
    type: 'terminal:sessions',
    sessions: terminalManager.getBySocket(socket.id),
  });

  socket.on('terminal:open', async (payload: any) => {
    try {
      const session = await terminalManager.open(socket.id, payload);
      socket.emit('terminal:opened', { type: 'terminal:opened', session });
    } catch (err: any) {
      socket.emit('terminal:error', {
        type: 'terminal:error',
        message: err.message,
      });
    }
  });

  socket.on('terminal:input', ({ sessionId, data }: any) => {
    try {
      terminalManager.write(sessionId, socket.id, data);
    } catch (err: any) {
      console.error(`[terminal:input] session=${sessionId}:`, err.message);
    }
  });

  socket.on('terminal:resize', ({ sessionId, cols, rows }: any) => {
    try {
      terminalManager.resize(sessionId, socket.id, cols, rows);
    } catch (err: any) {
      console.error(`[terminal:resize] session=${sessionId}:`, err.message);
    }
  });

  socket.on('terminal:close', ({ sessionId }: any) => {
    try {
      terminalManager.close(sessionId, socket.id);
      socket.emit('terminal:closed', { type: 'terminal:closed', sessionId });
    } catch (err: any) {
      console.error(`[terminal:close] session=${sessionId}:`, err.message);
      socket.emit('terminal:error', { type: 'terminal:error', message: err.message });
    }
  });

  socket.on('terminal:reconnect', ({ sessionIds }: any) => {
    const { lost } = terminalManager.handleReconnect(socket.id, sessionIds);
    for (const sessionId of lost) {
      socket.emit('terminal:closed', { type: 'terminal:closed', sessionId });
    }
    socket.emit('terminal:sessions', {
      type: 'terminal:sessions',
      sessions: terminalManager.getBySocket(socket.id),
    });
  });

  socket.on('disconnect', () => {
    terminalManager.handleDisconnect(socket.id);
  });
});

// Terminal binary output — scoped to owning socket
terminalManager.on('output', ({ sessionId, socketId, data }: any) => {
  io.to(socketId).emit(`terminal:output:${sessionId}`, data);
});

// Notify client when PTY exits
terminalManager.on('exited', ({ sessionId, socketId }: any) => {
  io.to(socketId).emit('terminal:closed', { type: 'terminal:closed', sessionId });
});

// Cleanup terminal PTYs on shutdown
process.on('SIGTERM', () => terminalManager.stopAll());
process.on('SIGINT', () => terminalManager.stopAll());

store.on('session:updated', (session) => {
  io.emit('session:updated', { type: 'session:updated', session });
});

store.on('session:removed', (id) => {
  io.emit('session:removed', { type: 'session:removed', id });
});

// LogTailer events
logTailer.on('activity', ({ pid, activity }) => {
  store.updateActivity(pid, activity);
});

logTailer.on('taskInfo', ({ pid, ...info }) => {
  store.updateTaskInfo(pid, info);
});

logTailer.on('file-rotated', ({ pid }) => {
  console.log(`JSONL rotated for PID ${pid}, will re-tail on next scan`);
});

// Scan loop
async function scanLoop() {
  try {
    const sessions = await scanSessions();
    store.updateFromScan(sessions);

    for (const session of sessions) {
      if (session.status !== 'stopped' && !logTailer.isTailing(session.pid)) {
        logTailer.startTailing(session.pid, session.projectDir);
      }
    }
  } catch (err) {
    console.error('Scan error:', err);
  }
}

setInterval(scanLoop, SCAN_INTERVAL_MS);
scanLoop();

http.listen(PORT, HOST, () => {
  console.log(`Dashboard server listening on http://${HOST}:${PORT}`);
});
