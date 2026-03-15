import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@dashboard/types': path.resolve(__dirname, '../types/src'),
    },
  },
  server: {
    host: '127.0.0.1',
    port: 3000,
    proxy: {
      '/api': 'http://127.0.0.1:3141',
      '/socket.io': { target: 'http://127.0.0.1:3141', ws: true },
    },
  },
});
