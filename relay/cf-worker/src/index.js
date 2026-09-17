// Student Portal relay as a Cloudflare Worker.
//
// Same wire protocol as api/sp-relay.mjs (the Vercel relay): the Go scraper
// POSTs { method, url, headers, body: <base64> } and gets back
// { status, headers, setCookie: [...], body: <base64> }. Redirects are not
// followed and cookies are not touched — the Go client owns both.
//
// Egress IP is the Cloudflare colo that serves the request, so the caller's
// location decides where the portal sees the request from. Called from an
// Indian caller (or via the Vercel bom1 relay) it egresses from Cloudflare
// Mumbai/Chennai.
//
// Auth: X-Relay-Secret must equal the SP_RELAY_SECRET binding.

const ALLOWED_HOST = "sp.srmist.edu.in";

const DROP_REQUEST_HEADERS = new Set([
  "connection", "content-length", "host", "accept-encoding", "transfer-encoding",
]);
const DROP_RESPONSE_HEADERS = new Set([
  "content-encoding", "content-length", "transfer-encoding", "connection", "set-cookie",
]);

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function secretMatches(provided, expected) {
  if (typeof provided !== "string" || !expected || provided.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= provided.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

function b64ToBytes(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToB64(bytes) {
  let bin = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
  }
  return btoa(bin);
}

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json({ error: "method not allowed" }, 405);
    }
    if (!env.SP_RELAY_SECRET) {
      return json({ error: "relay not configured (SP_RELAY_SECRET missing)" }, 503);
    }
    if (!secretMatches(request.headers.get("x-relay-secret"), env.SP_RELAY_SECRET)) {
      return json({ error: "unauthorized" }, 401);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "invalid json" }, 400);
    }
    const { method = "GET", url, headers = {}, body = "" } = payload || {};

    let target;
    try {
      target = new URL(url);
    } catch {
      return json({ error: "invalid url" }, 400);
    }
    if (target.protocol !== "https:" || target.hostname !== ALLOWED_HOST) {
      return json({ error: `only https://${ALLOWED_HOST} may be relayed` }, 400);
    }
    if (!/^[A-Z]+$/.test(method)) {
      return json({ error: "invalid method" }, 400);
    }

    const upstreamHeaders = new Headers();
    for (const [name, value] of Object.entries(headers)) {
      if (typeof value !== "string") continue;
      if (DROP_REQUEST_HEADERS.has(name.toLowerCase())) continue;
      upstreamHeaders.set(name, value);
    }

    const init = { method, headers: upstreamHeaders, redirect: "manual" };
    if (body && method !== "GET" && method !== "HEAD") {
      init.body = b64ToBytes(body);
    }

    let upstream;
    try {
      upstream = await fetch(target.toString(), init);
    } catch (err) {
      return json({ error: `upstream request failed: ${err.message}` }, 502);
    }

    const bytes = new Uint8Array(await upstream.arrayBuffer());
    const outHeaders = {};
    for (const [name, value] of upstream.headers) {
      if (!DROP_RESPONSE_HEADERS.has(name.toLowerCase())) outHeaders[name] = value;
    }
    const setCookie = typeof upstream.headers.getSetCookie === "function"
      ? upstream.headers.getSetCookie()
      : [];

    return json({
      status: upstream.status,
      headers: outHeaders,
      setCookie,
      body: bytesToB64(bytes),
    });
  },
};
