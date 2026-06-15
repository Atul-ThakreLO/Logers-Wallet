// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LogersAccount} from "../../src/LogersAccount.sol";
import {LogersAccountFactory} from "../../src/LogersAccountFactory.sol";
import {LogersPaymaster} from "../../src/LogersPaymaster.sol";
import {LogersPriceOracle} from "../../src/oracle/LogersPriceOracle.sol";
import {WebAuthnLib} from "../../src/libraries/WebAuthnLib.sol";
import {ILogersPaymaster} from "../../src/interfaces/ILogersPaymaster.sol";
import {MockChainlinkFeed} from "./MockChainlinkFeed.sol";

// ─── Mock ERC-20 ─────────────────────────────────────────────────────────── //

/// @dev Bare-bones ERC-20 used in tests, configurable decimals and free mint.
contract MockERC20 is ERC20 {
    uint8 private _dec;

    constructor(string memory name, string memory symbol, uint8 dec) ERC20(name, symbol) {
        _dec = dec;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// ─── TestHelper ──────────────────────────────────────────────────────────── //

/// @title TestHelper
/// @notice Base contract for all LogersWallet Foundry tests.
///         Deploys the full contract stack with deterministic test values.
abstract contract TestHelper is Test {
    // ─── Core contracts ─────────────────────────────────────────────────── //
    EntryPoint internal entryPoint;
    LogersAccountFactory internal factory;
    LogersPaymaster internal paymaster;
    LogersPriceOracle internal oracle;
    MockERC20 internal usdc;
    MockChainlinkFeed internal usdcFeed;

    // ─── Test passkey constants (deterministic, not real cryptography) ───── //

    /// @dev Fixed credential ID derived from a well-known string
    bytes32 internal constant CRED_ID = keccak256("test-logers-credential");

    /// @dev P-256 public key X — bounded to uint128 max to stay within curve field
    uint256 internal constant PUB_X = uint256(keccak256("pubkeyX")) % type(uint128).max + 1;

    /// @dev P-256 public key Y — bounded to uint128 max to stay within curve field
    uint256 internal constant PUB_Y = uint256(keccak256("pubkeyY")) % type(uint128).max + 1;

    // ─── Mock price: 1 USDC = 0.0003 ETH ───────────────────────────────── //
    int256 internal constant MOCK_USDC_ETH_PRICE = 0.0003 ether;

    // ─── Actors ─────────────────────────────────────────────────────────── //
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    uint256 internal paymasterOperatorKey = uint256(keccak256("pm-operator"));
    address internal paymasterOperator;

    // ─────────────────────────────────────────────────────────────────────── //

    function setUp() public virtual {
        paymasterOperator = vm.addr(paymasterOperatorKey);

        // EntryPoint
        entryPoint = new EntryPoint();

        // Oracle + mock USDC feed
        oracle = new LogersPriceOracle(address(this));
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdcFeed = new MockChainlinkFeed(MOCK_USDC_ETH_PRICE);
        oracle.addFeed(address(usdc), address(usdcFeed));

        // Factory — no P256Verifier argument (uses P256 lib internally)
        factory = new LogersAccountFactory(entryPoint, address(this));

        // Paymaster
        paymaster = new LogersPaymaster(entryPoint, oracle, address(this));
        paymaster.addOperator(paymasterOperator);
        paymaster.whitelistToken(address(usdc));

        // Fund paymaster deposit on EntryPoint
        vm.deal(address(this), 10 ether);
        paymaster.deposit{value: 1 ether}();
    }

    // ─────────────────────────────────────────────────────────────────────── //
    // Helper builders
    // ─────────────────────────────────────────────────────────────────────── //

    /// @dev Build a minimal PackedUserOperation for a given sender and callData.
    function _buildUserOp(address sender, bytes memory callData)
        internal
        view
        returns (PackedUserOperation memory)
    {
        return PackedUserOperation({
            sender: sender,
            nonce: entryPoint.getNonce(sender, 0),
            initCode: bytes(""),
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(300_000), uint128(300_000))),
            preVerificationGas: 50_000,
            gasFees: bytes32(abi.encodePacked(uint128(1 gwei), uint128(1 gwei))),
            paymasterAndData: bytes(""),
            signature: _mockWebAuthnSig()
        });
    }

    /// @dev Produce a mock WebAuthn signature that passes the always-returns-true
    ///      P256 EIP-7212 precompile mock (deployed in _deployAlwaysTruePrecompile).
    function _mockWebAuthnSig() internal pure returns (bytes memory) {
        // The authenticatorData below has:
        //   - 32-byte rpIdHash (any bytes)
        //   - flags byte 0x05 = UP(1) | UV(4)
        //   - 4-byte sign counter
        // Total = 37 bytes (minimum valid length)
        WebAuthnLib.WebAuthnAuth memory auth = WebAuthnLib.WebAuthnAuth({
            authenticatorData: abi.encodePacked(
                keccak256("rpId"), // 32-byte rpIdHash
                bytes1(0x05), //     flags: UP + UV
                bytes4(0x00000001) // signCount = 1
            ),
            clientDataJSON: '{"type":"webauthn.get","challenge":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","origin":"http://localhost:3000"}',
            challengeIndex: 23,
            typeIndex: 1,
            r: PUB_X,
            s: PUB_Y
        });
        return abi.encode(CRED_ID, auth);
    }

    /// @dev Deploy a mock P256 EIP-7212 precompile at address(0x100) that always
    ///      returns 1 (valid). Used so WebAuthnLib._verifyP256Sig passes in tests
    ///      without real P-256 arithmetic.
    function _deployAlwaysTruePrecompile() internal {
        // Bytecode: PUSH1 1, PUSH1 0, MSTORE, PUSH1 32, PUSH1 0, RETURN
        // Returns abi-encoded uint256(1) — "signature valid"
        bytes memory code = hex"6001600052602060006000f3"; // slightly adjusted to return 32 bytes
        // Simpler: store 1 at mem[0] and return 32 bytes from mem[0]
        // 60 01 = PUSH1 0x01
        // 60 00 = PUSH1 0x00
        // 52    = MSTORE  (stores 1 at bytes [0..31])
        // 60 20 = PUSH1 0x20 (32)
        // 60 00 = PUSH1 0x00
        // F3    = RETURN
        bytes memory deployBytecode = hex"600160005260206000f3";
        address precompile = address(0x0000000000000000000000000000000000000100);
        vm.etch(precompile, deployBytecode);
    }

    /// @dev Deploy a LogersAccount for CRED_ID/PUB_X/PUB_Y and return it.
    function _deployAliceAccount() internal returns (LogersAccount) {
        return factory.createAccount(CRED_ID, PUB_X, PUB_Y, 0);
    }

    /// @dev Sign paymaster hash with a given private key for operator testing.
    function _signPaymasterHash(bytes32 hash, uint256 privateKey)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethHash);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Build paymasterAndData for ETH mode (mode=0).
    function _buildEthModePaymasterData(
        PackedUserOperation memory userOp,
        uint48 validUntil,
        uint48 validAfter,
        uint256 signerKey
    ) internal view returns (bytes memory) {
        ILogersPaymaster.PaymasterMode mode = ILogersPaymaster.PaymasterMode.ETH;
        bytes32 hash = paymaster.getHash(userOp, mode, address(0), validUntil, validAfter);
        bytes memory sig = _signPaymasterHash(hash, signerKey);

        bytes memory customData = abi.encodePacked(
            uint8(0), // mode = ETH
            address(0), // token = zero
            validUntil,
            validAfter,
            sig
        );

        // paymasterAndData = address(paymaster) ++ validationGas ++ postOpGas ++ customData
        return abi.encodePacked(
            address(paymaster),
            uint128(150_000), // verificationGasLimit
            uint128(50_000), //  postOpGasLimit
            customData
        );
    }

    /// @dev Build paymasterAndData for ERC-20 mode (mode=1).
    function _buildErc20ModePaymasterData(
        PackedUserOperation memory userOp,
        address token,
        uint48 validUntil,
        uint48 validAfter,
        uint256 signerKey
    ) internal view returns (bytes memory) {
        ILogersPaymaster.PaymasterMode mode = ILogersPaymaster.PaymasterMode.ERC20;
        bytes32 hash = paymaster.getHash(userOp, mode, token, validUntil, validAfter);
        bytes memory sig = _signPaymasterHash(hash, signerKey);

        bytes memory customData = abi.encodePacked(
            uint8(1), // mode = ERC-20
            token,
            validUntil,
            validAfter,
            sig
        );

        return abi.encodePacked(address(paymaster), uint128(150_000), uint128(50_000), customData);
    }
}
