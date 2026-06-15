import { logersAccountAbi } from "@logers/contracts-abi";
import {
  type Address,
  type Hex,
  concat,
  encodeAbiParameters,
  encodeFunctionData,
  keccak256,
  pad,
  parseAbiParameters,
  toHex,
} from "viem";
import type { UserOperationRequest, UserOperationV07 } from "../types.js";
import { ENTRYPOINT_ADDRESS, LOGERS_CHAIN_ID } from "./config.js";

// ─── Build ──────────────────────────────────────────────────────────────── //

export function buildUserOperation(params: {
  sender: Address;
  nonce: bigint;
  request: UserOperationRequest;
  initCode?: Hex;
  paymasterAndData?: Hex;
}): Omit<UserOperationV07, "signature"> {
  const callData = encodeFunctionData({
    abi: logersAccountAbi,
    functionName: "execute",
    args: [params.request.to, params.request.value, params.request.data],
  });

  return {
    sender: params.sender,
    nonce: params.nonce,
    initCode: params.initCode ?? "0x",
    callData,
    accountGasLimits: packGasLimits(200_000n, 200_000n),
    preVerificationGas: 50_000n,
    gasFees: packGasFees(1_000_000_000n, 1_000_000_000n), // 1 gwei
    paymasterAndData: params.paymasterAndData ?? "0x",
  };
}

// ─── Hash ────────────────────────────────────────────────────────────────── //

export function getUserOpHash(
  userOp: Omit<UserOperationV07, "signature">,
  chainId: bigint = BigInt(LOGERS_CHAIN_ID)
): Hex {
  const innerHash = keccak256(
    encodeAbiParameters(
      parseAbiParameters("address,uint256,bytes32,bytes32,bytes32,uint256,bytes32,bytes32"),
      [
        userOp.sender,
        userOp.nonce,
        keccak256(userOp.initCode),
        keccak256(userOp.callData),
        userOp.accountGasLimits,
        userOp.preVerificationGas,
        userOp.gasFees,
        keccak256(userOp.paymasterAndData),
      ]
    )
  );

  return keccak256(
    encodeAbiParameters(parseAbiParameters("bytes32,address,uint256"), [
      innerHash,
      ENTRYPOINT_ADDRESS,
      chainId,
    ])
  );
}

// ─── Paymaster Data Builder ──────────────────────────────────────────────── //

/**
 * Build paymasterAndData for ETH mode (mode=0).
 * The backend ECDSA signature is appended last.
 */
export function buildEthPaymasterData(params: {
  paymasterAddress: Address;
  validUntil: number;
  validAfter: number;
  operatorSignature: Hex;
}): Hex {
  return concat([
    params.paymasterAddress,
    "0x00" as Hex, // mode = 0 (ETH)
    pad("0x0000000000000000000000000000000000000000", { size: 20 }), // zero token
    pad(toHex(params.validUntil), { size: 6 }),
    pad(toHex(params.validAfter), { size: 6 }),
    params.operatorSignature,
  ]) as Hex;
}

/**
 * Build paymasterAndData for ERC-20 token mode (mode=1).
 */
export function buildTokenPaymasterData(params: {
  paymasterAddress: Address;
  tokenAddress: Address;
  validUntil: number;
  validAfter: number;
  operatorSignature: Hex;
}): Hex {
  return concat([
    params.paymasterAddress,
    "0x01" as Hex, // mode = 1 (ERC-20)
    params.tokenAddress,
    pad(toHex(params.validUntil), { size: 6 }),
    pad(toHex(params.validAfter), { size: 6 }),
    params.operatorSignature,
  ]) as Hex;
}

// ─── Gas Packing ─────────────────────────────────────────────────────────── //

export function packGasLimits(verificationGasLimit: bigint, callGasLimit: bigint): Hex {
  return concat([
    pad(toHex(verificationGasLimit), { size: 16 }),
    pad(toHex(callGasLimit), { size: 16 }),
  ]) as Hex;
}

export function packGasFees(maxPriorityFeePerGas: bigint, maxFeePerGas: bigint): Hex {
  return concat([
    pad(toHex(maxPriorityFeePerGas), { size: 16 }),
    pad(toHex(maxFeePerGas), { size: 16 }),
  ]) as Hex;
}
