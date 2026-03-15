FROM node:18-slim

RUN corepack enable && corepack prepare pnpm@9.15.0 --activate

RUN apt-get update && apt-get install -y tmux python3 make g++ && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy shared tsconfig
COPY tsconfig.base.json ./

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

CMD ["/app/backend/node_modules/.bin/tsx", "backend/src/index.ts"]
