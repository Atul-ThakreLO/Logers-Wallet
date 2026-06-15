// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";

/// @title UserOperationLib
/// @notice Utilities for ERC-4337 v0.7 PackedUserOperation packing/unpacking.
///         Mirrors the layout defined in ERC-4337 v0.7 spec.
library UserOperationLib {
    /// @notice Hash a UserOperation without chain or entrypoint context.
    ///         Used to compute a canonical ID for the op before signing.
    /// @param op The packed UserOperation to hash
    /// @return The keccak256 hash of the op's fields (excluding signature)
    function hash(PackedUserOperation calldata op) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                op.sender,
                op.nonce,
                keccak256(op.initCode),
                keccak256(op.callData),
                op.accountGasLimits,
                op.preVerificationGas,
                op.gasFees,
                keccak256(op.paymasterAndData)
            )
        );
    }

    /// @notice Unpack verificationGasLimit from the high 128 bits of accountGasLimits.
    /// @param op The packed UserOperation
    /// @return The verification gas limit
    function unpackVerificationGasLimit(PackedUserOperation calldata op)
        internal
        pure
        returns (uint128)
    {
        return uint128(bytes16(op.accountGasLimits));
    }

    /// @notice Unpack callGasLimit from the low 128 bits of accountGasLimits.
    /// @param op The packed UserOperation
    /// @return The call gas limit
    function unpackCallGasLimit(PackedUserOperation calldata op) internal pure returns (uint128) {
        return uint128(uint256(op.accountGasLimits));
    }

    /// @notice Unpack maxPriorityFeePerGas from the high 128 bits of gasFees.
    /// @param op The packed UserOperation
    /// @return The max priority fee per gas
    function unpackMaxPriorityFeePerGas(PackedUserOperation calldata op)
        internal
        pure
        returns (uint128)
    {
        return uint128(bytes16(op.gasFees));
    }

    /// @notice Unpack maxFeePerGas from the low 128 bits of gasFees.
    /// @param op The packed UserOperation
    /// @return The max fee per gas
    function unpackMaxFeePerGas(PackedUserOperation calldata op) internal pure returns (uint128) {
        return uint128(uint256(op.gasFees));
    }
}
