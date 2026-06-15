// Auto-generated — do not edit. Run: make abi
export const logersPriceOracleAbi = [
  {
    type: "function",
    name: "addFeed",
    inputs: [
      { name: "token", type: "address" },
      { name: "aggregator", type: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "removeFeed",
    inputs: [{ name: "token", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setStalenessThreshold",
    inputs: [{ name: "newThreshold", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getTokenAmount",
    inputs: [
      { name: "token", type: "address" },
      { name: "ethAmount", type: "uint256" },
    ],
    outputs: [{ name: "tokenAmount", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getEthAmount",
    inputs: [
      { name: "token", type: "address" },
      { name: "tokenAmount", type: "uint256" },
    ],
    outputs: [{ name: "ethAmount", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "latestPrice",
    inputs: [{ name: "token", type: "address" }],
    outputs: [
      { name: "price", type: "uint256" },
      { name: "updatedAt", type: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isSupported",
    inputs: [{ name: "token", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRegisteredTokens",
    inputs: [],
    outputs: [{ name: "", type: "address[]" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "stalenessThreshold",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "FeedAdded",
    inputs: [
      { name: "token", type: "address", indexed: true },
      { name: "aggregator", type: "address", indexed: true },
    ],
  },
  {
    type: "event",
    name: "FeedRemoved",
    inputs: [{ name: "token", type: "address", indexed: true }],
  },
  {
    type: "event",
    name: "StalenessThresholdUpdated",
    inputs: [{ name: "newThreshold", type: "uint256", indexed: false }],
  },
  {
    type: "error",
    name: "TokenNotSupported",
    inputs: [{ name: "token", type: "address" }],
  },
  {
    type: "error",
    name: "StalePriceFeed",
    inputs: [
      { name: "token", type: "address" },
      { name: "updatedAt", type: "uint256" },
      { name: "threshold", type: "uint256" },
    ],
  },
  {
    type: "error",
    name: "ZeroPrice",
    inputs: [{ name: "token", type: "address" }],
  },
  { type: "error", name: "ZeroAddress", inputs: [] },
  { type: "error", name: "InvalidStalenessThreshold", inputs: [] },
] as const;
