// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {LogersAccount} from "./LogersAccount.sol";

/// @title LogersAccountFactory
/// @notice Deterministic CREATE2 factory for LogersAccount proxies.
///         Idempotent: calling createAccount twice for the same parameters
///         returns the same address without deploying again.
///         First UserOperation can include initCode = factory.getInitCode(...)
/// @dev Deploys a single shared LogersAccount implementation and creates
///      ERC-1967 proxy instances per user credential.
contract LogersAccountFactory is Ownable {
    // ─────────────────────────────── Immutables ───────────────────────────── //

    /// @notice The shared LogersAccount implementation (logic contract)
    LogersAccount public immutable accountImplementation;

    /// @notice ERC-4337 EntryPoint v0.7
    IEntryPoint public immutable entryPoint;

    // ─────────────────────────────── Events ───────────────────────────────── //

    /// @notice Emitted when a new LogersAccount proxy is deployed
    event AccountDeployed(
        address indexed account, bytes32 indexed credentialId, uint256 pubKeyX, uint256 pubKeyY
    );

    // ─────────────────────────────── Errors ───────────────────────────────── //

    /// @notice Zero address supplied where non-zero is required
    error ZeroAddress();

    /// @notice Public key coordinates must both be non-zero
    error InvalidPublicKey();

    /// @notice CREATE2 deployment returned address(0)
    error DeploymentFailed();

    // ─────────────────────────────── Constructor ──────────────────────────── //

    /// @param entryPoint_ ERC-4337 EntryPoint address
    /// @param factoryOwner Address that owns this factory (can pause, etc.)
    constructor(IEntryPoint entryPoint_, address factoryOwner) Ownable(factoryOwner) {
        if (address(entryPoint_) == address(0)) revert ZeroAddress();
        if (factoryOwner == address(0)) revert ZeroAddress();

        entryPoint = entryPoint_;
        accountImplementation = new LogersAccount();
    }

    // ─────────────────────────────── Deploy ───────────────────────────────── //

    /// @notice Deploy a new LogersAccount for a passkey. Idempotent — returns
    ///         existing account if already deployed for the same parameters.
    /// @param credentialId WebAuthn credential ID hashed to bytes32
    /// @param pubKeyX P-256 public key X coordinate
    /// @param pubKeyY P-256 public key Y coordinate
    /// @param salt Additional salt (use 0 for standard single-device wallets)
    /// @return account The deployed or pre-existing LogersAccount proxy
    function createAccount(bytes32 credentialId, uint256 pubKeyX, uint256 pubKeyY, uint256 salt)
        external
        returns (LogersAccount account)
    {
        if (pubKeyX == 0 || pubKeyY == 0) revert InvalidPublicKey();

        address predicted = getAddress(credentialId, pubKeyX, pubKeyY, salt);

        // Idempotent: return existing account if already deployed
        if (predicted.code.length > 0) {
            return LogersAccount(payable(predicted));
        }

        bytes memory initializer =
            abi.encodeCall(LogersAccount.initialize, (entryPoint, credentialId, pubKeyX, pubKeyY));

        bytes32 derivedSalt = _deriveSalt(credentialId, pubKeyX, pubKeyY, salt);

        ERC1967Proxy proxy =
            new ERC1967Proxy{salt: derivedSalt}(address(accountImplementation), initializer);

        if (address(proxy) == address(0)) revert DeploymentFailed();

        account = LogersAccount(payable(address(proxy)));
        emit AccountDeployed(address(account), credentialId, pubKeyX, pubKeyY);
    }

    // ─────────────────────────────── Prediction ───────────────────────────── //

    /// @notice Predict the CREATE2 address for given parameters before deployment.
    /// @param credentialId WebAuthn credential ID hashed to bytes32
    /// @param pubKeyX P-256 public key X coordinate
    /// @param pubKeyY P-256 public key Y coordinate
    /// @param salt Additional salt
    /// @return Predicted proxy address
    function getAddress(bytes32 credentialId, uint256 pubKeyX, uint256 pubKeyY, uint256 salt)
        public
        view
        returns (address)
    {
        bytes32 derivedSalt = _deriveSalt(credentialId, pubKeyX, pubKeyY, salt);

        bytes memory initializer =
            abi.encodeCall(LogersAccount.initialize, (entryPoint, credentialId, pubKeyX, pubKeyY));

        bytes memory creationCode = abi.encodePacked(
            type(ERC1967Proxy).creationCode, abi.encode(address(accountImplementation), initializer)
        );

        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff), address(this), derivedSalt, keccak256(creationCode)
                        )
                    )
                )
            )
        );
    }

    /// @notice Build initCode bytes for use in a first-UserOperation deployment.
    /// @param credentialId WebAuthn credential ID hashed to bytes32
    /// @param pubKeyX P-256 public key X coordinate
    /// @param pubKeyY P-256 public key Y coordinate
    /// @param salt Additional salt
    /// @return initCode bytes to place in UserOperation.initCode
    function getInitCode(bytes32 credentialId, uint256 pubKeyX, uint256 pubKeyY, uint256 salt)
        external
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            address(this),
            abi.encodeCall(this.createAccount, (credentialId, pubKeyX, pubKeyY, salt))
        );
    }

    // ─────────────────────────────── Internal ─────────────────────────────── //

    /// @dev Combine all inputs into a single CREATE2 salt for determinism.
    function _deriveSalt(bytes32 credentialId, uint256 pubKeyX, uint256 pubKeyY, uint256 salt)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(credentialId, pubKeyX, pubKeyY, salt));
    }
}
