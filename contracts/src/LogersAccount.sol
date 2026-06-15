// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {IAccount} from "@account-abstraction/interfaces/IAccount.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {ILogersAccount} from "./interfaces/ILogersAccount.sol";
import {WebAuthnLib} from "./libraries/WebAuthnLib.sol";

/// @title LogersAccount
/// @notice ERC-4337 smart wallet secured by WebAuthn passkeys.
///         Supports multiple passkey owners, ERC-1271 signature validation,
///         and UUPS upgrades authorised by the account itself.
/// @dev EntryPoint v0.7 compatible. P-256 verification via EIP-7212 + Daimo P256 fallback.
///      Storage layout is FROZEN — only append new state variables after existing ones.
contract LogersAccount is Initializable, UUPSUpgradeable, IAccount, ILogersAccount, IERC1271 {
    // ─────────────────────────────── Constants ────────────────────────────── //

    /// @dev Returned from validateUserOp to indicate a valid signature
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;

    /// @dev Returned from validateUserOp to indicate an invalid signature
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    /// @dev ERC-1271 magic value for a valid signature
    bytes4 internal constant ERC1271_MAGIC = 0x1626ba7e;

    /// @dev ERC-1271 return value for an invalid signature
    bytes4 internal constant ERC1271_INVALID = 0xffffffff;

    // ─────────────────────────────── Storage (frozen layout) ──────────────── //

    /// @dev Slot 0: EntryPoint reference
    IEntryPoint internal _entryPoint;

    /// @dev Slot 1: credentialId → Owner struct
    mapping(bytes32 => Owner) internal _owners;

    /// @dev Slot 2: ordered list of all credential IDs (for enumeration)
    bytes32[] internal _credentialIds;

    /// @dev Slot 3: active owner count
    uint256 internal _ownerCount;

    // ─────────────────────────────── Errors ───────────────────────────────── //

    /// @notice Caller is not the EntryPoint
    error OnlyEntryPoint();

    /// @notice Caller is neither the EntryPoint nor the account itself
    error OnlyEntryPointOrSelf();

    /// @notice Zero address supplied where non-zero is required
    error ZeroAddress();

    /// @notice Public key coordinates must both be non-zero
    error InvalidPublicKey();

    /// @notice A credential with this ID already has an active owner record
    error OwnerAlreadyExists(bytes32 credentialId);

    /// @notice No active owner record found for this credential ID
    error OwnerNotFound(bytes32 credentialId);

    /// @notice Cannot remove the last remaining owner
    error MustHaveAtLeastOneOwner();

    /// @notice A low-level call to `target` returned false
    error ExecutionFailed(address target, bytes returnData);

    /// @notice The EntryPoint prefund transfer failed
    error InsufficientFundsForPrefund(uint256 required, uint256 available);

    // ─────────────────────────────── Modifiers ────────────────────────────── //

    modifier onlyEntryPoint() {
        if (msg.sender != address(_entryPoint)) revert OnlyEntryPoint();
        _;
    }

    modifier onlyEntryPointOrSelf() {
        if (msg.sender != address(_entryPoint) && msg.sender != address(this)) {
            revert OnlyEntryPointOrSelf();
        }
        _;
    }

    // ─────────────────────────────── Constructor ──────────────────────────── //

    constructor() {
        _disableInitializers();
    }

    // ─────────────────────────────── Initializer ──────────────────────────── //

    /// @notice Initialise this account with the first passkey owner.
    /// @param entryPoint_ ERC-4337 EntryPoint address
    /// @param credentialId WebAuthn credential ID hashed to bytes32
    /// @param pubKeyX P-256 public key X coordinate
    /// @param pubKeyY P-256 public key Y coordinate
    function initialize(
        IEntryPoint entryPoint_,
        bytes32 credentialId,
        uint256 pubKeyX,
        uint256 pubKeyY
    ) external initializer {
        if (address(entryPoint_) == address(0)) revert ZeroAddress();
        if (pubKeyX == 0 || pubKeyY == 0) revert InvalidPublicKey();

        __UUPSUpgradeable_init();

        _entryPoint = entryPoint_;

        _addOwnerInternal(credentialId, pubKeyX, pubKeyY);
    }

    // ─────────────────────────────── ERC-4337 ─────────────────────────────── //

    /// @inheritdoc IAccount
    /// @notice Validates a UserOperation's WebAuthn signature.
    /// @dev Signature field encodes: abi.encode(bytes32 credentialId, WebAuthnLib.WebAuthnAuth auth)
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {
        // Prefund the EntryPoint if required
        if (missingAccountFunds > 0) {
            (bool success,) = payable(address(_entryPoint)).call{value: missingAccountFunds}("");
            if (!success) {
                revert InsufficientFundsForPrefund(missingAccountFunds, address(this).balance);
            }
        }

        // Decode the packed WebAuthn signature: (credentialId, WebAuthnAuth)
        (bytes32 credentialId, WebAuthnLib.WebAuthnAuth memory auth) =
            abi.decode(userOp.signature, (bytes32, WebAuthnLib.WebAuthnAuth));

        Owner storage owner = _owners[credentialId];
        if (!owner.active) return SIG_VALIDATION_FAILED;

        bool valid = WebAuthnLib.verify(
            userOpHash,
            true, // always require biometric (UV flag) for on-chain ops
            auth,
            owner.pubKeyX,
            owner.pubKeyY
        );

        return valid ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }

    // ─────────────────────────────── Execution ────────────────────────────── //

    /// @inheritdoc ILogersAccount
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        override
        onlyEntryPointOrSelf
    {
        _executeCall(target, value, data);
        emit ExecutedTransaction(target, value, data);
    }

    /// @inheritdoc ILogersAccount
    function executeBatch(Call[] calldata calls) external payable override onlyEntryPointOrSelf {
        uint256 len = calls.length;
        for (uint256 i; i < len;) {
            _executeCall(calls[i].target, calls[i].value, calls[i].data);
            unchecked {
                ++i;
            }
        }
        emit ExecutedBatch(len);
    }

    /// @dev Low-level call helper. Reverts with return data on failure.
    function _executeCall(address target, uint256 value, bytes calldata data) internal {
        if (target == address(0)) revert ZeroAddress();
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (!success) revert ExecutionFailed(target, returnData);
    }

    // ─────────────────────────────── Owner Management ─────────────────────── //

    /// @inheritdoc ILogersAccount
    function addOwner(bytes32 credentialId, uint256 pubKeyX, uint256 pubKeyY)
        external
        override
        onlyEntryPointOrSelf
    {
        if (pubKeyX == 0 || pubKeyY == 0) revert InvalidPublicKey();
        if (_owners[credentialId].active) revert OwnerAlreadyExists(credentialId);
        _addOwnerInternal(credentialId, pubKeyX, pubKeyY);
    }

    /// @inheritdoc ILogersAccount
    function removeOwner(bytes32 credentialId) external override onlyEntryPointOrSelf {
        if (!_owners[credentialId].active) revert OwnerNotFound(credentialId);
        if (_ownerCount == 1) revert MustHaveAtLeastOneOwner();
        _owners[credentialId].active = false;
        unchecked {
            --_ownerCount;
        }
        emit OwnerRemoved(credentialId);
    }

    /// @dev Internal helper to add an owner without guard checks.
    function _addOwnerInternal(bytes32 credentialId, uint256 pubKeyX, uint256 pubKeyY) internal {
        _owners[credentialId] = Owner({pubKeyX: pubKeyX, pubKeyY: pubKeyY, active: true});
        _credentialIds.push(credentialId);
        unchecked {
            ++_ownerCount;
        }
        emit OwnerAdded(credentialId, pubKeyX, pubKeyY);
    }

    // ─────────────────────────────── ERC-1271 ─────────────────────────────── //

    /// @inheritdoc IERC1271
    /// @dev Signature: abi.encode(bytes32 credentialId, WebAuthnLib.WebAuthnAuth auth)
    ///      UV is NOT required for off-chain signing (only for on-chain UserOps).
    function isValidSignature(bytes32 hash, bytes calldata signature)
        external
        view
        override
        returns (bytes4)
    {
        (bytes32 credentialId, WebAuthnLib.WebAuthnAuth memory auth) =
            abi.decode(signature, (bytes32, WebAuthnLib.WebAuthnAuth));

        Owner storage owner = _owners[credentialId];
        if (!owner.active) return ERC1271_INVALID;

        bool valid = WebAuthnLib.verify(hash, false, auth, owner.pubKeyX, owner.pubKeyY);

        return valid ? ERC1271_MAGIC : ERC1271_INVALID;
    }

    // ─────────────────────────────── UUPS ─────────────────────────────────── //

    /// @dev Upgrade is authorised only via the EntryPoint (i.e., via a UserOp) or self-call.
    function _authorizeUpgrade(address newImplementation) internal override onlyEntryPointOrSelf {
        if (newImplementation == address(0)) revert ZeroAddress();
    }

    // ─────────────────────────────── View ─────────────────────────────────── //

    /// @inheritdoc ILogersAccount
    function isOwner(bytes32 credentialId) external view override returns (bool) {
        return _owners[credentialId].active;
    }

    /// @inheritdoc ILogersAccount
    function getOwner(bytes32 credentialId) external view override returns (Owner memory) {
        if (!_owners[credentialId].active) revert OwnerNotFound(credentialId);
        return _owners[credentialId];
    }

    /// @inheritdoc ILogersAccount
    function ownerCount() external view override returns (uint256) {
        return _ownerCount;
    }

    /// @inheritdoc ILogersAccount
    function entryPoint() external view override returns (address) {
        return address(_entryPoint);
    }

    /// @inheritdoc ILogersAccount
    function getAllCredentialIds() external view override returns (bytes32[] memory) {
        return _credentialIds;
    }

    receive() external payable {}

    fallback() external payable {}
}
