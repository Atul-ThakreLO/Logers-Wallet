# ──────────────────────────────────────────────────────────────────────
# LogersWallet Makefile
# ──────────────────────────────────────────────────────────────────────

.PHONY: install dev build lint fmt clean typecheck \
        contracts-build contracts-test contracts-deploy \
        docker-up docker-down setup

# ─── General ─────────────────────────────────────────────────────── #

install:
	pnpm install

dev:
	pnpm run dev

build:
	pnpm run build

lint:
	pnpm run lint

fmt:
	pnpm run fmt

typecheck:
	pnpm run typecheck

clean:
	pnpm run clean

# ─── Contracts ───────────────────────────────────────────────────── #

contracts-build:
	cd contracts && forge build

contracts-test:
	cd contracts && forge test -vvv

contracts-fmt:
	cd contracts && forge fmt

contracts-deploy:
	bash tooling/scripts/deploy-contracts.sh

# ─── Docker ──────────────────────────────────────────────────────── #

docker-up:
	docker compose -f infra/docker/docker-compose.yml up -d

docker-down:
	docker compose -f infra/docker/docker-compose.yml down

# ─── Setup ───────────────────────────────────────────────────────── #

setup:
	bash tooling/scripts/setup.sh
