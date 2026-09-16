const BASE = "/placement-api";

// Cache the academia email so we can send it as a header for notifications
let _academiaEmail = null;
export function setAcademiaEmail(email) { _academiaEmail = email; }

async function request(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  if (_academiaEmail) headers["x-academia-email"] = _academiaEmail;

  const res = await fetch(`${BASE}${path}`, {
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

function getAuthHeaders(username) {
  return { "x-user-email": username };
}

export const placementApi = {
  login: (username, password) =>
    request("/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    }),

  verifyMfa: (username, mfaToken, totpCode, emailOtp) =>
    request("/verify-mfa", {
      method: "POST",
      body: JSON.stringify({ username, mfaToken, totpCode, emailOtp }),
    }),

  sendMfaEmail: (mfaToken) =>
    request("/send-mfa-email", {
      method: "POST",
      body: JSON.stringify({ mfaToken }),
    }),

  // ─── One-time connect + auto-login (Supabase credential storage) ──────────

  /** Connect placement account and store encrypted credentials */
  connect: (academiaEmail, username, password) =>
    request("/connect", {
      method: "POST",
      body: JSON.stringify({ academiaEmail, username, password }),
    }),

  /** Attempt silent auto-login using stored credentials */
  autoLogin: (academiaEmail) =>
    request("/auto-login", {
      method: "POST",
      body: JSON.stringify({ academiaEmail }),
    }),

  /** Remove stored credentials and destroy session */
  disconnect: (academiaEmail) =>
    request("/disconnect", {
      method: "POST",
      body: JSON.stringify({ academiaEmail }),
    }),

  /** Check if placement account is connected */
  connectionStatus: (academiaEmail) =>
    request("/connection-status", {
      headers: { "x-academia-email": academiaEmail },
    }),

  logout: (username) =>
    request("/logout", {
      method: "POST",
      body: JSON.stringify({ username }),
    }),

  status: (username) =>
    request(`/status`, { headers: getAuthHeaders(username) }),

  companies: (username, page = 0, size = 20) =>
    request(`/companies?page=${page}&size=${size}`, { headers: getAuthHeaders(username) }),

  jobs: (username, page = 0, size = 20) =>
    request(`/jobs?page=${page}&size=${size}`, { headers: getAuthHeaders(username) }),

  tracker: (username) =>
    request(`/tracker`, { headers: getAuthHeaders(username) }),

  profile: (username) =>
    request(`/profile`, { headers: getAuthHeaders(username) }),

  notices: (username, page = 0, size = 20) =>
    request(`/notices?page=${page}&size=${size}`, { headers: getAuthHeaders(username) }),

  policies: (username) =>
    request(`/policies`, { headers: getAuthHeaders(username) }),

  globalPolicy: (username) =>
    request(`/global-policy`, { headers: getAuthHeaders(username) }),

  calendar: (username) =>
    request(`/calendar`, { headers: getAuthHeaders(username) }),

  insights: (username) =>
    request(`/insights`, { headers: getAuthHeaders(username) }),

  studentStats: (username) =>
    request(`/student-stats`, { headers: getAuthHeaders(username) }),

  placementCycles: (username) =>
    request(`/placement-cycles`, { headers: getAuthHeaders(username) }),

  socialMedia: (username) =>
    request(`/social-media`, { headers: getAuthHeaders(username) }),

  all: (username) =>
    request(`/all`, { headers: getAuthHeaders(username) }),

  refresh: (username, section) =>
    request("/refresh", {
      method: "POST",
      headers: getAuthHeaders(username),
      body: JSON.stringify({ section }),
    }),

  captchaInfo: () => request("/captcha-info"),

  getResumes: (username) =>
    request("/resumes", { headers: getAuthHeaders(username) }),

  applyForJob: (username, jobUuid, jobId, answers, resumeName) =>
    request("/apply", {
      method: "POST",
      headers: getAuthHeaders(username),
      body: JSON.stringify({ jobUuid, jobId, answers, resumeName }),
    }),
};
