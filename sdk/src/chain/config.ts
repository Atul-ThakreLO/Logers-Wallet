import type { Address } from "viem";

export const LOGERS_CHAIN_ID = 84532; // Base Sepolia

export const ENTRYPOINT_ADDRESS = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789" as Address;

export const P256_VERIFIER_ADDRESS = "0xc2b78104907F722DABAc4C69f826a522B2754De4" as Address;

export const CONTRACT_ADDRESSES = {
  entryPoint: ENTRYPOINT_ADDRESS,
  p256Verifier: P256_VERIFIER_ADDRESS,
  factory: (process.env.NEXT_PUBLIC_FACTORY_ADDRESS ??
    process.env.FACTORY_ADDRESS ??
    "0x") as Address,
  paymaster: (process.env.NEXT_PUBLIC_PAYMASTER_ADDRESS ??
    process.env.PAYMASTER_ADDRESS ??
    "0x") as Address,
  oracle: (process.env.NEXT_PUBLIC_ORACLE_ADDRESS ?? process.env.ORACLE_ADDRESS ?? "0x") as Address,
} as const;

export const BUNDLER_URL = process.env.BUNDLER_URL ?? process.env.NEXT_PUBLIC_BUNDLER_URL ?? "";
