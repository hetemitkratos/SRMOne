/**
 * Haveloc crypto — TypeScript port of Go crypto.go
 * Handles token encryption/obfuscation, API-KEY generation, and JWT claim extraction.
 *
 * AES-CBC with fixed IV "1234567812345678" for ihaveloc token encryption.
 * AES-ECB with PKCS7 padding for API-KEY encryption.
 * Both use random 32-char keys that are interleaved into the output string.
 */

const IV_STRING = "1234567812345678";
const RANDOM_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

const IHAVELOC_PREFIX = 10;
const IHAVELOC_SUFFIX = 12;
const IHAVELOC_KEY_SPLIT = 23;
const IHAVELOC_MID_RAND = 6;

const API_KEY_RAND_1 = 7;
const API_KEY_RAND_2 = 3;
const API_KEY_RAND_3 = 5;
const API_KEY_RAND_4 = 7;
const API_KEY_RAND_5 = 8;
const API_KEY_KEY_SPLIT_1 = 11;
const API_KEY_KEY_SPLIT_2 = 5;
const API_KEY_KEY_SPLIT_3 = 9;

const D_RAND_LEN = 5;

function randomString(length: number): string {
  const chars = new Uint8Array(length);
  crypto.getRandomValues(chars);
  let result = "";
  for (let i = 0; i < length; i++) {
    result += RANDOM_ALPHABET[chars[i] % RANDOM_ALPHABET.length];
  }
  return result;
}

// ─── PKCS7 padding ───────────────────────────────────────────────────────────

function pkcs7Pad(data: Uint8Array, blockSize: number): Uint8Array {
  const padding = blockSize - (data.length % blockSize);
  const padded = new Uint8Array(data.length + padding);
  padded.set(data);
  for (let i = data.length; i < padded.length; i++) {
    padded[i] = padding;
  }
  return padded;
}

// ─── Base64 helpers ──────────────────────────────────────────────────────────

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

// ─── AES-CBC encrypt (for ihaveloc token) ────────────────────────────────────

async function aesCBCEncrypt(plaintext: Uint8Array, key: string): Promise<string> {
  const keyBytes = new TextEncoder().encode(key.slice(0, 32));
  const iv = new TextEncoder().encode(IV_STRING);
  const padded = pkcs7Pad(plaintext, 16);

  const cryptoKey = await crypto.subtle.importKey("raw", keyBytes as BufferSource, { name: "AES-CBC" }, false, ["encrypt"]);
  const cipherBuf = await crypto.subtle.encrypt({ name: "AES-CBC", iv: iv as BufferSource }, cryptoKey, padded as BufferSource);
  return base64Encode(new Uint8Array(cipherBuf));
}

// ─── AES-ECB encrypt (for API-KEY) ───────────────────────────────────────────
// WebCrypto doesn't support ECB. We simulate it by encrypting each 16-byte block
// with AES-CBC using a zero IV (CBC with zero IV on a single block = ECB).
// WebCrypto adds PKCS7 padding automatically, so a 16-byte input produces 32 bytes;
// we slice the first 16 bytes to get the ECB ciphertext for that block.

async function aesECBEncrypt(plaintext: Uint8Array, key: string): Promise<string> {
  const keyBytes = new TextEncoder().encode(key.slice(0, 32));
  const iv = new Uint8Array(16); // zero IV
  const padded = pkcs7Pad(plaintext, 16);

  const cryptoKey = await crypto.subtle.importKey("raw", keyBytes as BufferSource, { name: "AES-CBC" }, false, ["encrypt"]);

  const result = new Uint8Array(padded.length);
  for (let i = 0; i < padded.length; i += 16) {
    const block = padded.slice(i, i + 16);
    const cipherBuf = await crypto.subtle.encrypt({ name: "AES-CBC", iv: iv as BufferSource }, cryptoKey, block as BufferSource);
    const cipherBlock = new Uint8Array(cipherBuf);
    // First 16 bytes = ECB ciphertext; second 16 bytes = padding block
    result.set(cipherBlock.slice(0, 16), i);
  }

  return base64Encode(result);
}

// ─── Token encryption (ihaveloc) ─────────────────────────────────────────────

export async function encryptToken(jwt: string): Promise<string> {
  const key = randomString(32);
  const encrypted = await aesCBCEncrypt(new TextEncoder().encode(jwt), key);
  return obfuscateToken(encrypted, key);
}

function obfuscateToken(ciphertext: string, key: string): string {
  const r1 = randomString(IHAVELOC_PREFIX);
  const r2 = randomString(IHAVELOC_MID_RAND);
  const r3 = randomString(IHAVELOC_SUFFIX);
  const keyPart1 = key.slice(0, IHAVELOC_KEY_SPLIT);
  const keyPart2 = key.slice(IHAVELOC_KEY_SPLIT);
  return r1 + keyPart1 + r2 + ciphertext + keyPart2 + r3;
}

// ─── API-KEY generation ──────────────────────────────────────────────────────

export async function generateAPIKey(sub: string, phaveloc: number): Promise<string> {
  const key = randomString(32);
  const plaintext = buildAPIKeyPlaintext(sub, phaveloc);
  const encrypted = await aesECBEncrypt(new TextEncoder().encode(plaintext), key);
  return obfuscateAPIKey(encrypted, key);
}

function buildAPIKeyPlaintext(sub: string, phaveloc: number): string {
  const now = Math.floor(Date.now() / 1000);
  const diff = now - phaveloc;
  const r1 = randomString(D_RAND_LEN);
  const r2 = randomString(D_RAND_LEN);
  return `${r1}#R#${sub}#R#${diff}#R#${r2}`;
}

function obfuscateAPIKey(ciphertext: string, key: string): string {
  const r1 = randomString(API_KEY_RAND_1);
  const r2 = randomString(API_KEY_RAND_2);
  const r3 = randomString(API_KEY_RAND_3);
  const r4 = randomString(API_KEY_RAND_4);
  const r5 = randomString(API_KEY_RAND_5);
  const keyPart1 = key.slice(0, API_KEY_KEY_SPLIT_1);
  const keyPart2 = key.slice(API_KEY_KEY_SPLIT_1, API_KEY_KEY_SPLIT_1 + API_KEY_KEY_SPLIT_2);
  const keyPart3 = key.slice(API_KEY_KEY_SPLIT_1 + API_KEY_KEY_SPLIT_2, API_KEY_KEY_SPLIT_1 + API_KEY_KEY_SPLIT_2 + API_KEY_KEY_SPLIT_3);
  const keyPart4 = key.slice(API_KEY_KEY_SPLIT_1 + API_KEY_KEY_SPLIT_2 + API_KEY_KEY_SPLIT_3);
  return r1 + keyPart1 + r2 + keyPart2 + ciphertext + r3 + keyPart3 + r4 + keyPart4 + r5;
}

// ─── JWT claim extraction ────────────────────────────────────────────────────

function extractJWTClaims(jwt: string): Record<string, unknown> {
  const parts = jwt.split(".");
  if (parts.length < 2) throw new Error("invalid JWT format");

  let payload: string;
  try {
    // Try RawURL decoding first (JWT standard)
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    payload = atob(b64);
  } catch {
    throw new Error("could not decode JWT payload");
  }

  try {
    return JSON.parse(payload);
  } catch {
    throw new Error("could not parse JWT claims");
  }
}

export function extractSubFromJWT(jwt: string): string {
  const claims = extractJWTClaims(jwt);
  const sub = claims["sub"];
  if (typeof sub !== "string") throw new Error("JWT missing sub claim");
  return sub;
}

export function extractTSFromJWT(jwt: string): number {
  const claims = extractJWTClaims(jwt);
  const ts = claims["ts"];
  if (typeof ts !== "number") throw new Error("JWT missing ts claim");
  return Math.floor(ts);
}

export function extractUUIDFromJWT(jwt: string): string {
  const claims = extractJWTClaims(jwt);
  const uuid = claims["uuid"];
  if (typeof uuid !== "string") throw new Error("JWT missing uuid claim");
  return uuid;
}
