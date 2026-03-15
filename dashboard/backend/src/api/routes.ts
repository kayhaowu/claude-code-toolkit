import { Router } from 'express';
import type { SessionStore } from '../store/session-store.js';

export function createApiRouter(store: SessionStore): Router {
  const router = Router();

  router.get('/sessions', (_req, res) => {
    res.json(store.getAll());
  });

  return router;
}
