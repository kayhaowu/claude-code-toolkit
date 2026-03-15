import { defineConfig } from 'vitest/config';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  resolve: {
    alias: {
      '@dashboard/types': resolve(__dirname, '../types/src/index.ts'),
    },
  },
  test: {
    server: {
      fs: {
        allow: ['..'],
      },
    },
  },
});
