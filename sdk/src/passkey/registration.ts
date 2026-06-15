import { startRegistration } from "@simplewebauthn/browser";
import type {
  PublicKeyCredentialCreationOptionsJSON,
  RegistrationResponseJSON,
} from "@simplewebauthn/types";
import type { Hex } from "viem";
import type { PasskeyPublicKey } from "../types.js";
import {
  base64urlToBytes,
  extractP256PublicKey,
  hashCredentialId,
  parseAuthenticatorData,
} from "./encoding.js";

export interface RegistrationOptions {
  challenge: string; // base64url from server
  rpName: string;
  rpId: string;
  userName: string;
  userId?: string;
}

export async function startPasskeyRegistration(
  options: RegistrationOptions
): Promise<RegistrationResponseJSON> {
  const opts: PublicKeyCredentialCreationOptionsJSON = {
    challenge: options.challenge,
    rp: { name: options.rpName, id: options.rpId },
    user: {
      id: btoa(options.userId ?? crypto.randomUUID()),
      name: options.userName,
      displayName: options.userName,
    },
    pubKeyCredParams: [{ alg: -7, type: "public-key" }], // ES256 (P-256)
    authenticatorSelection: {
      authenticatorAttachment: "platform",
      requireResidentKey: true,
      residentKey: "required",
      userVerification: "required",
    },
    attestation: "none",
    timeout: 120_000,
  };
  return startRegistration(opts);
}

export async function parseRegistrationResponse(response: RegistrationResponseJSON): Promise<{
  credentialId: string;
  credentialIdHash: Hex;
  publicKey: PasskeyPublicKey;
}> {
  const { id: credentialId, response: r } = response;

  const attestationBytes = base64urlToBytes(r.attestationObject);
  const authData = extractAuthDataFromAttestation(attestationBytes);
  const parsedFlags = parseAuthenticatorData(authData.buffer as ArrayBuffer);

  if (!parsedFlags.flags.hasAttestedCredential) {
    throw new Error("No attested credential data in registration response");
  }

  const coseKey = extractCoseKeyFromAuthData(authData, credentialId);
  const publicKey = extractP256PublicKey(coseKey);
  const credentialIdHash = await hashCredentialId(credentialId);

  return { credentialId, credentialIdHash, publicKey };
}

// ─── Safe byte reader ────────────────────────────────────────────────────── //

function readByte(buf: Uint8Array, index: number): number {
  const byte = buf[index];
  if (byte === undefined) throw new Error(`CBOR parse: unexpected end of buffer at index ${index}`);
  return byte;
}

// ─── CBOR Helpers ────────────────────────────────────────────────────────── //

function extractAuthDataFromAttestation(attestation: Uint8Array): Uint8Array {
  // Minimal CBOR decoder — find authData byte string in the map
  let offset = 0;
  if ((readByte(attestation, offset) & 0xe0) !== 0xa0) throw new Error("Expected CBOR map");
  const mapLen = readByte(attestation, offset) & 0x1f;
  offset++;

  for (let i = 0; i < mapLen; i++) {
    const keyByte = readByte(attestation, offset);
    const keyLen = keyByte & 0x1f;
    offset++;
    const key = new TextDecoder().decode(attestation.slice(offset, offset + keyLen));
    offset += keyLen;

    const valTag = readByte(attestation, offset);

    if (key === "authData") {
      // Handle CBOR byte string length encoding
      const majorType = valTag & 0xe0;
      const additionalInfo = valTag & 0x1f;
      offset++;

      if (majorType !== 0x40 && majorType !== 0x60) {
        throw new Error(`Unexpected CBOR type for authData: 0x${valTag.toString(16)}`);
      }

      let valLen: number;
      if (additionalInfo < 24) {
        valLen = additionalInfo;
      } else if (additionalInfo === 24) {
        valLen = readByte(attestation, offset);
        offset++;
      } else if (additionalInfo === 25) {
        valLen = (readByte(attestation, offset) << 8) | readByte(attestation, offset + 1);
        offset += 2;
      } else {
        throw new Error("Unsupported CBOR length encoding for authData");
      }

      return attestation.slice(offset, offset + valLen);
    }

    // Skip value
    const additionalInfo = valTag & 0x1f;
    offset++;
    if (additionalInfo < 24) {
      offset += additionalInfo;
    } else if (additionalInfo === 24) {
      const len = readByte(attestation, offset);
      offset++;
      offset += len;
    } else if (additionalInfo === 25) {
      const len = (readByte(attestation, offset) << 8) | readByte(attestation, offset + 1);
      offset += 2;
      offset += len;
    }
  }
  throw new Error("authData not found in attestation");
}

function extractCoseKeyFromAuthData(authData: Uint8Array, _credId: string): ArrayBuffer {
  // Skip: rpIdHash(32) + flags(1) + signCount(4) + aaguid(16) + credIdLen(2) + credId
  let offset = 37 + 16;
  const credIdLen = (readByte(authData, offset) << 8) | readByte(authData, offset + 1);
  offset += 2 + credIdLen;
  return authData.slice(offset).buffer as ArrayBuffer;
}
