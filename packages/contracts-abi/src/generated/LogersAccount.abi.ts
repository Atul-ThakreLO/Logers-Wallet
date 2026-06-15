// Auto-generated — do not edit. Run: make abi
export const logersAccountAbi = [
  // ── Initializer ──────────────────────────────────────────────────────── //
  {
    type: "function",
    name: "initialize",
    inputs: [
      { name: "entryPoint_", type: "address" },
      { name: "p256Verifier_", type: "address" },
      { name: "credentialId", type: "bytes32" },
      { name: "pubKeyX", type: "uint256" },
      { name: "pubKeyY", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // ── Execution ─────────────────────────────────────────────────────────── //
  {
    type: "function",
    name: "execute",
    inputs: [
      { name: "target", type: "address" },
      { name: "value", type: "uint256" },
      { name: "data", type: "bytes" },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "executeBatch",
    inputs: [
      {
        name: "calls",
        type: "tuple[]",
        components: [
          { name: "target", type: "address" },
          { name: "value", type: "uint256" },
          { name: "data", type: "bytes" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  // ── Owner Management ──────────────────────────────────────────────────── //
  {
    type: "function",
    name: "addOwner",
    inputs: [
      { name: "credentialId", type: "bytes32" },
      { name: "pubKeyX", type: "uint256" },
      { name: "pubKeyY", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "removeOwner",
    inputs: [{ name: "credentialId", type: "bytes32" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "isOwner",
    inputs: [{ name: "credentialId", type: "bytes32" }],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getOwner",
    inputs: [{ name: "credentialId", type: "bytes32" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "pubKeyX", type: "uint256" },
          { name: "pubKeyY", type: "uint256" },
          { name: "active", type: "bool" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "ownerCount",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAllCredentialIds",
    inputs: [],
    outputs: [{ name: "", type: "bytes32[]" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "entryPoint",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  // ── ERC-1271 ──────────────────────────────────────────────────────────── //
  {
    type: "function",
    name: "isValidSignature",
    inputs: [
      { name: "hash", type: "bytes32" },
      { name: "signature", type: "bytes" },
    ],
    outputs: [{ name: "", type: "bytes4" }],
    stateMutability: "view",
  },
  // ── UUPS ──────────────────────────────────────────────────────────────── //
  {
    type: "function",
    name: "upgradeToAndCall",
    inputs: [
      { name: "newImplementation", type: "address" },
      { name: "data", type: "bytes" },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  // ── Events ────────────────────────────────────────────────────────────── //
  {
    type: "event",
    name: "OwnerAdded",
    inputs: [
      { name: "credentialId", type: "bytes32", indexed: true },
      { name: "pubKeyX", type: "uint256", indexed: false },
      { name: "pubKeyY", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "OwnerRemoved",
    inputs: [{ name: "credentialId", type: "bytes32", indexed: true }],
  },
  {
    type: "event",
    name: "ExecutedTransaction",
    inputs: [
      { name: "to", type: "address", indexed: true },
      { name: "value", type: "uint256", indexed: false },
      { name: "data", type: "bytes", indexed: false },
    ],
  },
  {
    type: "event",
    name: "ExecutedBatch",
    inputs: [{ name: "operationCount", type: "uint256", indexed: false }],
  },
  {
    type: "event",
    name: "Upgraded",
    inputs: [{ name: "implementation", type: "address", indexed: true }],
  },
  // ── Errors ────────────────────────────────────────────────────────────── //
  { type: "error", name: "OnlyEntryPoint", inputs: [] },
  { type: "error", name: "OnlyEntryPointOrSelf", inputs: [] },
  { type: "error", name: "ZeroAddress", inputs: [] },
  { type: "error", name: "InvalidPublicKey", inputs: [] },
  {
    type: "error",
    name: "OwnerAlreadyExists",
    inputs: [{ name: "credentialId", type: "bytes32" }],
  },
  {
    type: "error",
    name: "OwnerNotFound",
    inputs: [{ name: "credentialId", type: "bytes32" }],
  },
  { type: "error", name: "MustHaveAtLeastOneOwner", inputs: [] },
  {
    type: "error",
    name: "ExecutionFailed",
    inputs: [
      { name: "target", type: "address" },
      { name: "returnData", type: "bytes" },
    ],
  },
  {
    type: "error",
    name: "InsufficientFundsForPrefund",
    inputs: [
      { name: "required", type: "uint256" },
      { name: "available", type: "uint256" },
    ],
  },
] as const;
