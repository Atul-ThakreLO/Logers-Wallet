#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# LogersWallet — Bootstrap Script
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "🔧 LogersWallet Setup"
echo "────────────────────────────────────────"

# Check prerequisites
command -v pnpm >/dev/null 2>&1 || { echo "❌ pnpm required. Install: npm i -g pnpm"; exit 1; }
command -v forge >/dev/null 2>&1 || { echo "❌ Foundry required. Install: curl -L https://foundry.paradigm.xyz | bash"; exit 1; }
command -v bun >/dev/null 2>&1 || { echo "❌ Bun required. Install: curl -fsSL https://bun.sh/install | bash"; exit 1; }

# Install JS dependencies
echo "📦 Installing pnpm dependencies..."
pnpm install

# Install Foundry dependencies
echo "⚒️  Installing Foundry libraries..."
cd contracts
forge install
cd ..

# Copy env file if not exists
if [ ! -f .env ]; then
  echo "📋 Creating .env from .env.example..."
  cp .env.example .env
  echo "⚠️  Edit .env with your actual values!"
fi

# Start local services
echo "🐳 Starting Docker services (PostgreSQL + Redis)..."
docker compose -f infra/docker/docker-compose.yml up -d

echo ""
echo "✅ Setup complete!"
echo "   Run 'pnpm dev' to start development."
