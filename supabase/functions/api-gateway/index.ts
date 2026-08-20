/**
 * api-gateway Edge Function — all authenticated reads.
 * verify_jwt = false (custom session token check via requireSession).
 *
 * Routes (all require valid session token):
 *   GET  /profile          — student profile from student_profiles
 *   GET  /attendance       — from attendance_current, fallback to latest snapshot
 *   GET  /marks            — from marks_cache
 *   GET  /timetable        — from timetable_cache
 *   GET  /calendar?sem=    — from calendar_cache
 *   GET  /summary          — aggregate + schedule computation
 *   GET  /freshness        — from scraper_status
 *   GET  /jobs             — from haveloc_jobs
 *   GET  /notices          — from haveloc_notices
 *   GET  /applications     — from haveloc_applications
 *   GET  /bookmarks        — from job_bookmarks
 *   POST /bookmarks        — add bookmark
 *   DELETE /bookmarks/:id  — remove bookmark
 *   PATCH /bookmarks/:id   — update bookmark
 *   GET  /notifications    — list notifications
 *   POST /notifications/:id/read — mark notification read
 *   POST /notifications/read-all — mark all read
 *   GET  /settings         — user settings
 *   PUT  /settings         — update user settings
 *   GET  /notification-settings — notification settings
 *   PUT  /notification-settings — update notification settings
 *   GET  /attendance/history?days=30 — attendance snapshots
 *   GET  /faculty?name=    — faculty lookup (delegates to faculty-lookup function)
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import { requireSession } from "../_shared/session.ts";
import {
  buildScheduleFromData,
  getSemType,
  buildAttendanceSnapshot,
} from "../_shared/schedule.ts";

// ─── Helpers ─────────────────────────────────────────────────────────────────

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
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

interface SessionData {
  userId: string;
  email: string;
}

// ─── GET /profile ────────────────────────────────────────────────────────────

async function handleProfile(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  const { data, error } = await supabase
    .from("student_profiles")
    .select("*")
    .eq("academia_email", session.email)
    .maybeSingle();

  if (error) return json({ success: false, error: error.message }, 500);
  if (!data) return json({ success: false, error: "Profile not found" }, 404);

  // Build studentInfo from raw_data, ensuring PhotoUrl is set from photo_url column
  const studentInfo = (data.raw_data as Record<string, string>) || {};
  if (data.photo_url && !studentInfo["PhotoUrl"]) {
    studentInfo["PhotoUrl"] = data.photo_url;
  }

  return json({ success: true, ...data, studentInfo });
}

// ─── GET /attendance ─────────────────────────────────────────────────────────

async function handleAttendance(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  // Try attendance_current first
  const { data: current, error: currentErr } = await supabase
    .from("attendance_current")
    .select("*")
    .eq("academia_email", session.email)
    .maybeSingle();

  if (currentErr) console.error("[api-gateway] attendance_current:", currentErr.message);

  if (current) {
    return json({
      success: true,
      attendance: current.subjects,
      source: current.source,
      fetchedAt: current.fetched_at,
      overallPct: current.overall_pct,
    });
  }

  // Fallback to latest snapshot
  const { data: snapshot, error: snapErr } = await supabase
    .from("attendance_snapshots")
    .select("*")
    .eq("academia_email", session.email)
    .order("snapshot_date", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (snapErr) return json({ success: false, error: snapErr.message }, 500);
  if (!snapshot) return json({ success: false, error: "No attendance data found" }, 404);

  return json({
    success: true,
    attendance: snapshot.subjects,
    source: "snapshot",
    fetchedAt: snapshot.snapshot_date,
    overallPct: snapshot.overall_percentage,
  });
}

// ─── GET /marks ──────────────────────────────────────────────────────────────

async function handleMarks(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  const { data, error } = await supabase
    .from("marks_cache")
    .select("marks, cached_at")
    .eq("academia_email", session.email)
    .maybeSingle();

  if (error) return json({ success: false, error: error.message }, 500);
  if (!data) return json({ success: false, error: "No marks data found" }, 404);
  return json({ success: true, marks: data.marks, cachedAt: data.cached_at });
}

// ─── GET /timetable ──────────────────────────────────────────────────────────

async function handleTimetable(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  const { data, error } = await supabase
    .from("timetable_cache")
    .select("timetable, cached_at")
    .eq("academia_email", session.email)
    .maybeSingle();

  if (error) return json({ success: false, error: error.message }, 500);
  if (!data) return json({ success: false, error: "No timetable data found" }, 404);
  return json({ success: true, timetable: data.timetable, cachedAt: data.cached_at });
}

// ─── GET /calendar?sem= ──────────────────────────────────────────────────────

async function handleCalendar(supabase: ReturnType<typeof createClient>, session: SessionData, sem: string): Promise<Response> {
  const { data, error } = await supabase
    .from("calendar_cache")
    .select("calendar, cached_at")
    .eq("academia_email", session.email)
    .eq("sem", sem)
    .maybeSingle();

  if (error) return json({ success: false, error: error.message }, 500);
  if (!data) return json({ success: false, error: "No calendar data found" }, 404);
  return json({ success: true, calendar: data.calendar, cachedAt: data.cached_at });
}

// ─── GET /summary ────────────────────────────────────────────────────────────

async function handleSummary(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  // Fetch profile, timetable, calendar (both sems), attendance in parallel
  const [profileRes, ttRes, calEvenRes, calOddRes, attRes] = await Promise.all([
    supabase.from("student_profiles").select("*").eq("academia_email", session.email).maybeSingle(),
    supabase.from("timetable_cache").select("timetable, cached_at").eq("academia_email", session.email).maybeSingle(),
    supabase.from("calendar_cache").select("calendar, cached_at").eq("academia_email", session.email).eq("sem", "even").maybeSingle(),
    supabase.from("calendar_cache").select("calendar, cached_at").eq("academia_email", session.email).eq("sem", "odd").maybeSingle(),
    supabase.from("attendance_current").select("*").eq("academia_email", session.email).maybeSingle(),
  ]);

  const profile = profileRes.data;
  if (!profile) return json({ success: false, error: "Profile not found" }, 404);

  const studentInfo = (profile.raw_data as Record<string, unknown>) || {};
  if (profile.photo_url && !studentInfo["PhotoUrl"]) {
    studentInfo["PhotoUrl"] = profile.photo_url;
  }
  const semType = getSemType({ Semester: String(studentInfo.Semester || "1") });
  const calendar = semType === "even" ? calEvenRes.data?.calendar : calOddRes.data?.calendar;
  const timetable = ttRes.data?.timetable;
  const attendance = (attRes.data?.subjects as Array<Record<string, unknown>>) || [];

  let schedule = null;
  try {
    if (timetable && calendar && Object.keys(studentInfo).length) {
      schedule = buildScheduleFromData({ timetable, calendar, studentInfo });
    }
  } catch (err) {
    const error = err as Error;
    console.error("[api-gateway] schedule build error:", error.message);
  }

  const classes = Array.isArray(schedule?.classes) ? schedule!.classes : [];
  const nextClass = classes[0] || null;

  return json({
    success: true,
    email: session.email,
    studentInfo,
    semester: studentInfo.Semester || null,
    semType,
    calendar,
    timetable,
    schedule,
    todayDayOrder: schedule?.todayDayOrder || schedule?.dayOrder || null,
    classCount: classes.length,
    nextClass: nextClass
      ? {
          courseCode: nextClass.courseCode || "",
          courseTitle: nextClass.courseTitle || "",
          timing: nextClass.timing || "",
          hourIndex: nextClass.hourIndex ?? null,
          facultyName: nextClass.facultyName || "",
          roomNo: nextClass.roomNo || "",
        }
      : null,
    ...buildAttendanceSnapshot(attendance),
  });
}

// ─── GET /freshness ──────────────────────────────────────────────────────────

async function handleFreshness(supabase: ReturnType<typeof createClient>): Promise<Response> {
  const { data, error } = await supabase
    .from("scraper_status")
    .select("*")
    .order("job_name");

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, jobs: data || [] });
}

// ─── GET /attendance/history?days=30 ─────────────────────────────────────────

async function handleAttendanceHistory(supabase: ReturnType<typeof createClient>, session: SessionData, days: number): Promise<Response> {
  const since = new Date();
  since.setDate(since.getDate() - days);
  const sinceStr = since.toISOString().slice(0, 10);

  const { data, error } = await supabase
    .from("attendance_snapshots")
    .select("*")
    .eq("academia_email", session.email)
    .gte("snapshot_date", sinceStr)
    .order("snapshot_date", { ascending: true });

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, history: data || [] });
}

// ─── Jobs / Notices / Applications ───────────────────────────────────────────

async function handleJobs(supabase: ReturnType<typeof createClient>): Promise<Response> {
  const { data, error } = await supabase
    .from("haveloc_jobs")
    .select("*")
    .order("last_seen_at", { ascending: false })
    .limit(100);

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, jobs: data || [] });
}

async function handleNotices(supabase: ReturnType<typeof createClient>): Promise<Response> {
  const { data, error } = await supabase
    .from("haveloc_notices")
    .select("*")
    .order("last_seen_at", { ascending: false })
    .limit(100);

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, notices: data || [] });
}

async function handleApplications(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  const { data, error } = await supabase
    .from("haveloc_applications")
    .select("*")
    .eq("academia_email", session.email)
    .order("created_at", { ascending: false });

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, applications: data || [] });
}

// ─── Bookmarks ───────────────────────────────────────────────────────────────

async function handleGetBookmarks(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  const { data, error } = await supabase
    .from("job_bookmarks")
    .select("*")
    .eq("academia_email", session.email)
    .order("bookmarked_at", { ascending: false });

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, bookmarks: data || [] });
}

async function handleAddBookmark(supabase: ReturnType<typeof createClient>, session: SessionData, body: Record<string, unknown>): Promise<Response> {
  const { data, error } = await supabase
    .from("job_bookmarks")
    .upsert({
      academia_email: session.email,
      job_uuid: body.jobUuid,
      job_title: body.jobTitle || null,
      company_name: body.companyName || null,
      job_data: body.jobData || null,
      notes: body.notes || "",
    }, { onConflict: "academia_email,job_uuid" })
    .select()
    .single();

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, ...data });
}

async function handleRemoveBookmark(supabase: ReturnType<typeof createClient>, session: SessionData, jobUuid: string): Promise<Response> {
  const { error } = await supabase
    .from("job_bookmarks")
    .delete()
    .eq("academia_email", session.email)
    .eq("job_uuid", jobUuid);

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true });
}

async function handleUpdateBookmark(supabase: ReturnType<typeof createClient>, session: SessionData, jobUuid: string, updates: Record<string, unknown>): Promise<Response> {
  const { data, error } = await supabase
    .from("job_bookmarks")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("academia_email", session.email)
    .eq("job_uuid", jobUuid)
    .select()
    .single();

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, ...data });
}

// ─── Notifications ───────────────────────────────────────────────────────────

async function handleGetNotifications(supabase: ReturnType<typeof createClient>, session: SessionData, unreadOnly: boolean): Promise<Response> {
  let query = supabase
    .from("notifications")
    .select("*")
    .eq("academia_email", session.email)
    .order("created_at", { ascending: false })
    .limit(50);

  if (unreadOnly) query = query.eq("read", false);

  const { data, error } = await query;
  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, notifications: data || [] });
}

async function handleMarkNotificationRead(supabase: ReturnType<typeof createClient>, id: string): Promise<Response> {
  const { error } = await supabase
    .from("notifications")
    .update({ read: true })
    .eq("id", id);

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true });
}

async function handleMarkAllNotificationsRead(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  const { error } = await supabase
    .from("notifications")
    .update({ read: true })
    .eq("academia_email", session.email)
    .eq("read", false);

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true });
}

// ─── Settings ────────────────────────────────────────────────────────────────

async function handleGetSettings(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  const { data, error } = await supabase
    .from("user_settings")
    .select("*")
    .eq("academia_email", session.email)
    .maybeSingle();

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, settings: data || null });
}

async function handleUpdateSettings(supabase: ReturnType<typeof createClient>, session: SessionData, settings: Record<string, unknown>): Promise<Response> {
  const { data, error } = await supabase
    .from("user_settings")
    .upsert({
      academia_email: session.email,
      ...settings,
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" })
    .select()
    .single();

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, ...data });
}

// ─── Notification Settings ───────────────────────────────────────────────────

async function handleGetNotificationSettings(supabase: ReturnType<typeof createClient>, session: SessionData): Promise<Response> {
  const { data, error } = await supabase
    .from("notification_settings")
    .select("*")
    .eq("academia_email", session.email)
    .maybeSingle();

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, settings: data || null });
}

async function handleUpdateNotificationSettings(supabase: ReturnType<typeof createClient>, session: SessionData, settings: Record<string, unknown>): Promise<Response> {
  const { data, error } = await supabase
    .from("notification_settings")
    .upsert({
      academia_email: session.email,
      ...settings,
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" })
    .select()
    .single();

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, ...data });
}

// ─── Faculty lookup (delegate to faculty-lookup function) ────────────────────

async function handleFaculty(supabase: ReturnType<typeof createClient>, session: SessionData, name: string): Promise<Response> {
  // Try faculty_cache first
  const cacheKey = name.toLowerCase().trim();
  const { data: cached } = await supabase
    .from("faculty_cache")
    .select("profile_data, fetched_at")
    .eq("cache_key", cacheKey)
    .maybeSingle();

  if (cached) {
    const ageMs = Date.now() - new Date(cached.fetched_at).getTime();
    if (ageMs < 24 * 60 * 60 * 1000) {
      return json({ success: true, ...cached.profile_data, cached: true });
    }
  }

  // Delegate to faculty-lookup edge function
  const fnUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/faculty-lookup`;
  const fnKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  try {
    const resp = await fetch(`${fnUrl}?name=${encodeURIComponent(name)}`, {
      headers: {
        Authorization: `Bearer ${fnKey}`,
        "x-session-token": Deno.env.get("SUPABASE_ANON_KEY") || "",
      },
    });

    if (!resp.ok) {
      return json({ success: false, error: "Faculty lookup failed" }, resp.status);
    }

    const result = await resp.json();
    return json(result);
  } catch {
    // faculty-lookup not deployed yet — return cached data if any
    if (cached) {
      return json({ success: true, ...cached.profile_data, cached: true, stale: true });
    }
    return json({ success: false, error: "Faculty lookup unavailable" }, 503);
  }
}

// ─── Router ──────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  // Strip trailing slash and function path prefix to get the route path
  let path = url.pathname.replace(/\/$/, "");
  const fnPrefix = "/functions/v1/api-gateway";
  if (path.startsWith(fnPrefix)) {
    path = path.slice(fnPrefix.length);
  }
  const fnPrefix2 = "/api-gateway";
  if (path.startsWith(fnPrefix2)) {
    path = path.slice(fnPrefix2.length);
  }
  const method = req.method.toUpperCase();

  // CORS preflight
  if (method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, x-session-token",
      },
    });
  }

  // Verify session for all routes
  const session = await requireSession(req);
  if (!session) {
    return json({ success: false, error: "Unauthorized" }, 401);
  }

  const sessionData: SessionData = { userId: session.userId, email: session.email };
  const supabase = getSupabase();

  try {
    // ─── GET routes ──────────────────────────────────────────────────────────
    if (method === "GET") {
      if (path === "/profile" || path === "/" || path === "") {
        return await handleProfile(supabase, sessionData);
      }
      if (path === "/attendance") {
        return await handleAttendance(supabase, sessionData);
      }
      if (path === "/attendance/history") {
        const days = parseInt(url.searchParams.get("days") || "30", 10);
        return await handleAttendanceHistory(supabase, sessionData, days);
      }
      if (path === "/marks") {
        return await handleMarks(supabase, sessionData);
      }
      if (path === "/timetable") {
        return await handleTimetable(supabase, sessionData);
      }
      if (path === "/calendar") {
        const sem = url.searchParams.get("sem") || "even";
        return await handleCalendar(supabase, sessionData, sem);
      }
      if (path === "/summary") {
        return await handleSummary(supabase, sessionData);
      }
      if (path === "/freshness") {
        return await handleFreshness(supabase);
      }
      if (path === "/jobs") {
        return await handleJobs(supabase);
      }
      if (path === "/notices") {
        return await handleNotices(supabase);
      }
      if (path === "/applications") {
        return await handleApplications(supabase, sessionData);
      }
      if (path === "/bookmarks") {
        return await handleGetBookmarks(supabase, sessionData);
      }
      if (path === "/notifications") {
        const unreadOnly = url.searchParams.get("unreadOnly") === "true";
        return await handleGetNotifications(supabase, sessionData, unreadOnly);
      }
      if (path === "/settings") {
        return await handleGetSettings(supabase, sessionData);
      }
      if (path === "/notification-settings") {
        return await handleGetNotificationSettings(supabase, sessionData);
      }
      if (path === "/faculty") {
        const name = url.searchParams.get("name");
        if (!name) return json({ success: false, error: "name query param is required" }, 400);
        return await handleFaculty(supabase, sessionData, name);
      }
    }

    // ─── POST routes ─────────────────────────────────────────────────────────
    if (method === "POST") {
      if (path === "/bookmarks") {
        const body = await req.json();
        if (!body.jobUuid) return json({ success: false, error: "jobUuid is required" }, 400);
        return await handleAddBookmark(supabase, sessionData, body);
      }
      if (path.startsWith("/notifications/") && path.endsWith("/read")) {
        const id = path.split("/")[2];
        return await handleMarkNotificationRead(supabase, id);
      }
      if (path === "/notifications/read-all") {
        return await handleMarkAllNotificationsRead(supabase, sessionData);
      }
    }

    // ─── PUT routes ──────────────────────────────────────────────────────────
    if (method === "PUT") {
      if (path === "/settings") {
        const body = await req.json();
        return await handleUpdateSettings(supabase, sessionData, body);
      }
      if (path === "/notification-settings") {
        const body = await req.json();
        return await handleUpdateNotificationSettings(supabase, sessionData, body);
      }
    }

    // ─── DELETE routes ───────────────────────────────────────────────────────
    if (method === "DELETE") {
      if (path.startsWith("/bookmarks/")) {
        const jobUuid = decodeURIComponent(path.split("/")[2]);
        return await handleRemoveBookmark(supabase, sessionData, jobUuid);
      }
    }

    // ─── PATCH routes ────────────────────────────────────────────────────────
    if (method === "PATCH") {
      if (path.startsWith("/bookmarks/")) {
        const jobUuid = decodeURIComponent(path.split("/")[2]);
        const body = await req.json();
        return await handleUpdateBookmark(supabase, sessionData, jobUuid, body);
      }
    }

    return json({ success: false, error: "Not found" }, 404);
  } catch (err) {
    const error = err as Error;
    console.error("[api-gateway]", error.message);
    return json({ success: false, error: "Internal server error" }, 500);
  }
});
