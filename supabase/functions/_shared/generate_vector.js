/**
 * Node.js script to generate a cross-platform crypto test vector.
 * Run with: node supabase/functions/_shared/generate_vector.js
 *
 * Output: an encrypted string that the Deno crypto_test.ts can decrypt
 * to verify byte-compatibility.
 */
const crypto = require("crypto");

const ALGORITHM = "aes-256-cbc";
const IV_LENGTH = 16;

function getKey() {
  const raw = "0123456789abcdef0123456789abcdef"; // exactly 32 chars
  return Buffer.from(raw.slice(0, 32), "utf8");
}

function encryptPassword(plaintext) {
  const key = getKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  return `${iv.toString("base64")}:${encrypted.toString("base64")}`;
}

const encrypted = encryptPassword("testPassword123!");
console.log("NODE_ENCRYPTED =", JSON.stringify(encrypted));
console.log("\nPaste this value into NODE_ENCRYPTED in crypto_test.ts");
