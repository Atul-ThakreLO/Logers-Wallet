// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title DeployConfig
/// @notice Static configuration constants for the LogersWallet deployment.
///         Update these values before deploying to a new network.
library DeployConfig {
    // ── Well-known addresses ─────────────────────────────────────────────── //

    /// @notice ERC-4337 EntryPoint v0.7 (same across all EVM chains)
    address internal constant ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    // ── Base Sepolia token addresses ─────────────────────────────────────── //

    /// @notice USDC on Base Sepolia
    address internal constant USDC_ADDRESS = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    /// @notice Chainlink USDC/ETH feed on Base Sepolia.
    ///         Set to address(0) if not yet available — feed registration is skipped.
    address internal constant USDC_ETH_FEED = address(0); // TODO: replace with live feed

    // ── Initial funding ──────────────────────────────────────────────────── //

    /// @notice ETH deposited to paymaster on non-local deployments
    uint256 internal constant INITIAL_PAYMASTER_DEPOSIT = 0.05 ether;
}
