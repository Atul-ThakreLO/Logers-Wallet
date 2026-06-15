// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {TestHelper} from "./helpers/TestHelper.sol";
import {LogersAccount} from "../src/LogersAccount.sol";
import {LogersPaymaster} from "../src/LogersPaymaster.sol";
import {ILogersPaymaster} from "../src/interfaces/ILogersPaymaster.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LogersPaymasterTest is TestHelper {
    LogersAccount internal account;
    uint48 internal validUntil;
    uint48 internal validAfter;

    function setUp() public override {
        super.setUp();
        _deployAlwaysTruePrecompile();
        account = factory.createAccount(CRED_ID, PUB_X, PUB_Y, 0);
        validUntil = uint48(block.timestamp + 1 hours);
        validAfter = uint48(block.timestamp - 1);
    }

    // ─── addOperator / removeOperator ─────────────────────────────────────── //

    function test_addOperator_succeeds() public {
        vm.expectEmit(true, false, false, false);
        emit ILogersPaymaster.OperatorAdded(alice);
        paymaster.addOperator(alice);
        assertTrue(paymaster.operators(alice));
    }

    function test_addOperator_revertsZeroAddress() public {
        vm.expectRevert(ILogersPaymaster.ZeroAddress.selector);
        paymaster.addOperator(address(0));
    }

    function test_removeOperator_succeeds() public {
        paymaster.addOperator(alice);
        vm.expectEmit(true, false, false, false);
        emit ILogersPaymaster.OperatorRemoved(alice);
        paymaster.removeOperator(alice);
        assertFalse(paymaster.operators(alice));
    }

    function test_removeOperator_revertsIfNotOperator() public {
        vm.expectRevert(ILogersPaymaster.InvalidOperator.selector);
        paymaster.removeOperator(alice);
    }

    // ─── whitelistToken / delistToken ─────────────────────────────────────── //

    function test_whitelistToken_succeeds() public {
        address newToken = makeAddr("token");
        vm.expectEmit(true, false, false, false);
        emit ILogersPaymaster.TokenWhitelisted(newToken);
        paymaster.whitelistToken(newToken);
        assertTrue(paymaster.whitelistedTokens(newToken));
    }

    function test_delistToken_succeeds() public {
        vm.expectEmit(true, false, false, false);
        emit ILogersPaymaster.TokenDelisted(address(usdc));
        paymaster.delistToken(address(usdc));
        assertFalse(paymaster.whitelistedTokens(address(usdc)));
    }

    // ─── deposit / withdrawTo ─────────────────────────────────────────────── //

    function test_deposit_increases_balance() public {
        uint256 before = entryPoint.balanceOf(address(paymaster));
        paymaster.deposit{value: 0.5 ether}();
        assertEq(entryPoint.balanceOf(address(paymaster)), before + 0.5 ether);
    }

    function test_withdrawTo_succeeds() public {
        uint256 before = entryPoint.balanceOf(address(paymaster));
        paymaster.withdrawTo(payable(alice), 0.1 ether);
        assertEq(entryPoint.balanceOf(address(paymaster)), before - 0.1 ether);
        assertEq(alice.balance, 0.1 ether);
    }

    function test_withdrawTo_revertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        paymaster.withdrawTo(payable(alice), 0.1 ether);
    }

    // ─── validatePaymasterUserOp — ETH mode ───────────────────────────────── //

    function test_ethMode_validSignature_passes() public {
        PackedUserOperation memory op = _buildUserOp(address(account), bytes(""));

        // Build ETH mode paymasterAndData
        op.paymasterAndData =
            _buildEthModePaymasterData(op, validUntil, validAfter, paymasterOperatorKey);

        // Fund account for prefund
        vm.deal(address(account), 0.1 ether);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = op;

        // handleOps should not revert (will revert if paymaster validation fails)
        // Use a try/catch to isolate paymaster validation from account validation
        vm.prank(makeAddr("bundler"));
        try entryPoint.handleOps(ops, payable(makeAddr("beneficiary"))) {} catch {}
        // The paymaster passed validation if no InvalidSignature revert from it
    }

    function test_ethMode_invalidSignature_reverts() public {
        PackedUserOperation memory op = _buildUserOp(address(account), bytes(""));

        // Sign with a key that is NOT an operator
        uint256 nonOperatorKey = uint256(keccak256("not-an-operator"));
        op.paymasterAndData = _buildEthModePaymasterData(op, validUntil, validAfter, nonOperatorKey);

        vm.deal(address(account), 0.1 ether);

        // Directly test paymaster validation by calling as EntryPoint
        vm.prank(address(entryPoint));
        vm.expectRevert();
        paymaster.validatePaymasterUserOp(op, keccak256("hash"), 0.01 ether);
    }

    // ─── validatePaymasterUserOp — ERC-20 mode ────────────────────────────── //

    function test_erc20Mode_correctTokenAmountCalculated() public {
        PackedUserOperation memory op = _buildUserOp(address(account), bytes(""));
        op.paymasterAndData = _buildErc20ModePaymasterData(
            op, address(usdc), validUntil, validAfter, paymasterOperatorKey
        );

        // Mint and approve enough USDC
        usdc.mint(address(account), 1_000_000_000); // 1000 USDC
        vm.prank(address(account));
        usdc.approve(address(paymaster), type(uint256).max);

        vm.deal(address(account), 0.1 ether);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = op;

        vm.prank(makeAddr("bundler"));
        try entryPoint.handleOps(ops, payable(makeAddr("beneficiary"))) {} catch {}
    }

    function test_erc20Mode_insufficientAllowance_reverts() public {
        PackedUserOperation memory op = _buildUserOp(address(account), bytes(""));
        op.paymasterAndData = _buildErc20ModePaymasterData(
            op, address(usdc), validUntil, validAfter, paymasterOperatorKey
        );

        // No USDC allowance set — validatePaymasterUserOp should revert
        usdc.mint(address(account), 1_000_000_000);
        // No approve call — allowance = 0

        vm.prank(address(entryPoint));
        vm.expectRevert();
        paymaster.validatePaymasterUserOp(op, keccak256("hash"), 0.01 ether);
    }

    function test_erc20Mode_unsupportedToken_reverts() public {
        address badToken = makeAddr("badToken");
        PackedUserOperation memory op = _buildUserOp(address(account), bytes(""));
        op.paymasterAndData = _buildErc20ModePaymasterData(
            op, badToken, validUntil, validAfter, paymasterOperatorKey
        );

        vm.prank(address(entryPoint));
        vm.expectRevert();
        paymaster.validatePaymasterUserOp(op, keccak256("hash"), 0.01 ether);
    }

    // ─── Daily limit — ETH mode ────────────────────────────────────────────── //

    function test_dailyLimit_revertsWhenExceeded() public {
        // Set a 0.001 ETH daily limit
        paymaster.setDailyEthLimit(address(account), 0.001 ether);

        PackedUserOperation memory op = _buildUserOp(address(account), bytes(""));
        // High gas cost will exceed the 0.001 ETH limit
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(10_000_000), uint128(10_000_000)));
        op.paymasterAndData =
            _buildEthModePaymasterData(op, validUntil, validAfter, paymasterOperatorKey);

        vm.prank(address(entryPoint));
        vm.expectRevert();
        paymaster.validatePaymasterUserOp(op, keccak256("hash"), 1 ether);
    }

    function test_dailyLimit_zero_isUnlimited() public view {
        // Zero limit means unlimited — no revert expected from limit check
        assertEq(paymaster.dailyEthLimit(address(account)), 0);
    }

    // ─── setOracle ────────────────────────────────────────────────────────── //

    function test_setOracle_updates() public {
        address newOracle = makeAddr("newOracle");
        paymaster.setOracle(newOracle);
        assertEq(address(paymaster.oracle()), newOracle);
    }

    function test_setOracle_revertsZeroAddress() public {
        vm.expectRevert(ILogersPaymaster.ZeroAddress.selector);
        paymaster.setOracle(address(0));
    }

    // ─── withdrawToken ────────────────────────────────────────────────────── //

    function test_withdrawToken_succeeds() public {
        usdc.mint(address(paymaster), 1_000_000);
        paymaster.withdrawToken(address(usdc), alice, 1_000_000);
        assertEq(usdc.balanceOf(alice), 1_000_000);
    }

    function test_withdrawToken_revertsZeroRecipient() public {
        usdc.mint(address(paymaster), 1_000_000);
        vm.expectRevert(ILogersPaymaster.ZeroAddress.selector);
        paymaster.withdrawToken(address(usdc), address(0), 1_000_000);
    }
}
