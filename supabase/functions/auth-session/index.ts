/**
 * auth-session Edge Function — interactive login, token management.
 * verify_jwt = false (custom session tokens).
 *
 * Routes:
 *   POST /login    { email, password, spPassword? }  → { token, user, needsSpPassword }
 *   POST /sp-login { spPassword }                     → { success, message }  (token-required)
 *   POST /refresh                                     → { token, expiresAt }   (token-required)
 *   POST /logout                                      → { success }            (token-required)
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  createSessionToken,
  requireSession,
} from "../_shared/session.ts";
import { encryptPassword, decryptPassword } from "../_shared/crypto.ts";
import { AcademiaLoginSession } from "../_shared/academia-login.ts";

const CLASS_AUTHENTICATED = "authenticated_session_established";
const CLASS_INVALID_CREDS = "invalid_credentials";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function getSupabase() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Missing Supabase env vars");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// ─── POST /login ─────────────────────────────────────────────────────────────

async function handleLogin(req: Request): Promise<Response> {
  let body: { email?: string; password?: string; spPassword?: string };
  try {
    body = await req.json();
  } catch {
    return json({ success: false, error: "Invalid JSON body" }, 400);
  }

  const email = body.email?.trim().toLowerCase();
  const password = body.password;
  const spPassword = body.spPassword;

  if (!email || !password) {
    return json({ success: false, error: "email and password are required" }, 400);
  }

  if (!email.endsWith("@srmist.edu.in")) {
    return json(
      { success: false, error: "Only @srmist.edu.in email addresses are allowed." },
      400,
    );
  }

  const supabase = getSupabase();

  // 1. Run academia login to verify credentials live
  const loginSession = new AcademiaLoginSession();
  const result = await loginSession.login(email, password);

  if (!result.success || result.classification !== CLASS_AUTHENTICATED) {
    const status = result.classification === CLASS_INVALID_CREDS ? 401 : 500;
    return json(
      { success: false, error: result.error || "Login failed", classification: result.classification },
      status,
    );
  }

  // 2. Upsert academia_credentials
  const encPwd = await encryptPassword(password);
  const encSpPwd = spPassword ? await encryptPassword(spPassword) : null;

  // Check if credentials row exists (to preserve existing sp_password if not provided)
  const { data: existingCreds } = await supabase
    .from("academia_credentials")
    .select("encrypted_sp_password")
    .eq("academia_email", email)
    .single();

  const credUpdate: Record<string, unknown> = {
    academia_email: email,
    encrypted_password: encPwd,
    auto_login_enabled: true,
    updated_at: new Date().toISOString(),
  };

  if (encSpPwd) {
    credUpdate.encrypted_sp_password = encSpPwd;
  } else if (!existingCreds?.encrypted_sp_password) {
    credUpdate.encrypted_sp_password = null;
  }
  // If spPassword not provided but existing sp_password exists, preserve it (don't include in update)

  await supabase
    .from("academia_credentials")
    .upsert(credUpdate, { onConflict: "academia_email" });

  // 3. Upsert student_profiles skeleton; set last_seen_at = now()
  const { data: profile } = await supabase
    .from("student_profiles")
    .select("id")
    .eq("academia_email", email)
    .single();

  let userId: string;

  if (profile?.id) {
    userId = profile.id;
    await supabase
      .from("student_profiles")
      .update({ last_seen_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq("id", userId);
  } else {
    const { data: newProfile, error: profileErr } = await supabase
      .from("student_profiles")
      .insert({
        academia_email: email,
        last_seen_at: new Date().toISOString(),
      })
      .select("id")
      .single();

    if (profileErr || !newProfile) {
      return json(
        { success: false, error: "Failed to create student profile" },
        500,
      );
    }
    userId = newProfile.id;
  }

  // 4. If spPassword provided → fire-and-forget SP login (best-effort, non-blocking)
  // SP sync will be implemented in Phase 6; for now we just store the encrypted password.

  // 5. Create session token
  const token = await createSessionToken({ userId, email });

  // Check if user has stored SP password
  const hasSpPassword = !!(encSpPwd || existingCreds?.encrypted_sp_password);

  return json({
    success: true,
    token,
    user: { id: userId, email },
    needsSpPassword: !hasSpPassword,
  });
}

// ─── POST /sp-login ──────────────────────────────────────────────────────────

async function handleSpLogin(req: Request): Promise<Response> {
  const session = await requireSession(req);
  if (!session) return json({ success: false, error: "Unauthorized" }, 401);

  let body: { spPassword?: string };
  try {
    body = await req.json();
  } catch {
    return json({ success: false, error: "Invalid JSON body" }, 400);
  }

  const spPassword = body.spPassword;
  if (!spPassword) {
    return json({ success: false, error: "spPassword is required" }, 400);
  }

  const supabase = getSupabase();
  const encSpPwd = await encryptPassword(spPassword);

  // Store encrypted SP password
  const { error: updateErr } = await supabase
    .from("academia_credentials")
    .update({ encrypted_sp_password: encSpPwd, updated_at: new Date().toISOString() })
    .eq("academia_email", session.email);

  if (updateErr) {
    return json({ success: false, error: "Failed to store SP password" }, 500);
  }

  // SP login attempt will be implemented in Phase 6 (sp-sync)
  // For now, just acknowledge storage
  return json({
    success: true,
    message: "SP password stored. SP data will sync on next scheduled run.",
  });
}

// ─── POST /refresh ───────────────────────────────────────────────────────────

async function handleRefresh(req: Request): Promise<Response> {
  const session = await requireSession(req);
  if (!session) return json({ success: false, error: "Unauthorized" }, 401);

  // Check if stored credentials still exist
  const supabase = getSupabase();
  const { data: creds } = await supabase
    .from("academia_credentials")
    .select("encrypted_password")
    .eq("academia_email", session.email)
    .single();

  if (!creds?.encrypted_password) {
    return json({ success: false, error: "Credentials not found — please log in again" }, 401);
  }

  // Decrypt password and verify session is still valid via academia
  let password: string;
  try {
    password = await decryptPassword(creds.encrypted_password);
  } catch {
    return json({ success: false, error: "Failed to decrypt credentials" }, 500);
  }

  const loginSession = new AcademiaLoginSession();
  const result = await loginSession.login(session.email, password);

  if (!result.success || result.classification !== CLASS_AUTHENTICATED) {
    return json(
      { success: false, error: "Session expired — please log in again", classification: result.classification },
      401,
    );
  }

  // Re-issue token with fresh login
  const token = await createSessionToken({
    userId: session.userId,
    email: session.email,
  });

  // Update last_seen_at
  await supabase
    .from("student_profiles")
    .update({ last_seen_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("id", session.userId);

  return json({
    success: true,
    token,
    expiresAt: Date.now() + 12 * 60 * 60 * 1000,
  });
}

// ─── POST /logout ────────────────────────────────────────────────────────────

async function handleLogout(req: Request): Promise<Response> {
  const session = await requireSession(req);
  if (!session) return json({ success: false, error: "Unauthorized" }, 401);

  const supabase = getSupabase();

  // Delete credentials + disposable caches for this user
  await supabase
    .from("academia_credentials")
    .delete()
    .eq("academia_email", session.email);

  // Clean up disposable data (timetable_cache, marks_cache, calendar_cache, attendance_current)
  // Core profile and attendance_snapshots are preserved
  await supabase.from("timetable_cache").delete().eq("academia_email", session.email);
  await supabase.from("marks_cache").delete().eq("academia_email", session.email);
  await supabase.from("calendar_cache").delete().eq("academia_email", session.email);
  await supabase.from("attendance_current").delete().eq("academia_email", session.email);

  return json({ success: true });
}

// ─── Router ──────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  // Strip trailing slash and function prefix to get the route path
  let path = url.pathname.replace(/\/$/, "");
  // Remove function path prefix if present (e.g. /functions/v1/auth-session/login → /login)
  const fnPrefix = "/functions/v1/auth-session";
  if (path.startsWith(fnPrefix)) {
    path = path.slice(fnPrefix.length);
  }
  // Also handle bare function name prefix
  const fnPrefix2 = "/auth-session";
  if (path.startsWith(fnPrefix2)) {
    path = path.slice(fnPrefix2.length);
  }
  const method = req.method.toUpperCase();

  // CORS preflight
  if (method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, x-session-token",
      },
    });
  }

  try {
    if (path === "/login" || path === "" || path === "/") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleLogin(req);
    }

    if (path === "/sp-login") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleSpLogin(req);
    }

    if (path === "/refresh") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleRefresh(req);
    }

    if (path === "/logout") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleLogout(req);
    }

    return json({ error: "Not found" }, 404);
  } catch (err) {
    const error = err as Error;
    console.error("[auth-session]", error.message);
    return json({ success: false, error: "Internal server error" }, 500);
  }
});
