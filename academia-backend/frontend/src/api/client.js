const BASE = "/api";

async function request(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });

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

  if (!data.success) throw new Error(data.message || "Request failed");
  return data;
}

export const api = {
  login: (email, password) =>
    request("/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    }),

  logout: (email) =>
    request("/logout", {
      method: "POST",
      body: JSON.stringify({ email }),
    }),

  init: (email) => request(`/init?email=${encodeURIComponent(email)}`),
  student: (email) => request(`/student?email=${encodeURIComponent(email)}`),
  attendance: (email) => request(`/attendance?email=${encodeURIComponent(email)}`),
  marks: (email) => request(`/marks?email=${encodeURIComponent(email)}`),
  timetable: (email) => request(`/timetable?email=${encodeURIComponent(email)}`),
  calendar: (email, sem = "even") =>
    request(`/calendar?email=${encodeURIComponent(email)}&sem=${sem}`),
  all: (email) => request(`/all?email=${encodeURIComponent(email)}`),
  summary: (email) => request(`/summary?email=${encodeURIComponent(email)}`),
  schedule: (email) => request(`/schedule?email=${encodeURIComponent(email)}`),
  studentPhoto: (email) => `${BASE}/student-photo?email=${encodeURIComponent(email)}`,
  facultyPhoto: (url) => `${BASE}/faculty-photo?url=${encodeURIComponent(url)}`,
  faculty: (name) => request(`/faculty?name=${encodeURIComponent(name)}`),

  // Profile caching
  getCachedProfile: (email) => request(`/profile/cache?email=${encodeURIComponent(email)}`),
  cacheProfile: (email, studentInfo) =>
    request("/profile/cache", {
      method: "POST",
      body: JSON.stringify({ email, studentInfo }),
    }),

  // Attendance history
  getAttendanceHistory: (email, days = 30) =>
    request(`/attendance/history?email=${encodeURIComponent(email)}&days=${days}`),
  saveAttendanceSnapshot: (email, subjects, overallPct) =>
    request("/attendance/snapshot", {
      method: "POST",
      body: JSON.stringify({ email, subjects, overallPct }),
    }),

  // Settings sync
  getSettings: (email) => request(`/settings?email=${encodeURIComponent(email)}`),
  saveSettings: (email, settings) =>
    request("/settings", {
      method: "POST",
      body: JSON.stringify({ email, settings }),
    }),

  // Notifications
  getNotifications: (email, unreadOnly = false) =>
    request(`/notifications?email=${encodeURIComponent(email)}&unreadOnly=${unreadOnly}`),
  createNotification: (email, { type, title, body, data }) =>
    request("/notifications", {
      method: "POST",
      body: JSON.stringify({ email, type, title, body, data }),
    }),
  markNotificationRead: (id) =>
    request(`/notifications/${id}/read`, { method: "PATCH" }),
  markAllNotificationsRead: (email) =>
    request("/notifications/read-all", {
      method: "POST",
      body: JSON.stringify({ email }),
    }),

  // Notification settings
  getNotificationSettings: (email) =>
    request(`/notification-settings?email=${encodeURIComponent(email)}`),
  saveNotificationSettings: (email, settings) =>
    request("/notification-settings", {
      method: "POST",
      body: JSON.stringify({ email, settings }),
    }),

  // Job bookmarks
  getBookmarks: (email) => request(`/bookmarks?email=${encodeURIComponent(email)}`),
  addBookmark: (email, { jobUuid, jobTitle, companyName, jobData, notes }) =>
    request("/bookmarks", {
      method: "POST",
      body: JSON.stringify({ email, jobUuid, jobTitle, companyName, jobData, notes }),
    }),
  removeBookmark: (email, jobUuid) =>
    request(`/bookmarks/${encodeURIComponent(jobUuid)}?email=${encodeURIComponent(email)}`, {
      method: "DELETE",
    }),
  updateBookmark: (email, jobUuid, updates) =>
    request(`/bookmarks/${encodeURIComponent(jobUuid)}`, {
      method: "PATCH",
      body: JSON.stringify({ email, updates }),
    }),
};
