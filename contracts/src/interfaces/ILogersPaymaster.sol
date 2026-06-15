// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title ILogersPaymaster
/// @notice Interface for the dual-mode LogersPaymaster
interface ILogersPaymaster {
    // ─── Types ────────────────────────────────────────────────────────────── //

    /// @notice Sponsorship mode encoded in paymasterAndData
    /// @dev Mode 0 = ETH (paymaster covers gas), Mode 1 = ERC-20 (user pays in token)
    enum PaymasterMode {
        ETH,
        ERC20
    }

    // ─── Events ───────────────────────────────────────────────────────────── //

    /// @notice Emitted when the paymaster sponsors gas in ETH mode
    event SponsoredWithETH(address indexed account, uint256 actualGasCost);

    /// @notice Emitted when the paymaster sponsors gas in ERC-20 mode
    event SponsoredWithToken(
        address indexed account, address indexed token, uint256 tokenAmount, uint256 ethCost
    );

    /// @notice Emitted when a new operator is authorized to sign paymasterAndData
    event OperatorAdded(address indexed operator);

    /// @notice Emitted when an operator's authorization is revoked
    event OperatorRemoved(address indexed operator);

    /// @notice Emitted when a token is whitelisted for ERC-20 gas payments
    event TokenWhitelisted(address indexed token);

    /// @notice Emitted when a token is removed from the whitelist
    event TokenDelisted(address indexed token);

    // ─── Errors ───────────────────────────────────────────────────────────── //

    /// @notice Zero address supplied where non-zero is required
    error ZeroAddress();

    /// @notice Address is not a registered operator
    error InvalidOperator();

    /// @notice paymasterAndData is malformed or too short
    error InvalidPaymasterData();

    /// @notice ECDSA signature did not recover to a known operator
    error InvalidSignature();

    /// @notice Token is not whitelisted for ERC-20 gas payments
    error UnsupportedToken(address token);

    /// @notice User has insufficient ERC-20 allowance to cover gas
    error InsufficientTokenAllowance(address token, uint256 required, uint256 actual);

    /// @notice User has insufficient ERC-20 balance to cover gas
    error InsufficientTokenBalance(address token, uint256 required, uint256 actual);

    /// @notice Account's daily ETH gas spend limit would be exceeded
    error DailyLimitExceeded(address account, uint256 limit, uint256 used);

    /// @notice ERC-20 transfer failed (should not happen with SafeERC20)
    error TokenTransferFailed(address token);

    // ─── Admin ────────────────────────────────────────────────────────────── //

    /// @notice Authorize an address to co-sign paymasterAndData
    /// @param operator Address to add as a signing operator
    function addOperator(address operator) external;

    /// @notice Revoke an operator's signing authorization
    /// @param operator Address to remove as a signing operator
    function removeOperator(address operator) external;

    /// @notice Whitelist a token for use in ERC-20 gas payment mode
    /// @param token ERC-20 token address to whitelist
    function whitelistToken(address token) external;

    /// @notice Remove a token from the ERC-20 gas payment whitelist
    /// @param token ERC-20 token address to delist
    function delistToken(address token) external;
}
