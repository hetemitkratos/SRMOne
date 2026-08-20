const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || "https://kolpioxbznypmvivbdhn.supabase.co";
const AUTH_BASE = `${SUPABASE_URL}/functions/v1/auth-session`;
const API_BASE = `${SUPABASE_URL}/functions/v1/api-gateway`;

let _sessionToken = localStorage.getItem("srm_session_token") || null;

export function setSessionToken(token) {
  _sessionToken = token;
  if (token) localStorage.setItem("srm_session_token", token);
}
export function getSessionToken() { return _sessionToken; }
export function clearSessionToken() {
  _sessionToken = null;
  localStorage.removeItem("srm_session_token");
}

let _isRefreshing = false;

async function refreshToken() {
  if (_isRefreshing) return false;
  _isRefreshing = true;
  try {
    const res = await fetch(`${AUTH_BASE}/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...( _sessionToken ? { "x-session-token": _sessionToken } : {}) },
    });
    const data = await res.json();
    if (data.success && data.token) {
      setSessionToken(data.token);
      return true;
    }
    return false;
  } catch {
    return false;
  } finally {
    _isRefreshing = false;
  }
}

async function request(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  if (_sessionToken) headers["x-session-token"] = _sessionToken;

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  // Auto-refresh on 401: try to refresh token and retry once
  if (res.status === 401) {
    const refreshed = await refreshToken();
    if (refreshed) {
      const retryHeaders = { ...headers, "x-session-token": _sessionToken };
      const retryRes = await fetch(`${API_BASE}${path}`, { ...options, headers: retryHeaders });
      const retryText = await retryRes.text();
      if (!retryText) throw new Error(`Server returned empty response (status ${retryRes.status})`);
      let retryData;
      try { retryData = JSON.parse(retryText); } catch { throw new Error(`Invalid response from server (status ${retryRes.status})`); }
      if (!retryData.success) throw new Error(retryData.error || retryData.message || "Request failed");
      return retryData;
    }
  }

  const text = await res.text();
  if (!text) {
    throw new Error(`Server returned empty response (status ${res.status}). Is the academia backend running?`);
  }

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`Invalid response from server (status ${res.status})`);
  }

  if (!data.success) throw new Error(data.error || data.message || "Request failed");
  return data;
}

async function authRequest(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  if (_sessionToken) headers["x-session-token"] = _sessionToken;

  const res = await fetch(`${AUTH_BASE}${path}`, {
    ...options,
    headers,
  });

  const text = await res.text();
  if (!text) {
    throw new Error(`Server returned empty response (status ${res.status})`);
  }

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`Invalid response from server (status ${res.status})`);
  }

  if (!data.success) throw new Error(data.error || data.message || "Request failed");
  return data;
}

export const api = {
  login: async (email, password, spPassword) => {
    const data = await authRequest("/login", {
      method: "POST",
      body: JSON.stringify({ email, password, spPassword: spPassword || undefined }),
    });
    if (data.token) setSessionToken(data.token);
    return data;
  },

  autoLogin: async (email) => {
    const data = await authRequest("/refresh", {
      method: "POST",
    });
    if (data.token) setSessionToken(data.token);
    return data;
  },

  spLogin: (email, spPassword) =>
    authRequest("/sp-login", {
      method: "POST",
      body: JSON.stringify({ spPassword }),
    }),

  logout: () => {
    const p = authRequest("/logout", { method: "POST" });
    clearSessionToken();
    return p;
  },

  init: (email) => request(`/summary`),
  student: (email) => request(`/profile`),
  attendance: (email) => request(`/attendance`),
  marks: (email) => request(`/marks`),
  timetable: (email) => request(`/timetable`),
  calendar: (email, sem = "even") =>
    request(`/calendar?sem=${sem}`),
  all: (email) => request(`/summary`),
  summary: (email) => request(`/summary`),
  schedule: (email) => request(`/summary`),
  studentPhoto: (email) => null,
  facultyPhoto: (url) => null,
  faculty: (name) => request(`/faculty?name=${encodeURIComponent(name)}`),

  // Profile caching (handled by sync, no-op on frontend)
  getCachedProfile: (email) => request(`/profile`),
  cacheProfile: (email, studentInfo) =>
    Promise.resolve({ success: true }),

  // Attendance history
  getAttendanceHistory: (email, days = 30) =>
    request(`/attendance/history?days=${days}`),
  saveAttendanceSnapshot: (email, subjects, overallPct) =>
    Promise.resolve({ success: true }),

  // Settings sync
  getSettings: (email) => request(`/settings`),
  saveSettings: (email, settings) =>
    request("/settings", {
      method: "PUT",
      body: JSON.stringify(settings),
    }),

  // Notifications
  getNotifications: (email, unreadOnly = false) =>
    request(`/notifications?unreadOnly=${unreadOnly}`),
  createNotification: (email, { type, title, body, data }) =>
    request("/notifications", {
      method: "POST",
      body: JSON.stringify({ type, title, body, data }),
    }),
  markNotificationRead: (id) =>
    request(`/notifications/${id}/read`, { method: "POST" }),
  markAllNotificationsRead: (email) =>
    request("/notifications/read-all", { method: "POST" }),

  // Notification settings
  getNotificationSettings: (email) =>
    request(`/notification-settings`),
  saveNotificationSettings: (email, settings) =>
    request("/notification-settings", {
      method: "PUT",
      body: JSON.stringify(settings),
    }),

  // Job bookmarks
  getBookmarks: (email) => request(`/bookmarks`),
  addBookmark: (email, { jobUuid, jobTitle, companyName, jobData, notes }) =>
    request("/bookmarks", {
      method: "POST",
      body: JSON.stringify({ jobUuid, jobTitle, companyName, jobData, notes }),
    }),
  removeBookmark: (email, jobUuid) =>
    request(`/bookmarks/${encodeURIComponent(jobUuid)}`, {
      method: "DELETE",
    }),
  updateBookmark: (email, jobUuid, updates) =>
    request(`/bookmarks/${encodeURIComponent(jobUuid)}`, {
      method: "PATCH",
      body: JSON.stringify({ updates }),
    }),

  // Student Portal (sp.srmist.edu.in) — not yet migrated
  spAttendance: (email) =>
    Promise.resolve({ success: false, error: "SP portal not yet migrated" }),
  spStudent: (email) =>
    Promise.resolve({ success: false, error: "SP portal not yet migrated" }),
};
