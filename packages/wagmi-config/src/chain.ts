import { defineChain } from "viem";

/**
 * Base Sepolia testnet chain definition.
 * Chain ID: 84532
 */
export const baseSepolia = defineChain({
	id: 84_532,
	name: "Base Sepolia",
	nativeCurrency: {
		name: "Sepolia Ether",
		symbol: "ETH",
		decimals: 18,
	},
	rpcUrls: {
		default: {
			http: ["https://sepolia.base.org"],
		},
	},
	blockExplorers: {
		default: {
			name: "Basescan",
			url: "https://sepolia.basescan.org",
		},
	},
	testnet: true,
});
