import { create } from 'zustand';

interface ConnectionState {
  connected: boolean;
  error: string | null;
  setConnected: (connected: boolean) => void;
  setError: (error: string | null) => void;
}

export const useConnectionStore = create<ConnectionState>((set) => ({
  connected: false,
  error: null,
  setConnected: (connected) => set((state) => ({
    connected,
    error: connected ? null : state.error,
  })),
  setError: (error) => set({ error }),
}));
