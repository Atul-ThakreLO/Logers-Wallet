import { http, createConfig } from "wagmi";
import { baseSepolia } from "wagmi/chains";

export { baseSepolia } from "wagmi/chains";

export const LOGERS_CHAIN = baseSepolia;

export const CONTRACT_ADDRESSES = {
  entryPoint: "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789" as const,
  p256Verifier: "0xc2b78104907F722DABAc4C69f826a522B2754De4" as const,
  factory: (process.env.NEXT_PUBLIC_FACTORY_ADDRESS ?? "0x") as `0x${string}`,
  paymaster: (process.env.NEXT_PUBLIC_PAYMASTER_ADDRESS ?? "0x") as `0x${string}`,
  oracle: (process.env.NEXT_PUBLIC_ORACLE_ADDRESS ?? "0x") as `0x${string}`,
} as const;

export const wagmiConfig = createConfig({
  chains: [baseSepolia],
  transports: {
    [baseSepolia.id]: http(process.env.NEXT_PUBLIC_RPC_URL ?? "https://sepolia.base.org"),
  },
  ssr: true,
});

declare module "wagmi" {
  interface Register {
    config: typeof wagmiConfig;
  }
}
