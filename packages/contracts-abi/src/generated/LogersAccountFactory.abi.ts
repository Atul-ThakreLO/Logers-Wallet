// Auto-generated — do not edit. Run: make abi
export const logersAccountFactoryAbi = [
  {
    type: "function",
    name: "createAccount",
    inputs: [
      { name: "credentialId", type: "bytes32" },
      { name: "pubKeyX", type: "uint256" },
      { name: "pubKeyY", type: "uint256" },
      { name: "salt", type: "uint256" },
    ],
    outputs: [{ name: "account", type: "address" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getAddress",
    inputs: [
      { name: "credentialId", type: "bytes32" },
      { name: "pubKeyX", type: "uint256" },
      { name: "pubKeyY", type: "uint256" },
      { name: "salt", type: "uint256" },
    ],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getInitCode",
    inputs: [
      { name: "credentialId", type: "bytes32" },
      { name: "pubKeyX", type: "uint256" },
      { name: "pubKeyY", type: "uint256" },
      { name: "salt", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bytes" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "accountImplementation",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "entryPoint",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "AccountDeployed",
    inputs: [
      { name: "account", type: "address", indexed: true },
      { name: "credentialId", type: "bytes32", indexed: true },
      { name: "pubKeyX", type: "uint256", indexed: false },
      { name: "pubKeyY", type: "uint256", indexed: false },
    ],
  },
  { type: "error", name: "ZeroAddress", inputs: [] },
  { type: "error", name: "InvalidPublicKey", inputs: [] },
  { type: "error", name: "DeploymentFailed", inputs: [] },
] as const;
