// Auto-generated — do not edit. Run: make abi
export const logersPaymasterAbi = [
  // ── Admin ─────────────────────────────────────────────────────────────── //
  {
    type: "function",
    name: "addOperator",
    inputs: [{ name: "operator", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "removeOperator",
    inputs: [{ name: "operator", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "whitelistToken",
    inputs: [{ name: "token", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "delistToken",
    inputs: [{ name: "token", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setDailyEthLimit",
    inputs: [
      { name: "account", type: "address" },
      { name: "limitWei", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setOracle",
    inputs: [{ name: "newOracle", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // ── Paymaster Logic ───────────────────────────────────────────────────── //
  {
    type: "function",
    name: "getHash",
    inputs: [
      {
        name: "userOp",
        type: "tuple",
        components: [
          { name: "sender", type: "address" },
          { name: "nonce", type: "uint256" },
          { name: "initCode", type: "bytes" },
          { name: "callData", type: "bytes" },
          { name: "accountGasLimits", type: "bytes32" },
          { name: "preVerificationGas", type: "uint256" },
          { name: "gasFees", type: "bytes32" },
          { name: "paymasterAndData", type: "bytes" },
          { name: "signature", type: "bytes" },
        ],
      },
      { name: "mode", type: "uint8" },
      { name: "token", type: "address" },
      { name: "validUntil", type: "uint48" },
      { name: "validAfter", type: "uint48" },
    ],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "deposit",
    inputs: [],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "withdrawTo",
    inputs: [
      { name: "recipient", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "withdrawToken",
    inputs: [
      { name: "token", type: "address" },
      { name: "recipient", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "operators",
    inputs: [{ name: "operator", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "whitelistedTokens",
    inputs: [{ name: "token", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "oracle",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  // ── Events ────────────────────────────────────────────────────────────── //
  {
    type: "event",
    name: "SponsoredWithETH",
    inputs: [
      { name: "account", type: "address", indexed: true },
      { name: "actualGasCost", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "SponsoredWithToken",
    inputs: [
      { name: "account", type: "address", indexed: true },
      { name: "token", type: "address", indexed: true },
      { name: "tokenAmount", type: "uint256", indexed: false },
      { name: "ethCost", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "OperatorAdded",
    inputs: [{ name: "operator", type: "address", indexed: true }],
  },
  {
    type: "event",
    name: "OperatorRemoved",
    inputs: [{ name: "operator", type: "address", indexed: true }],
  },
  {
    type: "event",
    name: "TokenWhitelisted",
    inputs: [{ name: "token", type: "address", indexed: true }],
  },
  {
    type: "event",
    name: "TokenDelisted",
    inputs: [{ name: "token", type: "address", indexed: true }],
  },
  // ── Errors ────────────────────────────────────────────────────────────── //
  { type: "error", name: "ZeroAddress", inputs: [] },
  { type: "error", name: "InvalidOperator", inputs: [] },
  { type: "error", name: "InvalidPaymasterData", inputs: [] },
  { type: "error", name: "InvalidSignature", inputs: [] },
  {
    type: "error",
    name: "UnsupportedToken",
    inputs: [{ name: "token", type: "address" }],
  },
  {
    type: "error",
    name: "InsufficientTokenAllowance",
    inputs: [
      { name: "token", type: "address" },
      { name: "required", type: "uint256" },
      { name: "actual", type: "uint256" },
    ],
  },
  {
    type: "error",
    name: "InsufficientTokenBalance",
    inputs: [
      { name: "token", type: "address" },
      { name: "required", type: "uint256" },
      { name: "actual", type: "uint256" },
    ],
  },
  {
    type: "error",
    name: "DailyLimitExceeded",
    inputs: [
      { name: "account", type: "address" },
      { name: "limit", type: "uint256" },
      { name: "used", type: "uint256" },
    ],
  },
] as const;
