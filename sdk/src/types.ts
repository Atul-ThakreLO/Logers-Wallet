import type { Address, Hex } from "viem";

// ─── Passkey ────────────────────────────────────────────────────────────── //
export interface PasskeyPublicKey {
  x: Hex;
  y: Hex;
}

export interface RegisteredPasskey {
  credentialId: string;
  credentialIdHash: Hex;
  publicKey: PasskeyPublicKey;
  accountAddress: Address;
}

export interface WebAuthnAuthData {
  authenticatorData: Hex;
  clientDataJSON: string;
  challengeIndex: bigint;
  typeIndex: bigint;
  r: bigint;
  s: bigint;
}

// ─── UserOperation ──────────────────────────────────────────────────────── //
export interface UserOperationV07 {
  sender: Address;
  nonce: bigint;
  initCode: Hex;
  callData: Hex;
  accountGasLimits: Hex;
  preVerificationGas: bigint;
  gasFees: Hex;
  paymasterAndData: Hex;
  signature: Hex;
}

export interface UserOperationRequest {
  from: Address;
  to: Address;
  value: bigint;
  data: Hex;
}

// ─── Paymaster ──────────────────────────────────────────────────────────── //
export type PaymasterMode = 0 | 1; // 0 = ETH, 1 = ERC-20

export interface TokenInfo {
  address: Address;
  symbol: string;
  decimals: number;
  logoUri?: string;
}

// ─── Sign Session ───────────────────────────────────────────────────────── //
export interface SignSession {
  id: string;
  userOpHash: Hex;
  userOp: UserOperationV07;
  status: "PENDING" | "SIGNED" | "SUBMITTED" | "FAILED";
  paymasterMode: PaymasterMode;
  tokenAddress?: Address;
  expiresAt: number;
}
