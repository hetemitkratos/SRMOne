/**
 * Session token tests — verifies HMAC-SHA256 sign/verify and tamper detection.
 *
 * Run with: deno test --allow-env supabase/functions/_shared/session_test.ts
 *
 * Set SESSION_SECRET env var to a 48+ char string.
 */
import {
  createSessionToken,
  verifySessionToken,
  extractSessionToken,
} from "./session.ts";
import { assertEquals, assertNotEquals } from "@std/assert";

Deno.test("session: create → verify round-trip", async () => {
  const token = await createSessionToken({
    userId: "user-123",
    email: "test@srmist.edu.in",
  });
  const payload = await verifySessionToken(token);
  assertEquals(payload?.userId, "user-123");
  assertEquals(payload?.email, "test@srmist.edu.in");
});

Deno.test("session: tampered signature is rejected", async () => {
  const token = await createSessionToken({
    userId: "user-123",
    email: "test@srmist.edu.in",
  });
  const [payloadB64, sigB64] = token.split(".");
  // Flip last character of signature
  const tamperedSig = sigB64.slice(0, -1) + (sigB64.slice(-1) === "A" ? "B" : "A");
  const tampered = `${payloadB64}.${tamperedSig}`;
  const payload = await verifySessionToken(tampered);
  assertEquals(payload, null);
});

Deno.test("session: tampered payload is rejected", async () => {
  const token = await createSessionToken({
    userId: "user-123",
    email: "test@srmist.edu.in",
  });
  const [payloadB64, sigB64] = token.split(".");
  // Tamper with payload
  const tamperedPayload = payloadB64.slice(0, -1) +
    (payloadB64.slice(-1) === "A" ? "B" : "A");
  const tampered = `${tamperedPayload}.${sigB64}`;
  const payload = await verifySessionToken(tampered);
  assertEquals(payload, null);
});

Deno.test("session: expired token is rejected", async () => {
  const token = await createSessionToken(
    { userId: "user-123", email: "test@srmist.edu.in" },
    -1000, // already expired
  );
  const payload = await verifySessionToken(token);
  assertEquals(payload, null);
});

Deno.test("session: malformed token returns null", async () => {
  const payload = await verifySessionToken("not-a-valid-token");
  assertEquals(payload, null);
});

Deno.test("session: extractSessionToken from header", () => {
  const req = new Request("https://example.com", {
    headers: { "x-session-token": "abc.def" },
  });
  assertEquals(extractSessionToken(req), "abc.def");
});

Deno.test("session: extractSessionToken from Authorization Bearer", () => {
  const req = new Request("https://example.com", {
    headers: { authorization: "Bearer abc.def" },
  });
  assertEquals(extractSessionToken(req), "abc.def");
});

Deno.test("session: extractSessionToken returns null when absent", () => {
  const req = new Request("https://example.com");
  assertEquals(extractSessionToken(req), null);
});

Deno.test("session: different payloads produce different tokens", async () => {
  const a = await createSessionToken({ userId: "1", email: "a@test.com" });
  const b = await createSessionToken({ userId: "2", email: "b@test.com" });
  assertNotEquals(a, b);
});
