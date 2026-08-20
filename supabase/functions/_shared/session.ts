/**
 * Signed session tokens using HMAC-SHA256.
 * Format: base64url(payload).base64url(signature)
 * No external JWT library — keeps Edge Function bundle minimal.
 */

function getSecret(): string {
  const secret = Deno.env.get("SESSION_SECRET") ?? "";
  if (secret.length < 48) {
    throw new Error("SESSION_SECRET must be at least 48 characters long");
  }
  return secret;
}

function base64urlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlDecode(str: string): string {
  const padded = str.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4;
  return atob(pad ? padded + "=".repeat(4 - pad) : padded);
}

async function hmacSha256(key: string, data: string): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(key) as BufferSource,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    enc.encode(data) as BufferSource,
  );
  return new Uint8Array(sig);
}

export interface SessionPayload {
  userId: string;
  email: string;
  issuedAt: number;
  expiresAt: number;
}

export async function createSessionToken(
  payload: Omit<SessionPayload, "issuedAt" | "expiresAt">,
  ttlMs: number = 12 * 60 * 60 * 1000,
): Promise<string> {
  const now = Date.now();
  const full: SessionPayload = {
    ...payload,
    issuedAt: now,
    expiresAt: now + ttlMs,
  };
  const payloadB64 = base64urlEncode(
    new TextEncoder().encode(JSON.stringify(full)),
  );
  const sig = await hmacSha256(getSecret(), payloadB64);
  const sigB64 = base64urlEncode(sig);
  return `${payloadB64}.${sigB64}`;
}

export async function verifySessionToken(
  token: string,
): Promise<SessionPayload | null> {
  const parts = token.split(".");
  if (parts.length !== 2) return null;

  const [payloadB64, sigB64] = parts;
  const expectedSig = await hmacSha256(getSecret(), payloadB64);

  const providedSig = base64urlDecode(sigB64);
  const expectedBinary = String.fromCharCode(...expectedSig);
  if (providedSig.length !== expectedSig.length) return null;

  let diff = 0;
  for (let i = 0; i < providedSig.length; i++) {
    diff |= providedSig.charCodeAt(i) !== expectedBinary.charCodeAt(i) ? 1 : 0;
  }
  if (diff !== 0) return null;

  try {
    const payloadJson = base64urlDecode(payloadB64);
    const payload = JSON.parse(payloadJson) as SessionPayload;
    if (Date.now() > payload.expiresAt) return null;
    return payload;
  } catch {
    return null;
  }
}

export function extractSessionToken(req: Request): string | null {
  const header = req.headers.get("x-session-token");
  if (header) return header;

  const auth = req.headers.get("authorization");
  if (auth?.startsWith("Bearer ")) {
    return auth.slice(7);
  }

  // Token via query param for image/audio routes where headers aren't possible
  const url = new URL(req.url);
  const queryToken = url.searchParams.get("token");
  if (queryToken) return queryToken;

  return null;
}

export async function requireSession(
  req: Request,
): Promise<SessionPayload | null> {
  const token = extractSessionToken(req);
  if (!token) return null;
  return verifySessionToken(token);
}
