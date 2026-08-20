import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  HavelocClientAsync,
  login,
  verifyTOTP,
  sendMFAPrompt,
  signOut,
  fetchStudentDocuments,
  applyForJob as havelocApplyForJob,
  fetchJobView,
  type ApplyAnswer,
} from "../_shared/haveloc-client.ts";
import { encryptPassword, decryptPassword } from "../_shared/crypto.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const TABLE = "placement_credentials";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });
}

// ─── Route handlers ──────────────────────────────────────────────────────────

async function handleLogin(req: Request): Promise<Response> {
  const { username, password } = await req.json();
  if (!username || !password) return json({ success: false, error: "username and password are required" }, 400);

  const client = new HavelocClientAsync();
  try {
    const result = await login(client, username, password);

    if (result.requiresMfa) {
      return json({
        success: true,
        requiresMfa: true,
        mfaToken: result.mfaToken,
        publicUrl: result.publicUrl,
      });
    }

    return json({
      success: true,
      message: "Login successful",
      username,
      session: {
        token: result.token,
        encryptedToken: result.encryptedToken,
        sub: result.sub,
        uuid: result.uuid,
        phaveloc: result.phaveloc,
        publicUrl: result.publicUrl,
      },
    });
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
}

async function handleVerifyMfa(req: Request): Promise<Response> {
  const { mfaToken, totpCode, emailOtp, username } = await req.json();
  if (!mfaToken) return json({ success: false, error: "mfaToken is required" }, 400);
  if (!totpCode && !emailOtp) return json({ success: false, error: "totpCode or emailOtp is required" }, 400);

  const client = new HavelocClientAsync();
  try {
    const result = await verifyTOTP(client, mfaToken, totpCode || "", emailOtp || "");

    return json({
      success: true,
      message: "MFA verification successful",
      username: username || "mfa_user",
      session: {
        token: result.token,
        encryptedToken: result.encryptedToken,
        sub: result.sub,
        uuid: result.uuid,
        phaveloc: result.phaveloc,
        publicUrl: result.publicUrl,
      },
    });
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
}

async function handleSendMfaEmail(req: Request): Promise<Response> {
  const { mfaToken } = await req.json();
  if (!mfaToken) return json({ success: false, error: "mfaToken is required" }, 400);

  const client = new HavelocClientAsync();
  try {
    await sendMFAPrompt(client, mfaToken);
    return json({ success: true, message: "Verification code sent to your registered email." });
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
}

async function handleLogout(req: Request): Promise<Response> {
  const { token, phaveloc } = await req.json();
  if (!token) return json({ success: true });

  const client = new HavelocClientAsync();
  try {
    await client.setAuth(token, phaveloc || 0);
    await signOut(client);
  } catch { /* best effort */ }
  return json({ success: true });
}

// ─── Credential storage (connect / auto-login / disconnect / status) ──────────

async function handleConnect(req: Request): Promise<Response> {
  const { academiaEmail, username, password } = await req.json();
  if (!academiaEmail || !username || !password)
    return json({ success: false, error: "academiaEmail, username, and password are required" }, 400);

  const client = new HavelocClientAsync();
  try {
    const result = await login(client, username, password);

    const encrypted = await encryptPassword(password);
    const hasMfa = !!result.requiresMfa;

    await supabase.from(TABLE).upsert({
      academia_email: academiaEmail,
      placement_username: username,
      encrypted_password: encrypted,
      has_mfa: hasMfa,
      connected_at: new Date().toISOString(),
      auto_login_enabled: true,
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" });

    if (result.requiresMfa) {
      return json({
        success: true,
        requiresMfa: true,
        mfaToken: result.mfaToken,
        message: "MFA required. Credentials stored for future auto-login.",
      });
    }

    return json({
      success: true,
      message: "Placement account connected successfully",
      username,
    });
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
}

async function handleAutoLogin(req: Request): Promise<Response> {
  const { academiaEmail } = await req.json();
  if (!academiaEmail) return json({ success: false, error: "academiaEmail is required" }, 400);

  const { data: creds } = await supabase
    .from(TABLE)
    .select("*")
    .eq("academia_email", academiaEmail)
    .single();

  if (!creds || !creds.auto_login_enabled) {
    return json({ success: true, connected: false });
  }

  if (creds.has_mfa) {
    return json({
      success: true,
      connected: true,
      requiresMfa: true,
      username: creds.placement_username,
    });
  }

  try {
    const password = await decryptPassword(creds.encrypted_password);
    const client = new HavelocClientAsync();
    const result = await login(client, creds.placement_username, password);

    await supabase.from(TABLE)
      .update({ last_auto_login: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq("academia_email", academiaEmail);

    return json({
      success: true,
      connected: true,
      username: creds.placement_username,
      session: {
        token: result.token,
        encryptedToken: result.encryptedToken,
        sub: result.sub,
        uuid: result.uuid,
        phaveloc: result.phaveloc,
        publicUrl: result.publicUrl,
      },
    });
  } catch (err) {
    return json({ success: true, connected: false, error: (err as Error).message });
  }
}

async function handleDisconnect(req: Request): Promise<Response> {
  const { academiaEmail } = await req.json();
  if (!academiaEmail) return json({ success: false, error: "academiaEmail is required" }, 400);

  await supabase.from(TABLE).delete().eq("academia_email", academiaEmail);
  return json({ success: true, message: "Placement account disconnected" });
}

async function handleConnectionStatus(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);

  const { data: creds } = await supabase
    .from(TABLE)
    .select("*")
    .eq("academia_email", academiaEmail)
    .single();

  if (!creds) return json({ success: true, connected: false });

  return json({
    success: true,
    connected: true,
    username: creds.placement_username,
    hasMfa: creds.has_mfa,
    autoLoginEnabled: creds.auto_login_enabled,
    connectedAt: creds.connected_at,
    lastAutoLogin: creds.last_auto_login,
  });
}

async function handleCaptchaInfo(): Promise<Response> {
  return json({
    success: true,
    sitekey: "6LdWmBMhAAAAAHT3bLTH6JDQ9MatcSw0WzY5zogx",
    type: "reCAPTCHA_v2",
    note: "Captcha is frontend-only on Haveloc. It gates the login page route but is NOT sent to the server API.",
  });
}

// ─── Authenticated action handlers (require live Haveloc session) ────────────

async function getClientForUser(academiaEmail: string): Promise<{ client: HavelocClientAsync; uuid: string } | null> {
  const { data: creds } = await supabase
    .from(TABLE)
    .select("*")
    .eq("academia_email", academiaEmail)
    .single();

  if (!creds || !creds.auto_login_enabled || creds.has_mfa) return null;

  try {
    const password = await decryptPassword(creds.encrypted_password);
    const client = new HavelocClientAsync();
    const result = await login(client, creds.placement_username, password);
    if (result.requiresMfa) return null;

    await client.setAuth(result.token, result.phaveloc);
    return { client, uuid: result.uuid };
  } catch {
    return null;
  }
}

async function handleGetResumes(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);

  const session = await getClientForUser(academiaEmail);
  if (!session) return json({ success: false, error: "Could not establish session. Please reconnect your account." }, 401);

  try {
    const docs = await fetchStudentDocuments(session.client, session.uuid);
    return json({ success: true, data: docs });
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
}

async function handleApplyForJob(req: Request): Promise<Response> {
  const { academiaEmail, jobUuid, jobId, answers, resumeName } = await req.json();
  if (!academiaEmail || !jobUuid || !jobId) {
    return json({ success: false, error: "academiaEmail, jobUuid, and jobId are required" }, 400);
  }

  const session = await getClientForUser(academiaEmail);
  if (!session) return json({ success: false, error: "Could not establish session. Please reconnect your account." }, 401);

  try {
    const typedAnswers: ApplyAnswer[] = (answers || []).map((a: { questionId: number; responseOptions: string[] }) => ({
      questionId: a.questionId,
      responseOptions: a.responseOptions,
    }));
    const result = await havelocApplyForJob(session.client, jobUuid, jobId, typedAnswers, resumeName || "");
    return json({ success: true, data: result });
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
}

async function handleJobView(req: Request): Promise<Response> {
  const { academiaEmail, jobUuid } = await req.json();
  if (!academiaEmail || !jobUuid) {
    return json({ success: false, error: "academiaEmail and jobUuid are required" }, 400);
  }

  const session = await getClientForUser(academiaEmail);
  if (!session) return json({ success: false, error: "Could not establish session. Please reconnect your account." }, 401);

  try {
    const view = await fetchJobView(session.client, jobUuid);

    // Cache the job view for future gateway reads
    await supabase.from("placement_job_view_cache").upsert({
      job_uuid: jobUuid,
      data: view,
      updated_at: new Date().toISOString(),
    }, { onConflict: "job_uuid" });

    return json({ success: true, data: view });
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
}

// ─── Router ──────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  let path = url.pathname.replace(/\/$/, "");
  const fnPrefix = "/functions/v1/placement-session";
  if (path.startsWith(fnPrefix)) path = path.slice(fnPrefix.length);
  const fnPrefix2 = "/placement-session";
  if (path.startsWith(fnPrefix2)) path = path.slice(fnPrefix2.length);

  const method = req.method.toUpperCase();

  if (method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, x-academia-email",
      },
    });
  }

  try {
    if (path === "/login" || path === "" || path === "/") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleLogin(req);
    }
    if (path === "/verify-mfa") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleVerifyMfa(req);
    }
    if (path === "/send-mfa-email") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleSendMfaEmail(req);
    }
    if (path === "/logout") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleLogout(req);
    }
    if (path === "/connect") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleConnect(req);
    }
    if (path === "/auto-login") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleAutoLogin(req);
    }
    if (path === "/disconnect") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleDisconnect(req);
    }
    if (path === "/connection-status") {
      if (method !== "GET") return json({ error: "Method not allowed" }, 405);
      return await handleConnectionStatus(req);
    }
    if (path === "/captcha-info") {
      return await handleCaptchaInfo();
    }
    if (path === "/resumes") {
      if (method !== "GET") return json({ error: "Method not allowed" }, 405);
      return await handleGetResumes(req);
    }
    if (path === "/apply") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleApplyForJob(req);
    }
    if (path === "/job-view") {
      if (method !== "POST") return json({ error: "Method not allowed" }, 405);
      return await handleJobView(req);
    }

    return json({ error: "Not found" }, 404);
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
});
