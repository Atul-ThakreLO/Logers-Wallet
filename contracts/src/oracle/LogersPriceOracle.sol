// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {ILogersPriceOracle} from "../interfaces/ILogersPriceOracle.sol";

/// @title LogersPriceOracle
/// @notice Chainlink-based price oracle for LogersPaymaster ERC-20 gas payments.
///         Converts between ERC-20 token amounts and ETH wei equivalents.
///         Each registered token must have a Chainlink TOKEN/ETH price feed.
/// @dev Owner can add/remove token feeds. Includes a configurable staleness guard.
///      All returned prices are normalised to 18-decimal precision.
contract LogersPriceOracle is ILogersPriceOracle, Ownable {
    // ─────────────────────────────── Constants ────────────────────────────── //

    /// @notice ETH is represented with 18 decimals
    uint256 internal constant ETH_DECIMALS = 18;

    /// @notice Chainlink TOKEN/ETH feeds return 18-decimal prices
    uint256 internal constant CHAINLINK_PRICE_DECIMALS = 18;

    /// @notice Default price staleness guard: 1 hour
    uint256 internal constant DEFAULT_STALENESS_THRESHOLD = 3600;

    // ─────────────────────────────── Storage ──────────────────────────────── //

    /// @notice Chainlink aggregator per token address
    mapping(address => AggregatorV3Interface) internal _feeds;

    /// @notice Cached token decimals — avoid external calls on every query
    mapping(address => uint8) internal _tokenDecimals;

    /// @notice Ordered list of registered token addresses (for enumeration)
    address[] internal _registeredTokens;

    /// @notice Quick membership check
    mapping(address => bool) internal _isRegistered;

    /// @notice Maximum age (seconds) of a price update before it is considered stale
    uint256 public stalenessThreshold;

    // ─────────────────────────────── Constructor ──────────────────────────── //

    /// @param initialOwner Address that can add/remove feeds and update staleness threshold
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        stalenessThreshold = DEFAULT_STALENESS_THRESHOLD;
    }

    // ─────────────────────────────── Admin ────────────────────────────────── //

    /// @notice Register a Chainlink TOKEN/ETH price feed for a token.
    /// @param token ERC-20 token address
    /// @param aggregator Chainlink AggregatorV3Interface address (TOKEN/ETH feed)
    function addFeed(address token, address aggregator) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (aggregator == address(0)) revert ZeroAddress();

        _feeds[token] = AggregatorV3Interface(aggregator);
        _tokenDecimals[token] = IERC20Metadata(token).decimals();

        if (!_isRegistered[token]) {
            _isRegistered[token] = true;
            _registeredTokens.push(token);
        }

        emit FeedAdded(token, aggregator);
    }

    /// @notice Remove a token's price feed.
    /// @param token ERC-20 token address to deregister
    function removeFeed(address token) external onlyOwner {
        if (!_isRegistered[token]) revert TokenNotSupported(token);

        delete _feeds[token];
        delete _tokenDecimals[token];
        _isRegistered[token] = false;

        // Swap-and-pop from enumeration array to avoid gaps
        uint256 len = _registeredTokens.length;
        for (uint256 i; i < len;) {
            if (_registeredTokens[i] == token) {
                _registeredTokens[i] = _registeredTokens[len - 1];
                _registeredTokens.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit FeedRemoved(token);
    }

    /// @notice Update the staleness threshold.
    /// @param newThreshold New maximum price age in seconds (must be > 0)
    function setStalenessThreshold(uint256 newThreshold) external onlyOwner {
        if (newThreshold == 0) revert InvalidStalenessThreshold();
        stalenessThreshold = newThreshold;
        emit StalenessThresholdUpdated(newThreshold);
    }

    // ─────────────────────────────── Core Oracle ──────────────────────────── //

    /// @inheritdoc ILogersPriceOracle
    /// @dev tokenAmount = ethAmount × 10^tokenDecimals / tokenPriceInEth
    ///      where tokenPriceInEth is the Chainlink TOKEN/ETH price (18 decimals).
    function getTokenAmount(address token, uint256 ethAmount)
        external
        view
        override
        returns (uint256 tokenAmount)
    {
        (uint256 price,) = latestPrice(token);
        uint8 decimals = _tokenDecimals[token];
        tokenAmount = (ethAmount * (10 ** uint256(decimals))) / price;
    }

    /// @inheritdoc ILogersPriceOracle
    /// @dev ethAmount = tokenAmount × tokenPriceInEth / 10^tokenDecimals
    function getEthAmount(address token, uint256 tokenAmount)
        external
        view
        override
        returns (uint256 ethAmount)
    {
        (uint256 price,) = latestPrice(token);
        uint8 decimals = _tokenDecimals[token];
        ethAmount = (tokenAmount * price) / (10 ** uint256(decimals));
    }

    /// @inheritdoc ILogersPriceOracle
    function latestPrice(address token)
        public
        view
        override
        returns (uint256 price, uint256 updatedAt)
    {
        if (!_isRegistered[token]) revert TokenNotSupported(token);

        AggregatorV3Interface feed = _feeds[token];
        (, int256 answer,, uint256 timestamp,) = feed.latestRoundData();

        if (answer <= 0) revert ZeroPrice(token);

        if (block.timestamp - timestamp > stalenessThreshold) {
            revert StalePriceFeed(token, timestamp, stalenessThreshold);
        }

        price = uint256(answer);
        updatedAt = timestamp;
    }

    /// @inheritdoc ILogersPriceOracle
    function isSupported(address token) external view override returns (bool) {
        return _isRegistered[token];
    }

    /// @notice Return all currently registered token addresses.
    /// @return Array of token addresses with active price feeds
    function getRegisteredTokens() external view returns (address[] memory) {
        return _registeredTokens;
    }
}
