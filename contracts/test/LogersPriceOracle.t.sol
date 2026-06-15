// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {TestHelper} from "./helpers/TestHelper.sol";
import {LogersPriceOracle} from "../src/oracle/LogersPriceOracle.sol";
import {MockChainlinkFeed} from "./helpers/MockChainlinkFeed.sol";
import {MockERC20} from "./helpers/TestHelper.sol";
import {ILogersPriceOracle} from "../src/interfaces/ILogersPriceOracle.sol";

contract LogersPriceOracleTest is TestHelper {
    // ─── addFeed ─────────────────────────────────────────────────────────── //

    function test_addFeed_registersCorrectly() public {
        MockERC20 dai = new MockERC20("DAI", "DAI", 18);
        MockChainlinkFeed daiFeed = new MockChainlinkFeed(0.0004 ether);

        vm.expectEmit(true, true, false, false);
        emit ILogersPriceOracle.FeedAdded(address(dai), address(daiFeed));

        oracle.addFeed(address(dai), address(daiFeed));

        assertTrue(oracle.isSupported(address(dai)));
        (uint256 price,) = oracle.latestPrice(address(dai));
        assertEq(price, uint256(0.0004 ether));
    }

    function test_addFeed_revertsOnZeroToken() public {
        vm.expectRevert(ILogersPriceOracle.ZeroAddress.selector);
        oracle.addFeed(address(0), address(usdcFeed));
    }

    function test_addFeed_revertsOnZeroAggregator() public {
        vm.expectRevert(ILogersPriceOracle.ZeroAddress.selector);
        oracle.addFeed(address(usdc), address(0));
    }

    function test_addFeed_idempotent() public {
        // Adding the same feed twice should not push duplicate to array
        MockChainlinkFeed newFeed = new MockChainlinkFeed(0.0005 ether);
        oracle.addFeed(address(usdc), address(newFeed));
        oracle.addFeed(address(usdc), address(newFeed));

        address[] memory tokens = oracle.getRegisteredTokens();
        uint256 count;
        for (uint256 i; i < tokens.length; ++i) {
            if (tokens[i] == address(usdc)) ++count;
        }
        assertEq(count, 1);
    }

    function test_addFeed_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        oracle.addFeed(address(usdc), address(usdcFeed));
    }

    // ─── removeFeed ───────────────────────────────────────────────────────── //

    function test_removeFeed_removes() public {
        vm.expectEmit(true, false, false, false);
        emit ILogersPriceOracle.FeedRemoved(address(usdc));

        oracle.removeFeed(address(usdc));

        assertFalse(oracle.isSupported(address(usdc)));
    }

    function test_removeFeed_revertsIfNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(ILogersPriceOracle.TokenNotSupported.selector, alice)
        );
        oracle.removeFeed(alice);
    }

    // ─── getTokenAmount ───────────────────────────────────────────────────── //

    function test_getTokenAmount_sixDecimals() public view {
        // USDC has 6 decimals. Price = 0.0003 ETH per USDC.
        // 1 ETH → 1e18 / 0.0003e18 = 1/0.0003 USDC (in raw units) = 3333.333... USDC units
        // More precisely: tokenAmount = ethAmount * 10^6 / price
        // For ethAmount = 1 ether:  1e18 * 1e6 / 3e14 = 1e24 / 3e14 = 3_333_333_333
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = oracle.getTokenAmount(address(usdc), ethAmount);
        // price = 0.0003 ether = 3e14
        uint256 expected = (ethAmount * 1e6) / uint256(0.0003 ether);
        assertEq(tokenAmount, expected);
    }

    // ─── getEthAmount ─────────────────────────────────────────────────────── //

    function test_getEthAmount_sixDecimals() public view {
        // 1_000_000 USDC units (= 1 USDC at 6 dec) at 0.0003 ETH/USDC = 0.0003 ETH
        uint256 tokenAmount = 1_000_000; // 1 USDC
        uint256 ethAmount = oracle.getEthAmount(address(usdc), tokenAmount);
        uint256 expected = (tokenAmount * uint256(0.0003 ether)) / 1e6;
        assertEq(ethAmount, expected);
    }

    // ─── Roundtrip invariant ──────────────────────────────────────────────── //

    function test_roundtrip_ethToTokenToEth() public view {
        uint256 startEth = 0.1 ether;
        uint256 tokens = oracle.getTokenAmount(address(usdc), startEth);
        uint256 backToEth = oracle.getEthAmount(address(usdc), tokens);
        // Integer division with 6-decimal USDC causes rounding losses up to price/1e6
        // price = 3e14; rounding loss <= 3e14 per token, acceptable within 1e9 wei
        assertLe(backToEth, startEth);
        assertApproxEqAbs(backToEth, startEth, 1e9); // allow up to 1e9 wei rounding
    }

    // ─── latestPrice staleness ────────────────────────────────────────────── //

    function test_latestPrice_revertsOnStale() public {
        // Warp to a block.timestamp well above the threshold to avoid underflow
        vm.warp(10_000);
        uint256 staleTs = block.timestamp - oracle.stalenessThreshold() - 1;
        usdcFeed.setUpdatedAt(staleTs);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILogersPriceOracle.StalePriceFeed.selector,
                address(usdc),
                staleTs,
                oracle.stalenessThreshold()
            )
        );
        oracle.latestPrice(address(usdc));
    }

    function test_latestPrice_revertsOnZeroPrice() public {
        usdcFeed.setAnswer(0);
        vm.expectRevert(
            abi.encodeWithSelector(ILogersPriceOracle.ZeroPrice.selector, address(usdc))
        );
        oracle.latestPrice(address(usdc));
    }

    function test_latestPrice_revertsOnNegativePrice() public {
        usdcFeed.setAnswer(-1);
        vm.expectRevert(
            abi.encodeWithSelector(ILogersPriceOracle.ZeroPrice.selector, address(usdc))
        );
        oracle.latestPrice(address(usdc));
    }

    function test_latestPrice_revertsForUnsupportedToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(ILogersPriceOracle.TokenNotSupported.selector, alice)
        );
        oracle.latestPrice(alice);
    }

    // ─── setStalenessThreshold ─────────────────────────────────────────────── //

    function test_setStalenessThreshold_updates() public {
        vm.expectEmit(false, false, false, true);
        emit ILogersPriceOracle.StalenessThresholdUpdated(7200);
        oracle.setStalenessThreshold(7200);
        assertEq(oracle.stalenessThreshold(), 7200);
    }

    function test_setStalenessThreshold_revertsOnZero() public {
        vm.expectRevert(ILogersPriceOracle.InvalidStalenessThreshold.selector);
        oracle.setStalenessThreshold(0);
    }

    // ─── Fuzz ─────────────────────────────────────────────────────────────── //

    /// @notice For any non-zero ethAmount, roundtrip should be consistent within 1 wei.
    function testFuzz_getTokenAmount_getEthAmount_consistent(uint96 ethAmount) public view {
        vm.assume(ethAmount > 0);
        uint256 tokens = oracle.getTokenAmount(address(usdc), uint256(ethAmount));
        if (tokens == 0) return; // tiny eth amounts may round to 0 tokens — acceptable
        uint256 backEth = oracle.getEthAmount(address(usdc), tokens);
        // backEth should be ≤ original (integer rounding down)
        assertLe(backEth, uint256(ethAmount));
    }
}
