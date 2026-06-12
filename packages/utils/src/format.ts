import type { Address, Hash } from "viem";

/**
 * Truncate an Ethereum address for display.
 * Example: 0x1234...abcd
 */
export function truncateAddress(address: Address, chars = 4): string {
	return `${address.slice(0, chars + 2)}...${address.slice(-chars)}`;
}

/**
 * Truncate a transaction hash for display.
 * Example: 0xabcd...1234
 */
export function truncateHash(hash: Hash, chars = 4): string {
	return `${hash.slice(0, chars + 2)}...${hash.slice(-chars)}`;
}
