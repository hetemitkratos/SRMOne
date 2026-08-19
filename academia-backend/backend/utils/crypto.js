/**
 * AES-256-CBC encryption for storing academia/SP passwords securely.
 * Uses Node.js built-in crypto module — no extra dependencies.
 * Reuses the same pattern as placement-backend/utils/crypto.js.
 */
import crypto from "crypto";

const ALGORITHM = "aes-256-cbc";
const IV_LENGTH = 16;

function getKey() {
  const raw = process.env.ENCRYPTION_KEY || "";
  if (raw.length < 32) {
    throw new Error("ENCRYPTION_KEY must be at least 32 characters long");
  }
  return Buffer.from(raw.slice(0, 32), "utf8");
}

/**
 * Encrypt a plaintext password.
 * Returns a base64 string: iv:ciphertext
 */
export function encryptPassword(plaintext) {
  const key = getKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);
  return `${iv.toString("base64")}:${encrypted.toString("base64")}`;
}

/**
 * Decrypt an encrypted password string (iv:ciphertext format).
 * Returns the plaintext password.
 */
export function decryptPassword(encryptedStr) {
  const key = getKey();
  const [ivB64, dataB64] = encryptedStr.split(":");
  if (!ivB64 || !dataB64) {
    throw new Error("Invalid encrypted password format");
  }
  const iv = Buffer.from(ivB64, "base64");
  const encrypted = Buffer.from(dataB64, "base64");
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  const decrypted = Buffer.concat([
    decipher.update(encrypted),
    decipher.final(),
  ]);
  return decrypted.toString("utf8");
}
