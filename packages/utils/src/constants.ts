import type { Address } from "viem";

/** ERC-4337 EntryPoint v0.7 canonical address on Base Sepolia */
export const ENTRYPOINT_ADDRESS: Address =
	"0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";

/** Base Sepolia chain ID */
export const BASE_SEPOLIA_CHAIN_ID = 84_532 as const;

/** EIP-7212 P-256 precompile address (available on Base/OP Stack) */
export const P256_PRECOMPILE_ADDRESS: Address =
	"0x0000000000000000000000000000000000000100";

/** Maximum staleness for Chainlink oracle feeds (1 hour in seconds) */
export const ORACLE_MAX_STALENESS = 3_600 as const;

/** Paymaster modes */
export const PAYMASTER_MODE = {
	ETH: 0,
	ERC20: 1,
} as const;
