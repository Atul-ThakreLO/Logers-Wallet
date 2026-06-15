// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title AggregatorV3Interface
/// @notice Chainlink Data Feed V3 interface.
///         Local copy used because the installed `chainlink` lib is the full node
///         repository which does not expose the standard Solidity contract package.
///         Source: https://docs.chain.link/data-feeds/api-reference
interface AggregatorV3Interface {
    /// @notice How many decimals the answer has
    function decimals() external view returns (uint8);

    /// @notice Human-readable description of the underlying aggregator
    function description() external view returns (string memory);

    /// @notice The version representing the type of aggregator the proxy points to
    function version() external view returns (uint256);

    /// @notice Get data from a specific round
    /// @param _roundId The round ID to retrieve the round data for
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    /// @notice Get data from the latest round
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
