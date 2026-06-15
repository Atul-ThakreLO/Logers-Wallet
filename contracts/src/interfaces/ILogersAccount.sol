// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title ILogersAccount
/// @notice Public interface for the LogersAccount smart wallet
interface ILogersAccount {
    // ─── Events ───────────────────────────────────────────────────────────── //

    /// @notice Emitted when a new passkey owner is added
    event OwnerAdded(bytes32 indexed credentialId, uint256 pubKeyX, uint256 pubKeyY);

    /// @notice Emitted when a passkey owner is removed
    event OwnerRemoved(bytes32 indexed credentialId);

    /// @notice Emitted after a successful single call execution
    event ExecutedTransaction(address indexed to, uint256 value, bytes data);

    /// @notice Emitted after a successful batch execution
    event ExecutedBatch(uint256 operationCount);

    // ─── Types ────────────────────────────────────────────────────────────── //

    /// @notice Passkey owner record stored per credential ID
    struct Owner {
        uint256 pubKeyX;
        uint256 pubKeyY;
        bool active;
    }

    /// @notice A single call within a batch execution
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    // ─── Owner Management ─────────────────────────────────────────────────── //

    /// @notice Add a new passkey owner
    /// @param credentialId WebAuthn credential ID hashed to bytes32
    /// @param pubKeyX P-256 public key X coordinate
    /// @param pubKeyY P-256 public key Y coordinate
    function addOwner(bytes32 credentialId, uint256 pubKeyX, uint256 pubKeyY) external;

    /// @notice Remove an existing passkey owner
    /// @param credentialId WebAuthn credential ID hashed to bytes32
    function removeOwner(bytes32 credentialId) external;

    /// @notice Check whether a credential ID has an active owner record
    /// @param credentialId WebAuthn credential ID hashed to bytes32
    /// @return True if the credential is an active owner
    function isOwner(bytes32 credentialId) external view returns (bool);

    /// @notice Fetch the full owner struct for a credential
    /// @param credentialId WebAuthn credential ID hashed to bytes32
    /// @return The Owner struct (reverts if not active)
    function getOwner(bytes32 credentialId) external view returns (Owner memory);

    /// @notice Return the number of currently active owners
    function ownerCount() external view returns (uint256);

    /// @notice Return all registered credential IDs (including removed ones)
    function getAllCredentialIds() external view returns (bytes32[] memory);

    // ─── Execution ────────────────────────────────────────────────────────── //

    /// @notice Execute a single call from the account
    /// @param target Destination address
    /// @param value ETH value in wei to forward
    /// @param data Call data to forward
    function execute(address target, uint256 value, bytes calldata data) external payable;

    /// @notice Execute a batch of calls atomically
    /// @param calls Array of Call structs to execute in order
    function executeBatch(Call[] calldata calls) external payable;

    // ─── Info ─────────────────────────────────────────────────────────────── //

    /// @notice Return the ERC-4337 EntryPoint this account trusts
    function entryPoint() external view returns (address);
}
