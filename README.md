# LogersWallet

> Production-grade ERC-4337 smart wallet with WebAuthn/Passkey authentication, dual paymaster (ETH + ERC-20), and multi-owner governance.

**Chain**: Base Sepolia (84532) | **Standard**: ERC-4337 v0.7

## ✨ Features

- 🔐 **WebAuthn / Passkey** — No seed phrases, no private keys exposed
- 👥 **Multi-Owner** — Add/remove passkey owners per device
- 🔄 **UUPS Upgradeable** — Deterministic CREATE2 deployment
- ⛽ **Dual Paymaster** — Gas sponsorship in ETH or any whitelisted ERC-20
- 📊 **Price Oracle** — Chainlink-based ERC-20 → ETH conversion
- 📱 **QR Signing** — Cross-device mobile signing flow
- 📈 **The Graph** — Real-time on-chain event indexing

## 🏗️ Architecture

```
apps/web      → Next.js 14 dApp frontend
apps/api      → Elysia + Bun backend
contracts/    → Foundry smart contracts
sdk/          → Shared TypeScript SDK
subgraph/     → The Graph indexing
packages/     → Shared configs & utilities
```

## 🚀 Quick Start

```bash
# Prerequisites: Node.js 24+, pnpm, Foundry, Bun, Docker

# Clone and setup
git clone <repo-url> && cd logers-wallet
make setup

# Start development
make dev
```

## 📋 Development

```bash
make install          # Install dependencies
make dev              # Start all dev servers
make build            # Build all packages
make lint             # Lint all packages
make fmt              # Format all files
make contracts-build  # Build Solidity contracts
make contracts-test   # Run Foundry tests
make docker-up        # Start PostgreSQL + Redis
make docker-down      # Stop Docker services
```

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Smart Contracts | Solidity ^0.8.25, Foundry, OpenZeppelin v5 |
| Frontend | Next.js 14, React 19, Framer Motion |
| Backend | Elysia, Bun, Prisma, PostgreSQL |
| Chain Interaction | viem, wagmi |
| Authentication | WebAuthn, @simplewebauthn |
| Indexing | The Graph |
| Bundler | Pimlico |
| CI/CD | GitHub Actions, Docker |

## 📄 License

MIT
