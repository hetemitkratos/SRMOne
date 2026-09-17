// Student Portal relay — forwards a single HTTP request to sp.srmist.edu.in
// from Vercel's Mumbai region (see "regions" in the repo-root vercel.json).
//
// Why: sp.srmist.edu.in rejects login POSTs that originate from Render's
// US egress IP with a generic "Invalid credentials" page, even when the
// captcha and password are correct. The identical request from an Indian
// IP succeeds. The Go scraper (cmd/studentportal) sends each hop here when
// SP_RELAY_URL is set; cookies and redirects are still handled by Go.
//
// Request:  POST { method, url, headers: {name: value}, body: <base64> }
// Response: { status, headers: {name: value}, setCookie: [..], body: <base64> }
//
// Auth: X-Relay-Secret must equal SP_RELAY_SECRET (set the same value on
// Render and Vercel). Only https://sp.srmist.edu.in/* may be targeted.

import { timingSafeEqual } from "node:crypto";

export const config = { maxDuration: 60 };

const ALLOWED_HOST = "sp.srmist.edu.in";

// Hop-by-hop / transport headers that fetch manages itself.
const DROP_REQUEST_HEADERS = new Set([
  "connection",
  "content-length",
  "host",
  "accept-encoding",
  "transfer-encoding",
]);
const DROP_RESPONSE_HEADERS = new Set([
  "content-encoding",
  "content-length",
  "transfer-encoding",
  "connection",
  "set-cookie",
]);

function secretMatches(provided, expected) {
  if (typeof provided !== "string" || !expected) return false;
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "method not allowed" });
  }

  const expected = process.env.SP_RELAY_SECRET;
  if (!expected) {
    return res.status(503).json({ error: "relay not configured (SP_RELAY_SECRET missing)" });
  }
  if (!secretMatches(req.headers["x-relay-secret"], expected)) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const { method = "GET", url, headers = {}, body = "" } = req.body || {};

  let target;
  try {
    target = new URL(url);
  } catch {
    return res.status(400).json({ error: "invalid url" });
  }
  if (target.protocol !== "https:" || target.hostname !== ALLOWED_HOST) {
    return res.status(400).json({ error: `only https://${ALLOWED_HOST} may be relayed` });
  }
  if (!/^[A-Z]+$/.test(method)) {
    return res.status(400).json({ error: "invalid method" });
  }

  const upstreamHeaders = {};
  for (const [name, value] of Object.entries(headers)) {
    if (typeof value !== "string") continue;
    if (DROP_REQUEST_HEADERS.has(name.toLowerCase())) continue;
    upstreamHeaders[name] = value;
  }

  const init = { method, headers: upstreamHeaders, redirect: "manual" };
  if (body && method !== "GET" && method !== "HEAD") {
    init.body = Buffer.from(body, "base64");
  }

  let upstream;
  try {
    upstream = await fetch(target.toString(), init);
  } catch (err) {
    return res.status(502).json({ error: `upstream request failed: ${err.message}` });
  }

  const buf = Buffer.from(await upstream.arrayBuffer());
  const outHeaders = {};
  upstream.headers.forEach((value, name) => {
    if (!DROP_RESPONSE_HEADERS.has(name.toLowerCase())) outHeaders[name] = value;
  });

  return res.status(200).json({
    status: upstream.status,
    headers: outHeaders,
    setCookie: upstream.headers.getSetCookie(),
    body: buf.toString("base64"),
  });
}
