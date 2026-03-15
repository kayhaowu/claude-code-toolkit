FROM node:18-slim

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Install backend dependencies
COPY backend/package.json backend/pnpm-lock.yaml ./backend/
RUN cd backend && pnpm install --frozen-lockfile

# Install frontend dependencies
COPY frontend/package.json frontend/pnpm-lock.yaml ./frontend/
RUN cd frontend && pnpm install --frozen-lockfile

# Copy source
COPY types/ ./types/
COPY backend/ ./backend/
COPY frontend/ ./frontend/

# Build frontend
RUN cd frontend && pnpm build

EXPOSE 3141

CMD ["npx", "tsx", "backend/src/index.ts"]
