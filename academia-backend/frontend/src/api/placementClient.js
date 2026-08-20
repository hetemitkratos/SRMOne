const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || "https://kolpioxbznypmvivbdhn.supabase.co";
const SESSION_BASE = `${SUPABASE_URL}/functions/v1/placement-session`;
const GATEWAY_BASE = `${SUPABASE_URL}/functions/v1/placement-gateway`;

// Cache the academia email so we can send it as a header for data requests
let _academiaEmail = null;
export function setAcademiaEmail(email) { _academiaEmail = email; }

async function sessionRequest(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  if (_academiaEmail) headers["x-academia-email"] = _academiaEmail;

  const res = await fetch(`${SESSION_BASE}${path}`, {
    ...options,
    headers,
  });

  const text = await res.text();
  if (!text) {
    throw new Error(`Empty response from server (status ${res.status})`);
  }

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`Invalid JSON response (status ${res.status}): ${text.substring(0, 200)}`);
  }

  if (!data.success) throw new Error(data.error || data.message || "Request failed");
  return data;
}

async function gatewayRequest(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  if (_academiaEmail) headers["x-academia-email"] = _academiaEmail;

  const res = await fetch(`${GATEWAY_BASE}${path}`, {
    ...options,
    headers,
  });

  const text = await res.text();
  if (!text) {
    throw new Error(`Empty response from server (status ${res.status})`);
  }

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`Invalid JSON response (status ${res.status}): ${text.substring(0, 200)}`);
  }

  if (!data.success) throw new Error(data.error || data.message || "Request failed");
  return data;
}

export const placementApi = {
  // ─── Session routes (placement-session Edge Function) ──────────────────────

  login: (username, password) =>
    sessionRequest("/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    }),

  verifyMfa: (username, mfaToken, totpCode, emailOtp) =>
    sessionRequest("/verify-mfa", {
      method: "POST",
      body: JSON.stringify({ username, mfaToken, totpCode, emailOtp }),
    }),

  sendMfaEmail: (mfaToken) =>
    sessionRequest("/send-mfa-email", {
      method: "POST",
      body: JSON.stringify({ mfaToken }),
    }),

  /** Connect placement account and store encrypted credentials */
  connect: (academiaEmail, username, password) =>
    sessionRequest("/connect", {
      method: "POST",
      body: JSON.stringify({ academiaEmail, username, password }),
    }),

  /** Attempt silent auto-login using stored credentials */
  autoLogin: (academiaEmail) =>
    sessionRequest("/auto-login", {
      method: "POST",
      body: JSON.stringify({ academiaEmail }),
    }),

  /** Remove stored credentials */
  disconnect: (academiaEmail) =>
    sessionRequest("/disconnect", {
      method: "POST",
      body: JSON.stringify({ academiaEmail }),
    }),

  /** Check if placement account is connected */
  connectionStatus: (academiaEmail) =>
    sessionRequest("/connection-status", {
      headers: { "x-academia-email": academiaEmail },
    }),

  logout: (username) =>
    sessionRequest("/logout", {
      method: "POST",
      body: JSON.stringify({ username }),
    }),

  captchaInfo: () => sessionRequest("/captcha-info"),

  // ─── Data routes (placement-gateway Edge Function — reads from cache) ───────

  companies: (username, page = 0, size = 20) =>
    gatewayRequest("/companies"),

  jobs: (username, page = 0, size = 20) =>
    gatewayRequest("/jobs"),

  tracker: (username) =>
    gatewayRequest("/tracker"),

  profile: (username) =>
    gatewayRequest("/profile"),

  notices: (username, page = 0, size = 20) =>
    gatewayRequest("/notices"),

  policies: (username) =>
    gatewayRequest("/policies"),

  globalPolicy: (username) =>
    gatewayRequest("/global-policy"),

  calendar: (username) =>
    gatewayRequest("/calendar"),

  insights: (username) =>
    gatewayRequest("/insights"),

  studentStats: (username) =>
    gatewayRequest("/student-stats"),

  socialMedia: (username) =>
    gatewayRequest("/social-media"),

  syncStatus: () =>
    gatewayRequest("/sync-status"),

  // ─── Authenticated actions (placement-session — live Haveloc session) ───────

  /** No-op in cache architecture — data is refreshed every 5 min by sync */
  refresh: (username, section) =>
    sessionRequest("/captcha-info").then(() => ({ success: true })),

  /** Fetch student documents (resumes) — requires live session */
  getResumes: (username) =>
    sessionRequest("/resumes"),

  /** Apply for a job — requires live session */
  applyForJob: (username, jobUuid, jobId, answers, resumeName) =>
    sessionRequest("/apply", {
      method: "POST",
      body: JSON.stringify({ academiaEmail: _academiaEmail, jobUuid, jobId, answers, resumeName }),
    }),

  /** Fetch job view with questions — requires live session, caches result */
  jobView: (username, jobUuid) =>
    sessionRequest("/job-view", {
      method: "POST",
      body: JSON.stringify({ academiaEmail: _academiaEmail, jobUuid }),
    }),
};
