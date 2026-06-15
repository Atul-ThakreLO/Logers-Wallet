// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AggregatorV3Interface} from "../../src/interfaces/AggregatorV3Interface.sol";

/// @title MockChainlinkFeed
/// @notice Minimal Chainlink AggregatorV3Interface mock for unit tests.
///         Allows setting arbitrary answers and timestamps.
contract MockChainlinkFeed is AggregatorV3Interface {
    int256 public answer;
    uint256 public updatedAt;
    uint8 public decimals = 18;
    string public description = "MOCK/ETH";
    uint256 public version = 3;

    constructor(int256 initialAnswer) {
        answer = initialAnswer;
        updatedAt = block.timestamp;
    }

    /// @notice Overwrite the price answer
    function setAnswer(int256 newAnswer) external {
        answer = newAnswer;
    }

    /// @notice Overwrite the updatedAt timestamp (use to simulate stale feeds)
    function setUpdatedAt(uint256 ts) external {
        updatedAt = ts;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer_,
            uint256 startedAt,
            uint256 updatedAt_,
            uint80 answeredInRound
        )
    {
        return (1, answer, updatedAt, updatedAt, 1);
    }

    function getRoundData(uint80)
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}
