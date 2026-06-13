.PHONY: setup dev build test lint clean contracts subgraph deploy

# ── Setup ─────────────────────────────────────────────────────────────── #
setup:
	@echo "🚀 Setting up LogersWallet..."
	@bash tooling/scripts/setup.sh

# ── Development ───────────────────────────────────────────────────────── #
dev:
	@bash tooling/scripts/dev.sh

dev-infra:
	@docker compose -f infra/docker/docker-compose.yml up -d postgres redis

# ── Build ─────────────────────────────────────────────────────────────── #
build:
	@pnpm build

build-contracts:
	@cd contracts && forge build --sizes

abi:
	@cd contracts && forge build
	@bun tooling/scripts/extract-abis.ts

# ── Test ──────────────────────────────────────────────────────────────── #
test:
	@pnpm test

test-contracts:
	@cd contracts && forge test -vvv

test-coverage:
	@cd contracts && forge coverage --report lcov

# ── Quality ───────────────────────────────────────────────────────────── #
lint:
	@pnpm lint
	@cd contracts && forge fmt --check

format:
	@pnpm format
	@cd contracts && forge fmt

typecheck:
	@pnpm typecheck

# ── Deploy ────────────────────────────────────────────────────────────── #
deploy-contracts:
	@bash tooling/scripts/deploy-contracts.sh

deploy-subgraph:
	@cd subgraph && graph deploy --studio logers-wallet

# ── Clean ─────────────────────────────────────────────────────────────── #
clean:
	@pnpm clean
	@cd contracts && forge clean
	@docker compose -f infra/docker/docker-compose.yml down -v
