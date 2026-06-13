#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting LogersWallet dev stack..."

# Start infrastructure first
docker compose -f infra/docker/docker-compose.yml up -d postgres redis
echo "✅ Postgres + Redis running"

# Wait for postgres to be healthy
echo "⏳ Waiting for Postgres..."
until docker exec logers-postgres pg_isready -U logers -d logerswallet >/dev/null 2>&1; do
  sleep 1
done
echo "✅ Postgres ready"

# Run migrations
echo "🗄️  Running Prisma migrations..."
cd apps/api && bunx prisma db push --accept-data-loss && cd ../..

# Start all apps via Turbo
exec pnpm dev
