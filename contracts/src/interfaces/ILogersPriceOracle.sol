// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title ILogersPriceOracle
/// @notice Interface for the LogersWallet price oracle
interface ILogersPriceOracle {
    // ─── Events ───────────────────────────────────────────────────────────── //

    /// @notice Emitted when a new Chainlink price feed is registered for a token
    event FeedAdded(address indexed token, address indexed aggregator);

    /// @notice Emitted when a token's price feed is removed
    event FeedRemoved(address indexed token);

    /// @notice Emitted when the staleness threshold is updated
    event StalenessThresholdUpdated(uint256 newThreshold);

    // ─── Errors ───────────────────────────────────────────────────────────── //

    /// @notice Token is not registered in the oracle
    error TokenNotSupported(address token);

    /// @notice Price feed data is older than the staleness threshold
    error StalePriceFeed(address token, uint256 updatedAt, uint256 threshold);

    /// @notice Chainlink returned a zero or negative price
    error ZeroPrice(address token);

    /// @notice Zero address supplied where non-zero is required
    error ZeroAddress();

    /// @notice Staleness threshold of zero is invalid
    error InvalidStalenessThreshold();

    // ─── Core Queries ─────────────────────────────────────────────────────── //

    /// @notice Get how many token units equal `ethAmount` wei
    /// @param token ERC-20 token address
    /// @param ethAmount Amount in wei to convert
    /// @return tokenAmount Required token units (in token's native decimals)
    function getTokenAmount(address token, uint256 ethAmount)
        external
        view
        returns (uint256 tokenAmount);

    /// @notice Get how much ETH (wei) equals `tokenAmount` of a token
    /// @param token ERC-20 token address
    /// @param tokenAmount Token units to convert
    /// @return ethAmount Equivalent ETH in wei
    function getEthAmount(address token, uint256 tokenAmount)
        external
        view
        returns (uint256 ethAmount);

    /// @notice Get latest raw price data from Chainlink
    /// @param token ERC-20 token address
    /// @return price Price in ETH (18 decimals normalized)
    /// @return updatedAt Timestamp of last price update
    function latestPrice(address token) external view returns (uint256 price, uint256 updatedAt);

    /// @notice Check if a token is supported by the oracle
    /// @param token ERC-20 token address
    /// @return True if the token has a registered price feed
    function isSupported(address token) external view returns (bool);
}
