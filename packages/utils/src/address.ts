import type { Address } from "viem";

export function getExplorerUrl(
  type: "tx" | "address" | "token",
  value: string,
  chainId = 84532
): string {
  const explorers: Record<number, string> = {
    84532: "https://sepolia.basescan.org",
    8453: "https://basescan.org",
  };
  const base = explorers[chainId] ?? "https://sepolia.basescan.org";
  return `${base}/${type}/${value}`;
}

export function isValidAddress(value: string): value is Address {
  return /^0x[0-9a-fA-F]{40}$/.test(value);
}

export async function copyToClipboard(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}
