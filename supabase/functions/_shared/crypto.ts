/**
 * AES-256-CBC encryption via WebCrypto — byte-compatible with the Node.js
 * implementation in academia-backend/utils/crypto.js and
 * placement-backend/utils/crypto.js.
 *
 * Format: base64(iv):base64(ciphertext)
 * Key:    first 32 bytes of ENCRYPTION_KEY env var (UTF-8)
 * Padding: PKCS7 (WebCrypto AES-CBC default, same as Node createCipheriv default)
 */

const IV_LENGTH = 16;

function getKeyBytes(): Uint8Array {
  const raw = Deno.env.get("ENCRYPTION_KEY") ?? "";
  if (raw.length < 32) {
    throw new Error("ENCRYPTION_KEY must be at least 32 characters long");
  }
  return new TextEncoder().encode(raw.slice(0, 32));
}

async function importKey(
  keyBytes: Uint8Array,
  usage: KeyUsage[],
): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    keyBytes as BufferSource,
    { name: "AES-CBC" },
    false,
    usage,
  );
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function fromBase64(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export async function encryptPassword(plaintext: string): Promise<string> {
  const keyBytes = getKeyBytes();
  const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
  const key = await importKey(keyBytes, ["encrypt"]);
  const encoded = new TextEncoder().encode(plaintext);
  const cipherBuf = await crypto.subtle.encrypt(
    { name: "AES-CBC", iv: iv as BufferSource },
    key,
    encoded as BufferSource,
  );
  const cipherBytes = new Uint8Array(cipherBuf);
  return `${toBase64(iv)}:${toBase64(cipherBytes)}`;
}

export async function decryptPassword(encryptedStr: string): Promise<string> {
  const keyBytes = getKeyBytes();
  const [ivB64, dataB64] = encryptedStr.split(":");
  if (!ivB64 || !dataB64) {
    throw new Error("Invalid encrypted password format");
  }
  const iv = fromBase64(ivB64);
  const cipherBytes = fromBase64(dataB64);
  const key = await importKey(keyBytes, ["decrypt"]);
  const plainBuf = await crypto.subtle.decrypt(
    { name: "AES-CBC", iv: iv as BufferSource },
    key,
    cipherBytes as BufferSource,
  );
  return new TextDecoder().decode(plainBuf);
}
