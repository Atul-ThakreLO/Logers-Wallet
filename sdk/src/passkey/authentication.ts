import { startAuthentication } from "@simplewebauthn/browser";
import type {
  AuthenticationResponseJSON,
  PublicKeyCredentialRequestOptionsJSON,
} from "@simplewebauthn/types";
import type { Hex } from "viem";
import type { WebAuthnAuthData } from "../types.js";
import { base64urlToBytes, encodeWebAuthnSignature, parseDERSignature } from "./encoding.js";

export interface AuthenticationOptions {
  challenge: string; // base64url
  rpId: string;
  allowCredentials?: string[]; // base64url credential IDs
  timeout?: number;
}

export async function startPasskeyAuthentication(
  options: AuthenticationOptions
): Promise<AuthenticationResponseJSON> {
  const opts: PublicKeyCredentialRequestOptionsJSON = {
    challenge: options.challenge,
    rpId: options.rpId,
    ...(options.allowCredentials
      ? {
          allowCredentials: options.allowCredentials.map((id) => ({
            id,
            type: "public-key" as const,
          })),
        }
      : {}),
    userVerification: "required",
    timeout: options.timeout ?? 120_000,
  };
  return startAuthentication(opts);
}

export function parseAuthenticationResponse(
  response: AuthenticationResponseJSON,
  credentialIdHash: Hex
): { signature: Hex; authData: WebAuthnAuthData } {
  const { response: r } = response;
  const authenticatorData = base64urlToBytes(r.authenticatorData);
  const clientDataJSON = new TextDecoder().decode(base64urlToBytes(r.clientDataJSON));
  const signatureBytes = base64urlToBytes(r.signature);

  const { r: sigR, s: sigS } = parseDERSignature(signatureBytes);

  // Find indices in clientDataJSON
  const challengeIndex = clientDataJSON.indexOf('"challenge"');
  const typeIndex = clientDataJSON.indexOf('"type"');

  if (challengeIndex === -1 || typeIndex === -1) {
    throw new Error("Malformed clientDataJSON: missing challenge or type field");
  }

  const authData: WebAuthnAuthData = {
    authenticatorData: `0x${Array.from(authenticatorData)
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("")}` as Hex,
    clientDataJSON,
    challengeIndex: BigInt(challengeIndex),
    typeIndex: BigInt(typeIndex),
    r: sigR,
    s: sigS,
  };

  const signature = encodeWebAuthnSignature({
    credentialIdHash,
    authenticatorData,
    clientDataJSON,
    challengeIndex,
    typeIndex,
    r: sigR,
    s: sigS,
  });

  return { signature, authData };
}
