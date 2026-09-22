/**
 * Supabase client for academia backend.
 * Handles: student profiles, attendance snapshots, user settings, notifications.
 * Uses service role key — backend-only, never exposed to frontend.
 */
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.SUPABASE_URL || "";
const supabaseKey = process.env.SUPABASE_SERVICE_KEY || "";

if (!supabaseUrl || !supabaseKey || supabaseKey === "your-service-role-key-here") {
  console.warn("[supabase] SUPABASE_URL or SUPABASE_SERVICE_KEY not configured. DB caching disabled.");
} else {
  console.log(`[supabase] Initialized with URL: ${supabaseUrl}`);
}

export const supabase = (supabaseUrl && supabaseKey && supabaseKey !== "your-service-role-key-here")
  ? createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
  : null;

// ─── Egress guard: in-memory cache + circuit breaker ──────────────────────────
// The free-tier Supabase project has a hard egress cap. Every read below used to
// hit the network on every call, even for data that barely changes (faculty
// photos, session cookies checked on every request). This cache dedupes reads
// within a TTL window, and the breaker stops hammering Supabase once it starts
// returning quota-exceeded errors — retrying a blocked project just wastes time
// and keeps the quota pinned once it resets.

const readCache = new Map(); // key -> { value, expiresAt }

function cacheGet(key) {
  const hit = readCache.get(key);
  if (!hit) return undefined;
  if (Date.now() > hit.expiresAt) {
    readCache.delete(key);
    return undefined;
  }
  return hit.value;
}

function cacheSet(key, value, ttlMs) {
  readCache.set(key, { value, expiresAt: Date.now() + ttlMs });
}

const QUOTA_COOLDOWN_MS = 5 * 60 * 1000; // stop hitting Supabase for 5min after a quota error
let quotaBlockedUntil = 0;

function isQuotaError(error) {
  return !!error && /exceed_egress_quota|Service for this project is restricted/i.test(error.message || "");
}

function noteError(error) {
  if (isQuotaError(error)) {
    quotaBlockedUntil = Date.now() + QUOTA_COOLDOWN_MS;
  }
}

function isQuotaBlocked() {
  return Date.now() < quotaBlockedUntil;
}

/**
 * Wrap a cached read. `fn` is only called if not in cooldown and not cached.
 * `fallback` is returned (without hitting the network) while quota-blocked.
 */
async function cachedRead(key, ttlMs, fn, fallback) {
  const cached = cacheGet(key);
  if (cached !== undefined) return cached;
  if (isQuotaBlocked()) return fallback;
  const value = await fn();
  cacheSet(key, value, ttlMs);
  return value;
}

function invalidate(key) {
  readCache.delete(key);
}

// ─── Student Profiles ────────────────────────────────────────────────────────

export async function cacheStudentProfile(email, studentInfo) {
  if (!supabase) return null;
  const profile = {
    academia_email: email,
    name: studentInfo?.Name || null,
    reg_number: studentInfo?.RegistrationNumber || null,
    photo_url: studentInfo?.PhotoUrl || null,
    branch: studentInfo?.Department || null,
    semester: studentInfo?.Semester ? String(studentInfo.Semester) : null,
    batch: studentInfo?.Batch || null,
    raw_data: studentInfo,
    cached_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  const { data, error } = await supabase
    .from("student_profiles")
    .upsert(profile, { onConflict: "academia_email" })
    .select()
    .single();
  if (error) { noteError(error); console.error("[supabase] cacheStudentProfile:", error.message); }
  else invalidate(`profile:${email}`);
  return data;
}

export async function getCachedProfile(email) {
  if (!supabase) return null;
  return cachedRead(`profile:${email}`, 5 * 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("student_profiles")
      .select("*")
      .eq("academia_email", email)
      .single();
    if (error) {
      noteError(error);
      if (error.code === "PGRST116") return null;
      console.error("[supabase] getCachedProfile:", error.message);
      return null;
    }
    return data;
  }, null);
}

// ─── Attendance Snapshots ────────────────────────────────────────────────────

export async function saveAttendanceSnapshot(email, subjects, overallPct) {
  if (!supabase) return null;
  const today = new Date().toISOString().slice(0, 10);
  const totalClasses = subjects.reduce((sum, s) => sum + (parseInt(s.hoursConducted) || 0), 0);
  const attendedClasses = subjects.reduce((sum, s) => sum + ((parseInt(s.hoursConducted) || 0) - (parseInt(s.hoursAbsent) || 0)), 0);

  const { data, error } = await supabase
    .from("attendance_snapshots")
    .upsert({
      academia_email: email,
      snapshot_date: today,
      overall_percentage: overallPct,
      subjects: subjects,
      total_classes: totalClasses,
      attended_classes: attendedClasses,
    }, { onConflict: "academia_email,snapshot_date" })
    .select()
    .single();
  if (error) {
    noteError(error);
    console.error("[supabase] saveAttendanceSnapshot:", error.message);
  } else {
    console.log(`[supabase] ✓ Attendance snapshot saved for ${email} (${today}): ${overallPct?.toFixed(1)}%`);
  }
  return data;
}

export async function getAttendanceHistory(email, days = 30) {
  if (!supabase) return [];
  const since = new Date();
  since.setDate(since.getDate() - days);
  const { data, error } = await supabase
    .from("attendance_snapshots")
    .select("*")
    .eq("academia_email", email)
    .gte("snapshot_date", since.toISOString().slice(0, 10))
    .order("snapshot_date", { ascending: true });
  if (error) {
    noteError(error);
    console.error("[supabase] getAttendanceHistory:", error.message);
    return [];
  }
  return data || [];
}

// ─── User Settings ───────────────────────────────────────────────────────────

export async function getUserSettings(email) {
  if (!supabase) return null;
  return cachedRead(`usersettings:${email}`, 5 * 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("user_settings")
      .select("*")
      .eq("academia_email", email)
      .single();
    if (error) {
      noteError(error);
      if (error.code === "PGRST116") return null;
      console.error("[supabase] getUserSettings:", error.message);
      return null;
    }
    return data;
  }, null);
}

export async function upsertUserSettings(email, settings) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("user_settings")
    .upsert({
      academia_email: email,
      ...settings,
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" })
    .select()
    .single();
  if (error) { noteError(error); console.error("[supabase] upsertUserSettings:", error.message); }
  else invalidate(`usersettings:${email}`);
  return data;
}

// ─── Notifications ───────────────────────────────────────────────────────────

export async function createNotification(email, { type, title, body, data = {} }) {
  if (!supabase) return null;
  const { data: notif, error } = await supabase
    .from("notifications")
    .insert({ academia_email: email, type, title, body, data })
    .select()
    .single();
  if (error) console.error("[supabase] createNotification:", error.message);
  return notif;
}

export async function hasNotificationOfType(email, type) {
  if (!supabase) return false;
  const { count, error } = await supabase
    .from("notifications")
    .select("*", { count: "exact", head: true })
    .eq("academia_email", email)
    .eq("type", type);
  if (error) { console.error("[supabase] hasNotificationOfType:", error.message); return false; }
  return (count || 0) > 0;
}

export async function hasUnreadNotificationOfType(email, type) {
  if (!supabase) return false;
  const { count, error } = await supabase
    .from("notifications")
    .select("*", { count: "exact", head: true })
    .eq("academia_email", email)
    .eq("type", type)
    .eq("read", false);
  if (error) { console.error("[supabase] hasUnreadNotificationOfType:", error.message); return false; }
  return (count || 0) > 0;
}

/**
 * True if a low_attendance (or similar) notif was created recently for a similar subject set.
 * Prevents daily spam while still re-alerting when the situation changes or days later.
 */
export async function hasRecentNotificationOfType(email, type, withinHours = 24) {
  if (!supabase) return false;
  const since = new Date(Date.now() - withinHours * 60 * 60 * 1000).toISOString();
  const { count, error } = await supabase
    .from("notifications")
    .select("*", { count: "exact", head: true })
    .eq("academia_email", email)
    .eq("type", type)
    .gte("created_at", since);
  if (error) {
    console.error("[supabase] hasRecentNotificationOfType:", error.message);
    return false;
  }
  return (count || 0) > 0;
}

/**
 * Latest notification of a type (any read state), or null.
 */
export async function getLatestNotificationOfType(email, type) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("notifications")
    .select("*")
    .eq("academia_email", email)
    .eq("type", type)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) {
    console.error("[supabase] getLatestNotificationOfType:", error.message);
    return null;
  }
  return data || null;
}

export async function getNotifications(email, unreadOnly = false) {
  if (!supabase) return [];
  let query = supabase
    .from("notifications")
    .select("*")
    .eq("academia_email", email)
    .order("created_at", { ascending: false })
    .limit(50);
  if (unreadOnly) query = query.eq("read", false);
  const { data, error } = await query;
  if (error) {
    console.error("[supabase] getNotifications:", error.message);
    return [];
  }
  return data || [];
}

export async function markNotificationRead(id) {
  if (!supabase) return;
  const { error } = await supabase
    .from("notifications")
    .update({ read: true })
    .eq("id", id);
  if (error) console.error("[supabase] markNotificationRead:", error.message);
}

export async function markAllNotificationsRead(email) {
  if (!supabase) return;
  const { error } = await supabase
    .from("notifications")
    .update({ read: true })
    .eq("academia_email", email)
    .eq("read", false);
  if (error) console.error("[supabase] markAllNotificationsRead:", error.message);
}

// ─── Notification Settings ───────────────────────────────────────────────────

export async function getNotificationSettings(email) {
  if (!supabase) return null;
  return cachedRead(`notifsettings:${email}`, 5 * 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("notification_settings")
      .select("*")
      .eq("academia_email", email)
      .single();
    if (error) {
      noteError(error);
      if (error.code === "PGRST116") return null;
      return null;
    }
    return data;
  }, null);
}

export async function upsertNotificationSettings(email, settings) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("notification_settings")
    .upsert({
      academia_email: email,
      ...settings,
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" })
    .select()
    .single();
  if (error) { noteError(error); console.error("[supabase] upsertNotificationSettings:", error.message); }
  else invalidate(`notifsettings:${email}`);
  return data;
}

// ─── Faculty Profile Cache ───────────────────────────────────────────────────
// Persists scraped faculty profiles so we don't re-scrape SRM on every request.

// Faculty profiles barely ever change — cache reads for a full day in-process
// so a timetable with 6+ faculty doesn't issue 6+ Supabase round trips per view.
const FACULTY_CACHE_TTL_MS = 24 * 60 * 60 * 1000;

export async function getCachedFacultyProfile(cacheKey) {
  if (!supabase) return null;
  return cachedRead(`faculty:${cacheKey}`, FACULTY_CACHE_TTL_MS, async () => {
    const { data, error } = await supabase
      .from("faculty_cache")
      .select("profile_data, fetched_at")
      .eq("cache_key", cacheKey)
      .maybeSingle();
    if (error) {
      noteError(error);
      console.error("[supabase] getCachedFacultyProfile:", error.message);
      return null;
    }
    return data;
  }, null);
}

export async function saveCachedFacultyProfile(cacheKey, profileData) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("faculty_cache")
    .upsert({
      cache_key: cacheKey,
      profile_data: profileData,
      fetched_at: new Date().toISOString(),
    }, { onConflict: "cache_key" });
  if (error) {
    noteError(error);
    console.error("[supabase] saveCachedFacultyProfile:", error.message);
  } else {
    cacheSet(`faculty:${cacheKey}`, { profile_data: profileData, fetched_at: new Date().toISOString() }, FACULTY_CACHE_TTL_MS);
  }
  return null;
}

// ─── Academia Credentials (encrypted) ─────────────────────────────────────────

export async function saveAcademiaCredentials(email, encryptedPassword, encryptedSpPassword = null) {
  if (!supabase) return null;
  const patch = {
    academia_email: email,
    updated_at: new Date().toISOString(),
  };
  if (encryptedPassword !== undefined) patch.encrypted_password = encryptedPassword;
  if (encryptedSpPassword !== undefined) patch.encrypted_sp_password = encryptedSpPassword;
  const { data, error } = await supabase
    .from("academia_credentials")
    .upsert(patch, { onConflict: "academia_email" })
    .select()
    .single();
  if (error) { noteError(error); console.error("[supabase] saveAcademiaCredentials:", error.message); }
  else { invalidate(`credentials:${email}`); invalidate("autologinemails"); }
  return data;
}

export async function getAcademiaCredentials(email) {
  if (!supabase) return null;
  return cachedRead(`credentials:${email}`, 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("academia_credentials")
      .select("*")
      .eq("academia_email", email)
      .maybeSingle();
    if (error) {
      noteError(error);
      console.error("[supabase] getAcademiaCredentials:", error.message);
      return null;
    }
    return data;
  }, null);
}

export async function getAllAutoLoginEmails() {
  if (!supabase) return [];
  return cachedRead("autologinemails", 5 * 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("academia_credentials")
      .select("academia_email, encrypted_password, encrypted_sp_password, last_auto_login")
      .eq("auto_login_enabled", true);
    if (error) {
      noteError(error);
      console.error("[supabase] getAllAutoLoginEmails:", error.message);
      return [];
    }
    return data || [];
  }, []);
}

export async function updateAutoLoginTimestamp(email) {
  if (!supabase) return;
  const { error } = await supabase
    .from("academia_credentials")
    .update({ last_auto_login: new Date().toISOString() })
    .eq("academia_email", email);
  if (error) { noteError(error); console.error("[supabase] updateAutoLoginTimestamp:", error.message); }
}

export async function setAutoLoginEnabled(email, enabled) {
  if (!supabase) return;
  const { error } = await supabase
    .from("academia_credentials")
    .update({ auto_login_enabled: enabled, updated_at: new Date().toISOString() })
    .eq("academia_email", email);
  if (error) { noteError(error); console.error("[supabase] setAutoLoginEnabled:", error.message); }
  else { invalidate(`credentials:${email}`); invalidate("autologinemails"); }
}

export async function deleteAcademiaCredentials(email) {
  if (!supabase) return;
  const { error } = await supabase
    .from("academia_credentials")
    .delete()
    .eq("academia_email", email);
  if (error) { noteError(error); console.error("[supabase] deleteAcademiaCredentials:", error.message); }
  else { invalidate(`credentials:${email}`); invalidate("autologinemails"); }
}

// ─── Persisted portal sessions (encrypted cookies) ────────────────────────────

/**
 * Upsert encrypted cookie blobs for a user. Pass only the side that changed:
 * { academia: "<enc>", academiaMeta: {...} } and/or { sp: "<enc>" }.
 * Pass null for a side to clear it.
 */
export async function saveSessionCookies(email, { academia, academiaMeta, sp } = {}) {
  if (!supabase) return null;
  const now = new Date().toISOString();
  const patch = { academia_email: email, updated_at: now };
  if (academia !== undefined) {
    patch.encrypted_academia_cookies = academia;
    patch.academia_saved_at = academia ? now : null;
    if (academiaMeta !== undefined) patch.academia_meta = academiaMeta;
  }
  if (sp !== undefined) {
    patch.encrypted_sp_cookies = sp;
    patch.sp_saved_at = sp ? now : null;
  }
  const { error } = await supabase
    .from("academia_sessions")
    .upsert(patch, { onConflict: "academia_email" });
  if (error) { noteError(error); console.error("[supabase] saveSessionCookies:", error.message); }
  else invalidate(`sessioncookies:${email}`);
  return !error;
}

export async function getSessionCookies(email) {
  if (!supabase) return null;
  return cachedRead(`sessioncookies:${email}`, 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("academia_sessions")
      .select("*")
      .eq("academia_email", email)
      .maybeSingle();
    if (error) {
      noteError(error);
      console.error("[supabase] getSessionCookies:", error.message);
      return null;
    }
    return data;
  }, null);
}

export async function clearSessionCookies(email) {
  if (!supabase) return;
  const { error } = await supabase
    .from("academia_sessions")
    .delete()
    .eq("academia_email", email);
  if (error) { noteError(error); console.error("[supabase] clearSessionCookies:", error.message); }
  else invalidate(`sessioncookies:${email}`);
}

// ─── Timetable Cache ──────────────────────────────────────────────────────────

export async function getCachedTimetable(email) {
  if (!supabase) return null;
  return cachedRead(`timetable:${email}`, 10 * 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("timetable_cache")
      .select("timetable, cached_at")
      .eq("academia_email", email)
      .maybeSingle();
    if (error) { noteError(error); console.error("[supabase] getCachedTimetable:", error.message); return null; }
    return data;
  }, null);
}

export async function cacheTimetable(email, timetable) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("timetable_cache")
    .upsert({
      academia_email: email,
      timetable,
      cached_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" });
  if (error) { noteError(error); console.error("[supabase] cacheTimetable:", error.message); }
  else invalidate(`timetable:${email}`);
  return null;
}

// ─── Marks Cache ──────────────────────────────────────────────────────────────

export async function getCachedMarks(email) {
  if (!supabase) return null;
  return cachedRead(`marks:${email}`, 10 * 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("marks_cache")
      .select("marks, cached_at")
      .eq("academia_email", email)
      .maybeSingle();
    if (error) { noteError(error); console.error("[supabase] getCachedMarks:", error.message); return null; }
    return data;
  }, null);
}

export async function cacheMarks(email, marks) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("marks_cache")
    .upsert({
      academia_email: email,
      marks,
      cached_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" });
  if (error) { noteError(error); console.error("[supabase] cacheMarks:", error.message); }
  else invalidate(`marks:${email}`);
  return null;
}

// ─── Calendar Cache ───────────────────────────────────────────────────────────

export async function getCachedCalendar(email, sem) {
  if (!supabase) return null;
  return cachedRead(`calendar:${email}:${sem}`, 30 * 60 * 1000, async () => {
    const { data, error } = await supabase
      .from("calendar_cache")
      .select("calendar, cached_at")
      .eq("academia_email", email)
      .eq("sem", sem)
      .maybeSingle();
    if (error) { noteError(error); console.error("[supabase] getCachedCalendar:", error.message); return null; }
    return data;
  }, null);
}

export async function cacheCalendar(email, sem, calendar) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("calendar_cache")
    .upsert({
      academia_email: email,
      sem,
      calendar,
      cached_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email,sem" });
  if (error) { noteError(error); console.error("[supabase] cacheCalendar:", error.message); }
  else invalidate(`calendar:${email}:${sem}`);
  return null;
}
