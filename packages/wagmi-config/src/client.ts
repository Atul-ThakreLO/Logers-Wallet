import { createPublicClient, http } from "viem";
import { baseSepolia } from "./chain";

/**
 * Shared public client for Base Sepolia.
 * Used for read-only chain interactions.
 */
export const publicClient = createPublicClient({
	chain: baseSepolia,
	transport: http(),
});
