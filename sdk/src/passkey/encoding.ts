import type { Hex } from "viem";
import { bytesToHex, encodeAbiParameters } from "viem";

// ─── Base64URL Utilities ────────────────────────────────────────────────── //

export function base64urlToBytes(base64url: string): Uint8Array {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), "=");
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

export function bytesToBase64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

// ─── Credential ID Hashing ──────────────────────────────────────────────── //

export async function hashCredentialId(credentialId: string): Promise<Hex> {
  const bytes = base64urlToBytes(credentialId);
  const hash = await crypto.subtle.digest("SHA-256", bytes as unknown as BufferSource);
  return bytesToHex(new Uint8Array(hash)) as Hex;
}

// ─── Safe byte reader ────────────────────────────────────────────────────── //

function readByte(buf: Uint8Array, index: number): number {
  const byte = buf[index];
  if (byte === undefined)
    throw new Error(`Parse error: unexpected end of buffer at index ${index}`);
  return byte;
}

// ─── COSE Key Extraction ────────────────────────────────────────────────── //

export function extractP256PublicKey(cosePublicKey: ArrayBuffer): { x: Hex; y: Hex } {
  const bytes = new Uint8Array(cosePublicKey);
  let offset = 0;

  if ((readByte(bytes, offset) & 0xe0) !== 0xa0) throw new Error("Expected CBOR map");
  const mapLen = readByte(bytes, offset) & 0x1f;
  offset++;

  let xBytes: Uint8Array | null = null;
  let yBytes: Uint8Array | null = null;

  for (let i = 0; i < mapLen; i++) {
    const keyByte = readByte(bytes, offset);
    let key: number;

    if ((keyByte & 0xe0) === 0x20) {
      key = -1 - (keyByte & 0x1f);
      offset++;
    } else {
      key = keyByte & 0x1f;
      offset++;
    }

    const valByte = readByte(bytes, offset);
    if ((valByte & 0xe0) === 0x40) {
      // Byte string
      let len: number;
      if ((valByte & 0x1f) === 24) {
        offset++;
        len = readByte(bytes, offset);
        offset++;
      } else {
        len = valByte & 0x1f;
        offset++;
      }
      const val = bytes.slice(offset, offset + len);
      offset += len;
      if (key === -2) xBytes = val;
      else if (key === -3) yBytes = val;
    } else {
      // Skip (integer, text, etc.)
      if ((valByte & 0xe0) === 0x00 || (valByte & 0xe0) === 0x20) offset++;
      else if ((valByte & 0xe0) === 0x60) {
        const l = valByte & 0x1f;
        offset++;
        offset += l;
      } else offset++;
    }
  }

  if (!xBytes || !yBytes) throw new Error("P-256 coordinates not found in COSE key");
  if (xBytes.length !== 32 || yBytes.length !== 32) throw new Error("Invalid P-256 key length");

  return {
    x: bytesToHex(xBytes) as Hex,
    y: bytesToHex(yBytes) as Hex,
  };
}

// ─── Authenticator Data Parser ──────────────────────────────────────────── //

export function parseAuthenticatorData(authData: ArrayBuffer): {
  rpIdHash: Hex;
  flags: { userPresent: boolean; userVerified: boolean; hasAttestedCredential: boolean };
  signCount: number;
} {
  const view = new DataView(authData);
  const bytes = new Uint8Array(authData);
  const flagsByte = readByte(bytes, 32);
  return {
    rpIdHash: bytesToHex(bytes.slice(0, 32)) as Hex,
    flags: {
      userPresent: (flagsByte & 0x01) !== 0,
      userVerified: (flagsByte & 0x04) !== 0,
      hasAttestedCredential: (flagsByte & 0x40) !== 0,
    },
    signCount: view.getUint32(33, false),
  };
}

// ─── WebAuthn Signature Encoding ────────────────────────────────────────── //

export function encodeWebAuthnSignature(params: {
  credentialIdHash: Hex;
  authenticatorData: Uint8Array;
  clientDataJSON: string;
  challengeIndex: number;
  typeIndex: number;
  r: bigint;
  s: bigint;
}): Hex {
  const encoded = encodeAbiParameters(
    [
      {
        type: "tuple",
        components: [
          { name: "credentialIdHash", type: "bytes32" },
          {
            name: "webAuthnData",
            type: "tuple",
            components: [
              { name: "authenticatorData", type: "bytes" },
              { name: "clientDataJSON", type: "string" },
              { name: "challengeIndex", type: "uint256" },
              { name: "typeIndex", type: "uint256" },
              { name: "r", type: "uint256" },
              { name: "s", type: "uint256" },
            ],
          },
        ],
      },
    ],
    [
      {
        credentialIdHash: params.credentialIdHash,
        webAuthnData: {
          authenticatorData: bytesToHex(params.authenticatorData) as Hex,
          clientDataJSON: params.clientDataJSON,
          challengeIndex: BigInt(params.challengeIndex),
          typeIndex: BigInt(params.typeIndex),
          r: params.r,
          s: params.s,
        },
      },
    ]
  );
  return encoded as Hex;
}

// ─── DER Signature Parser ────────────────────────────────────────────────── //

export function parseDERSignature(der: Uint8Array): { r: bigint; s: bigint } {
  if (der[0] !== 0x30) throw new Error("Invalid DER: missing SEQUENCE tag");

  let offset = 2; // 0x30 + totalLen

  // Parse r
  if (der[offset] !== 0x02) throw new Error("Invalid DER: expected INTEGER for r");
  offset++;
  const rLen = readByte(der, offset);
  offset++;
  const rStart = der[offset] === 0x00 ? offset + 1 : offset;
  const r = BigInt(
    `0x${Array.from(der.slice(rStart, offset + rLen))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("")}`
  );
  offset += rLen;

  // Parse s
  if (der[offset] !== 0x02) throw new Error("Invalid DER: expected INTEGER for s");
  offset++;
  const sLen = readByte(der, offset);
  offset++;
  const sStart = der[offset] === 0x00 ? offset + 1 : offset;
  const s = BigInt(
    `0x${Array.from(der.slice(sStart, offset + sLen))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("")}`
  );

  return { r, s };
}
