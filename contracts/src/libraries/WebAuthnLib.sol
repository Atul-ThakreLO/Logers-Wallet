// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title WebAuthnLib
/// @notice Verifies WebAuthn P-256 (secp256r1) signatures on-chain.
/// @dev Supports EIP-7212 precompile on Base/OP-Stack chains.
///      Falls back to Daimo p256-verifier software fallback when precompile unavailable.
///      Both the EIP-7212 precompile (0x100) and the Daimo verifier (0xc2b7...) use
///      the same 160-byte raw ABI: hash(32) | r(32) | s(32) | x(32) | y(32).
///      We call via staticcall directly to avoid importing the P256.sol library
///      (which uses `pragma solidity 0.8.21`, incompatible with our 0.8.25 build).
library WebAuthnLib {
    // ─────────────────────────────── Constants ────────────────────────────── //

    /// @dev EIP-7212 P-256 precompile address (Base Sepolia + Base mainnet)
    address internal constant EIP7212_PRECOMPILE = 0x0000000000000000000000000000000000000100;

    /// @dev Daimo p256-verifier contract address (deployed on many EVM chains)
    ///      Source: https://github.com/daimo-eth/p256-verifier
    address internal constant DAIMO_P256_VERIFIER = 0xc2b78104907F722DABAc4C69f826a522B2754De4;

    /// @dev P-256 curve order n/2 used for lower-S (anti-malleability) check
    uint256 internal constant P256_N_DIV_2 =
        57_896_044_605_178_124_381_348_723_474_703_786_764_998_477_612_067_880_171_211_129_530_534_256_022_184;

    /// @dev WebAuthn flag bit: user present
    uint8 internal constant AUTH_FLAG_UP = 0x01;

    /// @dev WebAuthn flag bit: user verified (biometric)
    uint8 internal constant AUTH_FLAG_UV = 0x04;

    // ─────────────────────────────── Errors ───────────────────────────────── //

    /// @notice authenticatorData shorter than the minimum 37 bytes
    error InvalidAuthDataLength();

    /// @notice User-present flag is not set in authenticatorData
    error UserNotPresent();

    /// @notice User-verified flag is not set but was required
    error UserNotVerified();

    /// @notice clientDataJSON does not contain the expected challenge or type
    error InvalidChallenge();

    /// @notice P-256 signature verification failed
    error InvalidSignature();

    /// @notice base64url input has an invalid length or character
    error InvalidBase64UrlEncoding();

    // ─────────────────────────────── Types ────────────────────────────────── //

    /// @notice Full WebAuthn assertion passed for on-chain verification
    struct WebAuthnAuth {
        /// @dev authenticatorData bytes returned by authenticator (≥37 bytes)
        bytes authenticatorData;
        /// @dev clientDataJSON string (must contain challenge as base64url)
        string clientDataJSON;
        /// @dev byte offset of `"challenge"` key within clientDataJSON
        uint256 challengeIndex;
        /// @dev byte offset of `"type"` key within clientDataJSON
        uint256 typeIndex;
        /// @dev r component of DER-decoded P-256 signature (lower-S normalised)
        uint256 r;
        /// @dev s component of P-256 signature
        uint256 s;
    }

    // ─────────────────────────────── Core ─────────────────────────────────── //

    /// @notice Verify a WebAuthn assertion against an expected challenge.
    /// @param challenge Expected challenge bytes32 (typically the userOpHash)
    /// @param requireUV Require user verification flag (biometric confirmation)
    /// @param auth The assertion data from the authenticator
    /// @param x P-256 public key X coordinate of the credential owner
    /// @param y P-256 public key Y coordinate of the credential owner
    /// @return valid True if the WebAuthn assertion is cryptographically valid
    function verify(
        bytes32 challenge,
        bool requireUV,
        WebAuthnAuth memory auth,
        uint256 x,
        uint256 y
    ) internal view returns (bool valid) {
        // 1. Minimum length: rpIdHash(32) + flags(1) + signCount(4) = 37 bytes
        if (auth.authenticatorData.length < 37) revert InvalidAuthDataLength();

        // 2. Check user-present and user-verified flags
        bytes1 flags = auth.authenticatorData[32];
        if (uint8(flags) & AUTH_FLAG_UP == 0) revert UserNotPresent();
        if (requireUV && (uint8(flags) & AUTH_FLAG_UV == 0)) revert UserNotVerified();

        // 3. Verify clientDataJSON contains the expected challenge at challengeIndex
        _verifyClientDataChallenge(
            challenge, auth.clientDataJSON, auth.challengeIndex, auth.typeIndex
        );

        // 4. Compute signed message:
        //    SHA-256(authenticatorData || SHA-256(clientDataJSON))
        bytes32 clientDataHash = sha256(bytes(auth.clientDataJSON));
        bytes32 messageHash = sha256(abi.encodePacked(auth.authenticatorData, clientDataHash));

        // 5. Verify P-256 signature (try EIP-7212 precompile first, fallback to Daimo)
        valid = _verifyP256Sig(messageHash, auth.r, auth.s, x, y);
    }

    // ─────────────────────────────── Internal ─────────────────────────────── //

    /// @dev Verify that clientDataJSON contains the correct type and challenge values.
    function _verifyClientDataChallenge(
        bytes32 challenge,
        string memory clientDataJSON,
        uint256 challengeIndex,
        uint256 typeIndex
    ) private pure {
        bytes memory data = bytes(clientDataJSON);

        // Verify type field: value starts at typeIndex + 8 (after `"type":`)
        bytes memory expectedType = bytes('"webauthn.get"');
        bytes memory actualType = _sliceBytes(data, typeIndex + 8, expectedType.length);
        if (keccak256(actualType) != keccak256(expectedType)) revert InvalidChallenge();

        // Verify challenge: value starts at challengeIndex + 13 (after `"challenge":`)
        // base64url(32 bytes) = 43 chars
        bytes memory encodedChallenge = _sliceBytes(data, challengeIndex + 13, 43);
        bytes memory decodedChallenge = _base64urlDecode43(encodedChallenge);
        if (bytes32(decodedChallenge) != challenge) revert InvalidChallenge();
    }

    /// @dev Try EIP-7212 precompile then Daimo software verifier.
    ///      Both accept the same 160-byte input: hash | r | s | x | y.
    ///      Rejects high-S (malleable) signatures before any external call.
    function _verifyP256Sig(bytes32 messageHash, uint256 r, uint256 s, uint256 x, uint256 y)
        private
        view
        returns (bool)
    {
        // Reject high-S malleable signatures (lower-S normalization per BIP-146)
        if (s > P256_N_DIV_2) return false;

        // Build the 160-byte input the verifier expects
        bytes memory input = abi.encode(messageHash, r, s, x, y);

        // Attempt EIP-7212 precompile (very cheap on Base / OP-Stack chains)
        (bool ok, bytes memory result) = EIP7212_PRECOMPILE.staticcall(input);
        if (ok && result.length == 32 && abi.decode(result, (uint256)) == 1) {
            return true;
        }

        // Software fallback: Daimo p256-verifier (deployed at well-known address)
        (bool ok2, bytes memory result2) = DAIMO_P256_VERIFIER.staticcall(input);
        if (ok2 && result2.length == 32) {
            return abi.decode(result2, (uint256)) == 1;
        }

        return false;
    }

    /// @dev Slice `length` bytes from `data` starting at `start`. Reverts if out of bounds.
    function _sliceBytes(bytes memory data, uint256 start, uint256 length)
        private
        pure
        returns (bytes memory result)
    {
        if (start + length > data.length) revert InvalidAuthDataLength();
        result = new bytes(length);
        for (uint256 i; i < length;) {
            result[i] = data[start + i];
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Decode exactly 43 base64url chars → 32 bytes (for a bytes32 challenge).
    function _base64urlDecode43(bytes memory encoded) private pure returns (bytes memory) {
        if (encoded.length != 43) revert InvalidBase64UrlEncoding();
        bytes memory result = new bytes(32);
        uint256 j;
        for (uint256 i; i + 3 < encoded.length;) {
            uint256 a = _b64Val(encoded[i]);
            uint256 b = _b64Val(encoded[i + 1]);
            uint256 c = _b64Val(encoded[i + 2]);
            uint256 d = (i + 3 < encoded.length) ? _b64Val(encoded[i + 3]) : 0;
            if (j < 32) result[j++] = bytes1(uint8((a << 2) | (b >> 4)));
            if (j < 32) result[j++] = bytes1(uint8((b << 4) | (c >> 2)));
            if (j < 32) result[j++] = bytes1(uint8((c << 6) | d));
            unchecked {
                i += 4;
            }
        }
        return result;
    }

    /// @dev Decode a single base64url character to its 6-bit value.
    function _b64Val(bytes1 c) private pure returns (uint256) {
        uint8 v = uint8(c);
        if (v >= 65 && v <= 90) return uint256(v - 65); // A-Z → 0-25
        if (v >= 97 && v <= 122) return uint256(v - 71); // a-z → 26-51
        if (v >= 48 && v <= 57) return uint256(v + 4); //  0-9 → 52-61
        if (v == 45) return 62; //                          '-'
        if (v == 95) return 63; //                          '_'
        revert InvalidBase64UrlEncoding();
    }
}
