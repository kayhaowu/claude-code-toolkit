import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@dashboard/types': path.resolve(__dirname, '../types/src'),
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: [],
  },
});
