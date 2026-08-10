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
  if (error) console.error("[supabase] cacheStudentProfile:", error.message);
  return data;
}

export async function getCachedProfile(email) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("student_profiles")
    .select("*")
    .eq("academia_email", email)
    .single();
  if (error) {
    if (error.code === "PGRST116") return null;
    console.error("[supabase] getCachedProfile:", error.message);
    return null;
  }
  return data;
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
    console.error("[supabase] getAttendanceHistory:", error.message);
    return [];
  }
  return data || [];
}

// ─── User Settings ───────────────────────────────────────────────────────────

export async function getUserSettings(email) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("user_settings")
    .select("*")
    .eq("academia_email", email)
    .single();
  if (error) {
    if (error.code === "PGRST116") return null;
    console.error("[supabase] getUserSettings:", error.message);
    return null;
  }
  return data;
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
  if (error) console.error("[supabase] upsertUserSettings:", error.message);
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
  const { data, error } = await supabase
    .from("notification_settings")
    .select("*")
    .eq("academia_email", email)
    .single();
  if (error) {
    if (error.code === "PGRST116") return null;
    return null;
  }
  return data;
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
  if (error) console.error("[supabase] upsertNotificationSettings:", error.message);
  return data;
}

// ─── Job Bookmarks ───────────────────────────────────────────────────────────

export async function getJobBookmarks(email) {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("job_bookmarks")
    .select("*")
    .eq("academia_email", email)
    .order("bookmarked_at", { ascending: false });
  if (error) {
    console.error("[supabase] getJobBookmarks:", error.message);
    return [];
  }
  return data || [];
}

export async function addJobBookmark(email, { jobUuid, jobTitle, companyName, jobData, notes }) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("job_bookmarks")
    .upsert({
      academia_email: email,
      job_uuid: jobUuid,
      job_title: jobTitle,
      company_name: companyName,
      job_data: jobData,
      notes: notes || "",
    }, { onConflict: "academia_email,job_uuid" })
    .select()
    .single();
  if (error) console.error("[supabase] addJobBookmark:", error.message);
  return data;
}

export async function updateJobBookmark(email, jobUuid, updates) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("job_bookmarks")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("academia_email", email)
    .eq("job_uuid", jobUuid)
    .select()
    .single();
  if (error) console.error("[supabase] updateJobBookmark:", error.message);
  return data;
}

export async function removeJobBookmark(email, jobUuid) {
  if (!supabase) return;
  const { error } = await supabase
    .from("job_bookmarks")
    .delete()
    .eq("academia_email", email)
    .eq("job_uuid", jobUuid);
  if (error) console.error("[supabase] removeJobBookmark:", error.message);
}

// ─── Faculty Profile Cache ───────────────────────────────────────────────────
// Persists scraped faculty profiles so we don't re-scrape SRM on every request.

export async function getCachedFacultyProfile(cacheKey) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("faculty_cache")
    .select("profile_data, fetched_at")
    .eq("cache_key", cacheKey)
    .maybeSingle();
  if (error) {
    console.error("[supabase] getCachedFacultyProfile:", error.message);
    return null;
  }
  return data;
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
  if (error) console.error("[supabase] saveCachedFacultyProfile:", error.message);
  return null;
}

// ─── Timetable Cache ──────────────────────────────────────────────────────────

export async function getCachedTimetable(email) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("timetable_cache")
    .select("timetable, cached_at")
    .eq("academia_email", email)
    .maybeSingle();
  if (error) { console.error("[supabase] getCachedTimetable:", error.message); return null; }
  return data;
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
  if (error) console.error("[supabase] cacheTimetable:", error.message);
  return null;
}

// ─── Marks Cache ──────────────────────────────────────────────────────────────

export async function getCachedMarks(email) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("marks_cache")
    .select("marks, cached_at")
    .eq("academia_email", email)
    .maybeSingle();
  if (error) { console.error("[supabase] getCachedMarks:", error.message); return null; }
  return data;
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
  if (error) console.error("[supabase] cacheMarks:", error.message);
  return null;
}

// ─── Calendar Cache ───────────────────────────────────────────────────────────

export async function getCachedCalendar(email, sem) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("calendar_cache")
    .select("calendar, cached_at")
    .eq("academia_email", email)
    .eq("sem", sem)
    .maybeSingle();
  if (error) { console.error("[supabase] getCachedCalendar:", error.message); return null; }
  return data;
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
  if (error) console.error("[supabase] cacheCalendar:", error.message);
  return null;
}
