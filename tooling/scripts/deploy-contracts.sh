#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# LogersWallet — Contract Deployment Script
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "🚀 Deploying LogersWallet contracts to Base Sepolia..."
echo "────────────────────────────────────────"

# Load env
if [ -f .env ]; then
  source .env
fi

# Validate
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"
: "${BASE_SEPOLIA_RPC_URL:?BASE_SEPOLIA_RPC_URL not set}"

cd contracts

# Deploy (script populated in Phase 2)
echo "⚠️  Deploy script not yet implemented. See Phase 2."
# forge script script/Deploy.s.sol:DeployScript \
#   --rpc-url "$BASE_SEPOLIA_RPC_URL" \
#   --private-key "$PRIVATE_KEY" \
#   --broadcast \
#   --verify

echo "Done."
