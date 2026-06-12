# LogersWallet — Master Architecture & Execution Overview

> Senior System Designer Reference Document
> Read this before executing ANY phase prompt. Every phase references back here.
> Version: 1.0.0 | Chain: Base Sepolia | Standard: ERC-4337 v0.7

---

## 🗺️ Project Identity

**LogersWallet** is a production-grade, ERC-4337 smart wallet with:
- WebAuthn / Passkey-based authentication (no seed phrases, no private keys exposed)
- Multi-owner governance on-chain (add/remove passkey owners per device)
- UUPS upgradeable smart accounts deployed via deterministic CREATE2 factory
- **Dual Paymaster**: sponsors gas in native ETH *or* any whitelisted ERC-20 token
- **On-chain Price Oracle**: Chainlink-based oracle for ERC-20 → ETH gas conversion
- QR-based mobile passkey creation and transaction signing flow
- Beautiful, interactive web frontend (Next.js 14 App Router)
- Elysia + Bun backend for off-chain orchestration and bundler relay
- The Graph for real-time on-chain event indexing
- Base Sepolia testnet (EIP-7212 P-256 precompile available)

---

## 📦 Monorepo Structure

```
logers-wallet/                              ← pnpm workspace root
│
├── apps/
│   ├── web/                               ← Next.js 14 dApp frontend
│   ├── api/                               ← Elysia + Bun backend
│   └── docs/                              ← Nextra documentation site
│
├── packages/
│   ├── contracts-abi/                     ← Generated ABIs + TS types (from contracts/)
│   ├── ui/                                ← Shared React component library (shadcn base)
│   ├── wagmi-config/                      ← Shared wagmi/viem chain + client config
│   ├── typescript-config/                 ← Shared tsconfig bases
│   ├── eslint-config/                     ← Shared ESLint + Biome rules
│   └── utils/                             ← Shared utility functions (formatting, crypto)
│
├── contracts/                             ← Foundry project root
│   ├── src/
│   │   ├── LogersAccount.sol
│   │   ├── LogersAccountFactory.sol
│   │   ├── LogersPaymaster.sol            ← Dual paymaster (ETH + ERC-20)
│   │   ├── oracle/
│   │   │   └── LogersPriceOracle.sol      ← Chainlink-based price oracle
│   │   ├── validators/
│   │   │   └── WebAuthnValidator.sol
│   │   ├── interfaces/
│   │   │   ├── ILogersAccount.sol
│   │   │   ├── ILogersPaymaster.sol
│   │   │   └── ILogersPriceOracle.sol
│   │   └── libraries/
│   │       ├── WebAuthnLib.sol
│   │       └── UserOperationLib.sol
│   ├── test/
│   ├── script/
│   ├── lib/
│   └── foundry.toml
│
├── subgraph/                              ← The Graph indexing
│   ├── src/
│   │   ├── factory.ts
│   │   ├── account.ts
│   │   └── paymaster.ts
│   ├── abis/
│   ├── schema.graphql
│   └── subgraph.yaml
│
├── sdk/                                   ← Shared TypeScript SDK (consumed by apps/)
│   └── src/
│       ├── abi/                           ← re-exports from packages/contracts-abi
│       ├── passkey/
│       ├── chain/
│       ├── graph/
│       └── index.ts
│
├── infra/
│   ├── docker/
│   │   ├── docker-compose.yml
│   │   ├── docker-compose.prod.yml
│   │   ├── api/Dockerfile
│   │   └── web/Dockerfile
│   └── nginx/
│       └── nginx.conf
│
├── tooling/
│   ├── github/
│   │   └── workflows/
│   │       └── ci.yml
│   └── scripts/
│       ├── setup.sh
│       ├── deploy-contracts.sh
│       └── dev.sh
│
├── .changeset/
│   └── config.json
├── .env.example
├── .gitignore
├── .nvmrc
├── .tool-versions
├── turbo.json
├── pnpm-workspace.yaml
├── package.json
├── Makefile
└── README.md
```

---

## 🏗️ System Architecture

### Layer 1 — Smart Contracts (Foundry, Base Sepolia)

```
EntryPoint v0.7 (ERC-4337 canonical — already deployed)
    │
    ├── LogersAccountFactory
    │       └── CREATE2 deploy of LogersAccount proxy per passkey public key
    │
    ├── LogersAccount (UUPS Upgradeable)
    │       ├── MultiOwnable         — add/remove passkey owners
    │       ├── WebAuthnLib          — P-256 secp256r1 signature verification
    │       ├── ERC1271              — isValidSignature for off-chain signing
    │       └── UUPSUpgradeable      — upgrade guarded by owner
    │
    ├── LogersPaymaster (Dual: ETH + ERC-20)
    │       ├── Mode 0: Native ETH   — backend co-signs, covers ETH gas directly
    │       ├── Mode 1: ERC-20 Token — user pays in token, oracle converts to ETH
    │       └── LogersPriceOracle    — Chainlink aggregator for token/ETH price
    │
    └── LogersPriceOracle
            ├── Chainlink AggregatorV3Interface per token
            ├── staleness check (max 1 hour)
            └── owner-managed token feed registry
```

### Layer 2 — Backend (Elysia + Bun)

```
apps/api/src/
 ├── /passkey/challenge          → generate registration/auth challenges
 ├── /passkey/register           → verify attestation, store pubkey, predict address
 ├── /passkey/authenticate       → verify assertion, issue JWT session cookie
 ├── /account/predict            → return CREATE2 address before deployment
 ├── /account/:address/balance   → native + token balances
 ├── /userop/build               → construct UserOperation from intent
 ├── /userop/sponsor             → Paymaster co-signs (ETH or ERC-20 mode)
 ├── /userop/sign/:sessionId     → mobile posts WebAuthn signature
 ├── /userop/session/:sessionId  → frontend polls sign status
 ├── /userop/submit/:sessionId   → submit signed UserOp to Pimlico bundler
 ├── /tokens/supported           → list of whitelisted ERC-20 tokens
 └── /graph/account/:address     → proxy subgraph query
```

### Layer 3 — Frontend (Next.js 14)

```
apps/web/src/app/
 ├── /                           → landing page (animated)
 ├── /create                     → passkey registration + QR cross-device flow
 ├── /wallet                     → main dashboard (balance, activity, quick actions)
 ├── /wallet/send                → send ETH or tokens
 ├── /wallet/activity            → full transaction history (The Graph)
 ├── /wallet/owners              → multi-owner passkey management
 ├── /wallet/settings            → upgrade, preferences
 └── /sign/[sessionId]           → mobile QR signing page
```

### Layer 4 — Indexing (The Graph)

```
subgraph/
 ├── AccountDeployed             → all LogersAccount deployments
 ├── OwnerAdded / OwnerRemoved   → owner changes per account
 ├── ExecutedTransaction         → all ops per account
 ├── SponsoredWithETH            → native gas sponsorships
 └── SponsoredWithToken          → ERC-20 gas payments (token, amount, ethValue)
```

---

## 🔐 Dual Paymaster Architecture

This is the core addition vs the base design. The paymaster supports two modes, selected by the frontend per UserOp:

```
paymasterAndData layout:
 [0:20]    paymaster address
 [20:21]   mode (0x00 = ETH, 0x01 = ERC-20)
 [21:41]   token address (zero address if mode=0)
 [41:47]   validUntil (uint48)
 [47:53]   validAfter (uint48)
 [53:118]  ECDSA signature (65 bytes)
```

### Mode 0 — Native ETH Sponsorship
- Backend operator signs the UserOp hash
- Paymaster covers gas from its EntryPoint deposit
- No token interaction

### Mode 1 — ERC-20 Token Payment
```
Flow:
  1. Frontend selects token (e.g. USDC)
  2. Backend queries LogersPriceOracle.getEthAmount(token, gasEstimate)
  3. Backend calculates maxTokenCost = gasEstimate × (tokenPerEth + 10% buffer)
  4. Backend signs paymasterAndData with mode=1 + token address
  5. Paymaster _validatePaymasterUserOp:
       a. Reads tokenAmount from paymasterAndData
       b. Calls oracle.getTokenAmount(token, maxCost) → required token units
       c. Checks user has approved ≥ tokenAmount
  6. Paymaster _postOp:
       a. Calls transferFrom(user, paymaster, actualTokenCost)
       b. Paymaster covers ETH gas from deposit
       c. Emits SponsoredWithToken(account, token, tokenAmount, ethCost)
```

### Price Oracle Flow
```
LogersPriceOracle
  ├── addFeed(token, chainlinkAggregator)  ← owner only
  ├── getTokenAmount(token, ethWei)         → how many tokens = X ETH
  ├── getEthAmount(token, tokenUnits)       → how much ETH = X tokens
  └── latestPrice(token)                   → raw price + staleness check
```

---

## 🔗 Package Dependency Graph

```
contracts/          ──(forge build → JSON ABIs)──▶  packages/contracts-abi/
packages/contracts-abi/ ──────────────────────────▶  sdk/
subgraph/           ──(schema types)──────────────▶  sdk/
sdk/                ──────────────────────────────▶  apps/web/
sdk/                ──────────────────────────────▶  apps/api/
packages/ui/        ──────────────────────────────▶  apps/web/
packages/wagmi-config/ ───────────────────────────▶  apps/web/
packages/utils/     ──────────────────────────────▶  apps/web/ + apps/api/
```

---

## 📋 Execution Phases

| Phase | File | Focus |
|-------|------|-------|
| 0 | `00_MASTER_OVERVIEW.md` | Architecture bible (this file) |
| 1 | `01_MONOREPO_SETUP.md` | Scaffold, workspace, tooling, all package.json files |
| 2 | `02_CONTRACTS.md` | All Solidity: Account, Factory, Oracle, Dual Paymaster + tests |
| 3 | `03_CONTRACTS_ABI_PACKAGE.md` | ABI extraction + TS codegen into packages/contracts-abi |
| 4 | `04_SDK.md` | sdk/ package: passkey, chain, userop, graph queries |
| 5 | `05_BACKEND_API.md` | Elysia API: passkey, userop, token, bundler, paymaster signer |
| 6 | `06_SUBGRAPH.md` | The Graph: schema, handlers, dual paymaster events |
| 7 | `07_FRONTEND_CORE.md` | Next.js shell: routing, state, wagmi, hooks, providers |
| 8 | `08_FRONTEND_UI.md` | Wallet UI: all screens, components, animations |
| 9 | `09_INFRA_DEVOPS.md` | Docker, Nginx, CI, Makefile, deploy scripts |

---

## ⚙️ Key Technical Decisions

### Why split contracts-abi into its own package?
- `contracts/` is a Foundry project (pure Solidity). It should not import from JS packages.
- After `forge build`, a script copies `out/*.json` ABIs into `packages/contracts-abi/src/`.
- This gives type-safe ABI imports in TS without circular deps.

### Why a separate `sdk/` directory (not under packages/)?
- The SDK is a heavier package with viem, @simplewebauthn, zod dependencies.
- Keeping it at root level (not nested in packages/) avoids confusion with lighter packages.
- `packages/` contains pure config/utility packages with minimal dependencies.

### Why Chainlink for price oracle (not Uniswap TWAP)?
- Chainlink is available on Base Sepolia with real price feeds
- TWAP manipulation risk is non-trivial for paymaster (attacker could drain)
- Chainlink has staleness checks built in (heartbeat / deviation threshold)
- Oracle is a separate contract — can be upgraded independently

### Why UUPS over Transparent Proxy?
- UUPS: upgrade logic in implementation (~2700 gas cheaper per call)
- Simpler proxy bytecode, no ProxyAdmin needed
- OZ v5 UUPSUpgradeable is battle-tested

### EIP-7212 on Base
- Base (OP Stack) supports the P-256 precompile at `0x0000...0100`
- This makes WebAuthn signature verification ~10x cheaper than pure Solidity
- Daimo's p256-verifier is the software fallback for other chains

---

## 🗄️ Database Schema (PostgreSQL + Prisma)

```prisma
model PasskeyCredential {
  id              String   @id @default(cuid())
  credentialId    String   @unique          // base64url from WebAuthn
  credentialIdHex String   @unique          // bytes32 hex for on-chain
  publicKeyX      String                    // hex 32 bytes
  publicKeyY      String                    // hex 32 bytes
  accountAddress  String?                   // set after deployment
  counter         BigInt   @default(0)
  rpId            String
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt

  signSessions SignSession[]
  @@index([accountAddress])
}

model SignSession {
  id             String     @id @default(cuid())
  userOpHash     String
  userOpJson     Json
  status         SignStatus @default(PENDING)
  signature      String?
  accountAddress String
  paymasterMode  Int        @default(0)     // 0=ETH, 1=ERC20
  tokenAddress   String?                    // set if mode=1
  expiresAt      DateTime
  createdAt      DateTime   @default(now())
  updatedAt      DateTime   @updatedAt

  credential   PasskeyCredential? @relation(fields: [credentialId], references: [credentialId])
  credentialId String?

  @@index([accountAddress])
  @@index([status, expiresAt])
}

enum SignStatus {
  PENDING
  SIGNED
  SUBMITTED
  FAILED
}
```

---

## 🌐 Environment Variables Reference

```bash
# ─── Blockchain ───────────────────────────────────────────────────── #
NEXT_PUBLIC_RPC_URL=https://sepolia.base.org
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_ENTRYPOINT_ADDRESS=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789

# Set by deploy-contracts.sh after Phase 2 deployment
NEXT_PUBLIC_FACTORY_ADDRESS=
NEXT_PUBLIC_PAYMASTER_ADDRESS=
NEXT_PUBLIC_ORACLE_ADDRESS=
FACTORY_ADDRESS=
PAYMASTER_ADDRESS=
ORACLE_ADDRESS=

# ─── The Graph ────────────────────────────────────────────────────── #
NEXT_PUBLIC_SUBGRAPH_URL=https://api.studio.thegraph.com/query/XXXXX/logers-wallet/version/latest
SUBGRAPH_URL=https://api.studio.thegraph.com/query/XXXXX/logers-wallet/version/latest

# ─── Backend ──────────────────────────────────────────────────────── #
API_PORT=4000
NEXT_PUBLIC_API_URL=http://localhost:4000
INTERNAL_API_URL=http://api:4000
DATABASE_URL=postgresql://logers:logers@localhost:5432/logerswallet
REDIS_URL=redis://localhost:6379

# Pimlico bundler (https://pimlico.io)
BUNDLER_URL=https://api.pimlico.io/v2/84532/rpc?apikey=YOUR_KEY

# Paymaster ECDSA signer (separate EOA from deployer)
PAYMASTER_PRIVATE_KEY=0x...

# JWT (generate: openssl rand -hex 32)
JWT_SECRET=your-64-char-hex

# ─── WebAuthn ─────────────────────────────────────────────────────── #
RP_ID=localhost
RP_NAME=LogersWallet
RP_ORIGIN=http://localhost:3000
NEXT_PUBLIC_RP_ID=localhost
NEXT_PUBLIC_RP_NAME=LogersWallet
NEXT_PUBLIC_RP_ORIGIN=http://localhost:3000

# ─── Deployment ───────────────────────────────────────────────────── #
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
PRIVATE_KEY=0x...           # deployer key
ETHERSCAN_API_KEY=           # optional, for verification
PIMLICO_API_KEY=pim_xxxxx
```

---

## 🎨 Design System

| Token | Value |
|-------|-------|
| Primary | `#6366F1` (Indigo-500) |
| Primary Hover | `#4F46E5` |
| Primary Glow | `rgba(99,102,241,0.3)` |
| Background Base | `#07070E` |
| Background Surface | `#0D0D1A` |
| Background Elevated | `#12121F` |
| Success | `#10B981` |
| Warning | `#F59E0B` |
| Danger | `#EF4444` |
| Token Payment | `#8B5CF6` (Violet — distinct from ETH primary) |

- **Font**: Geist Sans (variable) + Geist Mono for addresses/hashes
- **Motion**: Framer Motion — spring physics only, no linear easing
- **Icons**: Lucide React
- **Cards**: `backdrop-blur-xl bg-white/[0.04] border border-white/[0.08]`
- **Unique element**: Neural network canvas animation on landing + wallet dashboard

---

## ✅ Global Conventions (apply in ALL phases)

### Solidity
- `^0.8.25` minimum compiler
- Custom errors ONLY — `error Unauthorized()` — zero `require` strings
- Pattern: `if (condition) revert ErrorName()` throughout, never `require(cond, "msg")`
- Full NatSpec (`@notice`, `@param`, `@return`) on all public/external functions
- `forge fmt` enforced (line_length = 100)
- Named constants — no magic numbers anywhere
- Gas optimization: `unchecked` arithmetic where overflow impossible, `calldata` over `memory`

### TypeScript
- `strict: true` in all tsconfigs
- Zod for all API runtime validation (input and output schemas)
- `viem` for all chain interactions — no ethers.js
- Eden Treaty for type-safe Elysia → Next.js API calls
- No `any` — ever. Use `unknown` and narrow properly.
- Barrel `index.ts` exports from every package/module

### Naming
- Contracts: `Logers` prefix (e.g., `LogersAccount`, `LogersPaymaster`)
- SDK exports: camelCase (e.g., `logersAccountAbi`, `buildUserOperation`)
- DB models: PascalCase (Prisma convention)
- API routes: kebab-case (`/userop/build`, `/passkey/register`)
- React components: PascalCase, co-located in feature folders

### Git
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`
- Changesets for package versioning (`.changeset/`)
- Pre-commit: `lint-staged` — biome check + forge fmt

---

*This document is the single source of truth. Never contradict it in phase prompts.*
