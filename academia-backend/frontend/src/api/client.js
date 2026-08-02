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
};
