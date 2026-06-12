# LogersWallet API — Bun Runtime
FROM oven/bun:1-alpine AS base

WORKDIR /app

# Install dependencies
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile

# Copy source
COPY src/ ./src/

# Run
EXPOSE 4000
CMD ["bun", "run", "src/index.ts"]
