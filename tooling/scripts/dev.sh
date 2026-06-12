#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# LogersWallet — Dev Server Launcher
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "🚀 Starting LogersWallet development environment..."
echo "────────────────────────────────────────"

# Ensure Docker services are running
echo "🐳 Checking Docker services..."
docker compose -f infra/docker/docker-compose.yml up -d

# Start turbo dev (all apps in parallel)
echo "⚡ Starting all apps..."
pnpm dev
