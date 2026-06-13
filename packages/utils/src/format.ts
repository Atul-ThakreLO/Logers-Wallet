import type { Address } from "viem";

export function formatAddress(address: Address, chars = 4): string {
  return `${address.slice(0, chars + 2)}...${address.slice(-chars)}`;
}

export function formatEth(wei: bigint, decimals = 4): string {
  const eth = Number(wei) / 1e18;
  if (eth === 0) return "0 ETH";
  if (eth < 0.0001) return "< 0.0001 ETH";
  return `${eth.toFixed(decimals)} ETH`;
}

export function formatToken(amount: bigint, decimals: number, symbol: string): string {
  const value = Number(amount) / 10 ** decimals;
  if (value === 0) return `0 ${symbol}`;
  if (value < 0.01) return `< 0.01 ${symbol}`;
  return `${value.toFixed(4)} ${symbol}`;
}

export function formatUsd(usdCents: bigint): string {
  const dollars = Number(usdCents) / 100;
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(dollars);
}
