// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BasePaymaster} from "@account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILogersPaymaster} from "./interfaces/ILogersPaymaster.sol";
import {ILogersPriceOracle} from "./interfaces/ILogersPriceOracle.sol";

/// @title LogersPaymaster
/// @notice Dual-mode verifying paymaster for LogersWallet.
///         Mode 0 (ETH): Backend operator co-signs; paymaster covers gas from deposit.
///         Mode 1 (ERC-20): User pays in a whitelisted ERC-20 token; oracle converts
///                          token amount to ETH; paymaster covers ETH gas.
///
/// @dev paymasterAndData layout (after 20-byte paymaster address + 16-byte gas fields):
///      [0:1]    mode (uint8): 0 = ETH, 1 = ERC-20
///      [1:21]   token address (20 bytes): zero if mode=0
///      [21:27]  validUntil (uint48)
///      [27:33]  validAfter (uint48)
///      [33:98]  ECDSA operator signature (65 bytes)
///
/// @dev BasePaymaster sets `Ownable(msg.sender)` — we call `transferOwnership` immediately
///      in the constructor to hand control to `initialOwner`.
contract LogersPaymaster is BasePaymaster, ILogersPaymaster {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    // ─────────────────────────────── Constants ────────────────────────────── //

    /// @notice Offset of mode byte in the custom paymaster data section
    uint256 internal constant MODE_OFFSET = 0;

    /// @notice Offset of token address in the custom paymaster data section
    uint256 internal constant TOKEN_OFFSET = 1;

    /// @notice Offset of validUntil (uint48) in the custom paymaster data section
    uint256 internal constant VALID_UNTIL_OFFSET = 21;

    /// @notice Offset of validAfter (uint48) in the custom paymaster data section
    uint256 internal constant VALID_AFTER_OFFSET = 27;

    /// @notice Offset of ECDSA operator signature in the custom paymaster data section
    uint256 internal constant SIG_OFFSET = 33;

    /// @notice Length of an ECDSA signature
    uint256 internal constant SIG_LENGTH = 65;

    /// @notice Minimum custom paymaster data length (bytes after paymaster address + gas fields)
    uint256 internal constant MIN_PAYMASTER_DATA = SIG_OFFSET + SIG_LENGTH; // 98 bytes

    /// @notice Price buffer added on top of oracle quote to absorb short-term volatility (10%)
    uint256 internal constant PRICE_BUFFER_BPS = 1000;

    /// @notice Basis points denominator
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    // ─────────────────────────────── Storage ──────────────────────────────── //

    /// @notice Price oracle for ERC-20 → ETH conversion
    ILogersPriceOracle public oracle;

    /// @notice Addresses authorised to sign paymasterAndData
    mapping(address => bool) public operators;

    /// @notice ERC-20 tokens accepted for gas payment (mode=1)
    mapping(address => bool) public whitelistedTokens;

    /// @notice Per-account daily ETH gas spend limit in wei (0 = unlimited)
    mapping(address => uint256) public dailyEthLimit;

    /// @notice Per-account, per-day ETH spend tracker: account → day → spent wei
    mapping(address => mapping(uint256 => uint256)) public dailyEthSpent;

    // ─────────────────────────────── Constructor ──────────────────────────── //

    /// @param entryPoint_ ERC-4337 EntryPoint address
    /// @param oracle_ Chainlink-based price oracle for ERC-20 conversions
    /// @param initialOwner Address that will own this paymaster (admin)
    constructor(IEntryPoint entryPoint_, ILogersPriceOracle oracle_, address initialOwner)
        BasePaymaster(entryPoint_)
    {
        if (address(oracle_) == address(0)) revert ZeroAddress();
        if (initialOwner == address(0)) revert ZeroAddress();

        oracle = oracle_;

        // BasePaymaster sets owner = msg.sender; hand off to intended owner
        transferOwnership(initialOwner);

        // Initial owner is also an operator
        operators[initialOwner] = true;
        emit OperatorAdded(initialOwner);
    }

    // ─────────────────────────────── Admin ────────────────────────────────── //

    /// @inheritdoc ILogersPaymaster
    function addOperator(address operator) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        operators[operator] = true;
        emit OperatorAdded(operator);
    }

    /// @inheritdoc ILogersPaymaster
    function removeOperator(address operator) external onlyOwner {
        if (!operators[operator]) revert InvalidOperator();
        operators[operator] = false;
        emit OperatorRemoved(operator);
    }

    /// @inheritdoc ILogersPaymaster
    function whitelistToken(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        whitelistedTokens[token] = true;
        emit TokenWhitelisted(token);
    }

    /// @inheritdoc ILogersPaymaster
    function delistToken(address token) external onlyOwner {
        whitelistedTokens[token] = false;
        emit TokenDelisted(token);
    }

    /// @notice Set per-account daily ETH gas spend limit (0 = unlimited).
    /// @param account Smart wallet address to apply the limit to
    /// @param limitWei Daily gas limit in wei
    function setDailyEthLimit(address account, uint256 limitWei) external onlyOwner {
        dailyEthLimit[account] = limitWei;
    }

    /// @notice Update the price oracle address.
    /// @param newOracle New ILogersPriceOracle implementation address
    function setOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert ZeroAddress();
        oracle = ILogersPriceOracle(newOracle);
    }

    // ─────────────────────────────── ERC-4337 Validation ──────────────────── //

    /// @dev Validates paymaster signature and per-mode logic.
    ///      Returns packed context for _postOp.
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) internal override returns (bytes memory context, uint256 validationData) {
        // paymasterAndData[0:20] = paymaster address (stripped by EntryPoint).
        // paymasterAndData[20:36] = validation + postOp gas (16 bytes, handled by EntryPoint).
        // Our custom data starts at index 36 relative to the full paymasterAndData field.
        bytes calldata pmData = userOp.paymasterAndData[36:];

        if (pmData.length < MIN_PAYMASTER_DATA) revert InvalidPaymasterData();

        // Decode fields from custom data section
        PaymasterMode mode = PaymasterMode(uint8(bytes1(pmData[MODE_OFFSET:MODE_OFFSET + 1])));
        address token = address(bytes20(pmData[TOKEN_OFFSET:TOKEN_OFFSET + 20]));
        uint48 validUntil = uint48(bytes6(pmData[VALID_UNTIL_OFFSET:VALID_UNTIL_OFFSET + 6]));
        uint48 validAfter = uint48(bytes6(pmData[VALID_AFTER_OFFSET:VALID_AFTER_OFFSET + 6]));
        bytes calldata sig = pmData[SIG_OFFSET:SIG_OFFSET + SIG_LENGTH];

        // 1. Verify operator ECDSA signature over the canonical hash
        bytes32 sigHash = getHash(userOp, mode, token, validUntil, validAfter);
        address recovered = sigHash.toEthSignedMessageHash().recover(sig);
        if (!operators[recovered]) revert InvalidSignature();

        // 2. Mode-specific validation
        if (mode == PaymasterMode.ERC20) {
            if (token == address(0) || !whitelistedTokens[token]) {
                revert UnsupportedToken(token);
            }

            // Calculate required token amount with 10% buffer for price volatility
            uint256 requiredTokenRaw = oracle.getTokenAmount(token, maxCost);
            uint256 requiredToken =
                requiredTokenRaw + (requiredTokenRaw * PRICE_BUFFER_BPS) / BPS_DENOMINATOR;

            // Check user has granted sufficient allowance
            uint256 allowance = IERC20(token).allowance(userOp.sender, address(this));
            if (allowance < requiredToken) {
                revert InsufficientTokenAllowance(token, requiredToken, allowance);
            }

            // Check user has sufficient token balance
            uint256 balance = IERC20(token).balanceOf(userOp.sender);
            if (balance < requiredToken) {
                revert InsufficientTokenBalance(token, requiredToken, balance);
            }

            context = abi.encode(userOp.sender, mode, token, requiredToken, maxCost);
        } else {
            // ETH mode: enforce daily ETH gas spend limit
            _checkAndRecordDailyLimit(userOp.sender, maxCost);
            context = abi.encode(userOp.sender, mode, address(0), uint256(0), maxCost);
        }

        // Pack ERC-4337 validationData: sigFailure=0 | validUntil | validAfter
        validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << 208);
    }

    // ─────────────────────────────── ERC-4337 Post-Op ─────────────────────── //

    /// @dev Post-op: collect ERC-20 payment (mode=1) or emit ETH sponsorship event (mode=0).
    function _postOp(
        PostOpMode postOpMode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    )
        internal
        override
    {
        // If the op itself reverted, skip token collection to avoid double-charge
        if (postOpMode == PostOpMode.postOpReverted) return;

        (address account, PaymasterMode mode, address token, uint256 maxTokenAmount,) =
            abi.decode(context, (address, PaymasterMode, address, uint256, uint256));

        if (mode == PaymasterMode.ERC20) {
            // Compute actual token cost based on real gas consumed
            uint256 actualTokenAmount = oracle.getTokenAmount(token, actualGasCost);
            // Cap at the max that was pre-approved during validation
            uint256 chargeAmount =
                actualTokenAmount < maxTokenAmount ? actualTokenAmount : maxTokenAmount;

            IERC20(token).safeTransferFrom(account, address(this), chargeAmount);
            emit SponsoredWithToken(account, token, chargeAmount, actualGasCost);
        } else {
            emit SponsoredWithETH(account, actualGasCost);
        }
    }

    // ─────────────────────────────── Hash ─────────────────────────────────── //

    /// @notice Compute the hash that operators must sign to authorise a UserOp.
    /// @dev Includes chainId and paymaster address to prevent cross-chain/cross-contract replay.
    /// @param userOp The UserOperation to authorise
    /// @param mode Sponsorship mode (ETH or ERC-20)
    /// @param token Token address (zero for ETH mode)
    /// @param validUntil Signature expiry timestamp
    /// @param validAfter Signature activation timestamp
    /// @return Hash that the operator must sign
    function getHash(
        PackedUserOperation calldata userOp,
        PaymasterMode mode,
        address token,
        uint48 validUntil,
        uint48 validAfter
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.accountGasLimits,
                userOp.preVerificationGas,
                userOp.gasFees,
                block.chainid,
                address(this),
                uint8(mode),
                token,
                validUntil,
                validAfter
            )
        );
    }

    // ─────────────────────────────── Helpers ──────────────────────────────── //

    /// @dev Check and record daily ETH spend. Reverts if limit would be exceeded.
    function _checkAndRecordDailyLimit(address account, uint256 cost) internal {
        uint256 limit = dailyEthLimit[account];
        if (limit == 0) return; // unlimited

        uint256 today = block.timestamp / 1 days;
        uint256 spent = dailyEthSpent[account][today];
        if (spent + cost > limit) revert DailyLimitExceeded(account, limit, spent + cost);
        dailyEthSpent[account][today] = spent + cost;
    }

    /// @notice Withdraw accumulated ERC-20 token payments.
    /// @param token ERC-20 token to withdraw
    /// @param recipient Destination address
    /// @param amount Token amount to withdraw
    function withdrawToken(address token, address recipient, uint256 amount) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(recipient, amount);
    }
}
