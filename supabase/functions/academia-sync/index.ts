/**
 * academia-sync Edge Function
 *
 * Port of Go loginprobe `login_and_fetch` flow.
 * Triggered by cron or manual invocation.
 *
 * Auth guard: service-role bearer + X-Cron-Secret header.
 *
 * Flow:
 * 1. Read academia_credentials where auto_login_enabled, chunked by offset/limit.
 * 2. Per user: decrypt password → login → prime portal → fetch sections
 *    (studentInfo, attendance, marks, timetable, calendars) → parse → write DB caches.
 * 3. Update scraper_status + per-user sync_errors.
 * 4. On invalid_credentials: disable auto_login_enabled + notify user.
 * 5. After each chunk, self-invoke next offset (fire-and-forget).
 */

import {
  AcademiaLoginSession,
} from "../_shared/academia-login.ts";
import {
  parseAttendance,
  mapAttendanceRows,
  parseStudentInfoHTML,
  parseMarksHTML,
  parsePersonalTimetableHTML,
  parseBatchSlotMapHTML,
  mergeTimetableCourses,
  parseAcademicCalendarHTML,
  extractStudentPhotoSource,
  extractStudentPhotoDownloadURL,
  looksLikeUnauthenticatedPage,
  extractHTMLTitle,
  type FetchData,
  type AttendanceRecord,
  type TimetableResult,
  type CalendarResult,
  type ScheduleEntry,
  type Advisor,
} from "../_shared/academia-parsers.ts";
import { decryptPassword } from "../_shared/crypto.ts";
import { getSupabaseClient } from "../_shared/supabase.ts";
import { buildAttendanceSnapshot } from "../_shared/schedule.ts";

// ─── Constants ───────────────────────────────────────────────────────────────

const BASE_URL = "https://academia.srmist.edu.in";
const ATTENDANCE_URL =
  BASE_URL + "/srm_university/academia-academic-services/page/My_Time_Table_2023_24";
const PERSONAL_TT_URL = ATTENDANCE_URL;
const UNIFIED_TT_B1 =
  BASE_URL + "/srm_university/academia-academic-services/page/Unified_Time_Table_2025_Batch_1";
const UNIFIED_TT_B2 =
  BASE_URL + "/srm_university/academia-academic-services/page/Unified_Time_Table_2025_batch_2";

const CLASS_INVALID_CREDS = "invalid_credentials";

const CHUNK_SIZE = 10;
const PER_USER_BUDGET_MS = 25_000;

// ─── Auth guard ──────────────────────────────────────────────────────────────

function checkAuth(req: Request): { ok: boolean; status: number; body: unknown } {
  const authHeader = req.headers.get("authorization") ?? "";
  const cronSecret = req.headers.get("x-cron-secret") ?? "";
  const expectedSecret = Deno.env.get("CRON_SECRET") ?? "";

  if (!expectedSecret) {
    return {
      ok: false,
      status: 500,
      body: { error: "CRON_SECRET env var not set" },
    };
  }

  if (cronSecret !== expectedSecret) {
    return { ok: false, status: 401, body: { error: "invalid cron secret" } };
  }

  if (!authHeader.startsWith("Bearer ")) {
    return { ok: false, status: 401, body: { error: "missing bearer token" } };
  }

  return { ok: true, status: 200, body: null };
}

// ─── Section fetchers ────────────────────────────────────────────────────────

async function fetchAttendanceBundle(
  session: AcademiaLoginSession,
): Promise<{
  studentInfo: Record<string, string>;
  attendance: AttendanceRecord[];
  marks: FetchData["marks"];
  errors: string[];
}> {
  const errors: string[] = [];
  const serviceUrl = session.getServiceUrl();

  let { html, debug } = await session.fetchDecodedFragment(
    "attendance",
    ATTENDANCE_URL,
    serviceUrl + "/#Page:My_Time_Table_2023_24",
  );

  // Retry on 403 with portal home as referer
  if (debug.statusCode === 403) {
    await sleep(500);
    const retry = await session.fetchDecodedFragment(
      "attendance_retry",
      ATTENDANCE_URL,
      serviceUrl + "/",
    );
    html = retry.html;
    debug = retry.debug;
  }

  // Parse attendance
  let attendance: AttendanceRecord[] = [];
  try {
    const { records } = parseAttendance(html);
    attendance = mapAttendanceRows(records);
  } catch (err) {
    errors.push(`attendance: ${(err as Error).message}`);
  }

  // Parse student info
  let studentInfo: Record<string, string> = {};
  try {
    studentInfo = parseStudentInfoHTML(html);
    if (Object.keys(studentInfo).length > 0) {
      // Try to extract photo
      let photoCandidate = extractStudentPhotoDownloadURL(html);
      if (!photoCandidate) photoCandidate = extractStudentPhotoSource(html);
      if (photoCandidate) {
        try {
          const dataUrl = await session.fetchStudentPhotoDataURL(photoCandidate);
          studentInfo["PhotoUrl"] = dataUrl;
        } catch {
          studentInfo["PhotoUrl"] = photoCandidate;
        }
      }
    }
  } catch (err) {
    errors.push(`studentInfo: ${(err as Error).message}`);
  }

  // Parse marks
  let marks: FetchData["marks"] = [];
  try {
    marks = parseMarksHTML(html);
  } catch (err) {
    errors.push(`marks: ${(err as Error).message}`);
  }

  return { studentInfo, attendance, marks, errors };
}

async function fetchTimetableBundle(
  session: AcademiaLoginSession,
): Promise<{ timetable: TimetableResult | null; errors: string[] }> {
  const errors: string[] = [];
  const serviceUrl = session.getServiceUrl();

  let { html, debug } = await session.fetchDecodedFragment(
    "personal_timetable",
    PERSONAL_TT_URL,
    serviceUrl + "/#Page:My_Time_Table_2023_24",
  );

  // Retry on 404/403
  if (debug.statusCode === 404 || debug.statusCode === 403) {
    await sleep(500);
    const retry = await session.fetchDecodedFragment(
      "personal_timetable_retry",
      PERSONAL_TT_URL,
      serviceUrl + "/",
    );
    html = retry.html;
  }

  let batch = "1";
  let rawCourses: Record<string, string>[] = [];
  let advisors: Advisor[] = [];

  try {
    const result = parsePersonalTimetableHTML(html);
    batch = result.batch;
    rawCourses = result.courses;
    advisors = result.advisors;
  } catch (err) {
    errors.push(`timetable: ${(err as Error).message}`);
    return { timetable: null, errors };
  }

  // Fetch unified timetable based on batch
  const unifiedUrl = batch.trim() === "2" ? UNIFIED_TT_B2 : UNIFIED_TT_B1;
  const unifiedName = batch.trim() === "2"
    ? "unified_timetable_batch_2"
    : "unified_timetable_batch_1";
  const unifiedReferer = batch.trim() === "2"
    ? serviceUrl + "/#Page:Unified_Time_Table_2025_batch_2"
    : serviceUrl + "/#Page:Unified_Time_Table_2025_Batch_1";

  let slotMap: Record<string, ScheduleEntry[]> = {};
  try {
    const unifiedResult = await session.fetchDecodedFragment(
      unifiedName,
      unifiedUrl,
      unifiedReferer,
    );
    slotMap = parseBatchSlotMapHTML(unifiedResult.html);
  } catch (err) {
    errors.push(`unified_timetable: ${(err as Error).message}`);
    // Return with empty schedule if unified fails
  }

  const courses = mergeTimetableCourses(rawCourses, slotMap);
  return {
    timetable: { batch, courses, advisors },
    errors,
  };
}

async function fetchCalendars(
  session: AcademiaLoginSession,
  targetSems: string[],
): Promise<{ calendars: Record<string, CalendarResult>; errors: string[] }> {
  const errors: string[] = [];
  const serviceUrl = session.getServiceUrl();
  const calendars: Record<string, CalendarResult> = {};

  const yearPairs = ["2026_27", "2025_26", "2024_25"];

  for (const sem of targetSems) {
    const semToken = sem.toUpperCase();
    let calendarResult: CalendarResult | null = null;
    let lastErr = "";

    // Try Academic_Reports page first, then legacy per-sem pages
    const candidates = [
      {
        url: BASE_URL + "/srm_university/academia-academic-services/page/Academic_Reports",
        referer: serviceUrl + "/#Academic_Reports",
        name: `calendar_${sem}_Academic_Reports`,
      },
      ...yearPairs.map((year) => {
        const pageName = `Academic_Planner_${year}_${semToken}`;
        return {
          url: BASE_URL + "/srm_university/academia-academic-services/page/" + pageName,
          referer: serviceUrl + "/#Page:" + pageName,
          name: `calendar_${sem}_${pageName}`,
        };
      }),
    ];

    for (const target of candidates) {
      try {
        const { html } = await session.fetchDecodedFragment(
          target.name,
          target.url,
          target.referer,
        );

        if (looksLikeUnauthenticatedPage(target.url, html) ||
            extractHTMLTitle(html).includes("Login")) {
          lastErr = `got login shell for ${target.url}`;
          continue;
        }

        const calendar = parseAcademicCalendarHTML(html, sem);
        calendarResult = calendar;
        break;
      } catch (err) {
        lastErr = (err as Error).message;
        continue;
      }
    }

    if (calendarResult) {
      calendars[sem] = calendarResult;
    } else {
      errors.push(`calendar_${sem}: ${lastErr}`);
    }
  }

  return { calendars, errors };
}

// ─── DB writers ──────────────────────────────────────────────────────────────

async function writeStudentProfile(
  email: string,
  studentInfo: Record<string, string>,
): Promise<void> {
  const supabase = getSupabaseClient();
  const profileData: Record<string, unknown> = {
    academia_email: email,
    name: studentInfo["Name"] ?? null,
    reg_number: studentInfo["Registration Number"] ?? null,
    photo_url: studentInfo["PhotoUrl"] ?? null,
    branch: studentInfo["Branch"] ?? null,
    section: studentInfo["Section"] ?? null,
    semester: studentInfo["Semester"] ?? null,
    phone: studentInfo["Mobile"] ?? null,
    email: studentInfo["Email"] ?? null,
    program: studentInfo["Program"] ?? null,
    campus: studentInfo["Campus"] ?? null,
    raw_data: studentInfo,
    cached_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  await supabase
    .from("student_profiles")
    .upsert(profileData, { onConflict: "academia_email" });
}

async function writeAttendance(
  email: string,
  attendance: AttendanceRecord[],
): Promise<void> {
  const supabase = getSupabaseClient();
  const now = new Date().toISOString();
  const today = new Date().toISOString().slice(0, 10);

  // Write to attendance_current (source='academia')
  const snapshot = buildAttendanceSnapshot(
    attendance as unknown as Array<Record<string, unknown>>,
  );

  await supabase
    .from("attendance_current")
    .upsert({
      academia_email: email,
      source: "academia",
      subjects: attendance,
      overall_pct: snapshot.attendanceAverage,
      fetched_at: now,
    }, { onConflict: "academia_email" });

  // Write daily snapshot to attendance_snapshots (upsert by email+date)
  const { data: existing } = await supabase
    .from("attendance_snapshots")
    .select("id")
    .eq("academia_email", email)
    .eq("snapshot_date", today)
    .limit(1);

  if (existing && existing.length > 0) {
    await supabase
      .from("attendance_snapshots")
      .update({
        overall_percentage: snapshot.attendanceAverage,
        subjects: attendance,
        total_classes: snapshot.attendanceCount,
        created_at: now,
      })
      .eq("id", existing[0].id);
  } else {
    await supabase
      .from("attendance_snapshots")
      .insert({
        academia_email: email,
        snapshot_date: today,
        overall_percentage: snapshot.attendanceAverage,
        subjects: attendance,
        total_classes: snapshot.attendanceCount,
      });
  }
}

async function writeMarks(email: string, marks: unknown[]): Promise<void> {
  const supabase = getSupabaseClient();
  const now = new Date().toISOString();

  await supabase
    .from("marks_cache")
    .upsert({
      academia_email: email,
      marks,
      cached_at: now,
      updated_at: now,
    }, { onConflict: "academia_email" });
}

async function writeTimetable(email: string, timetable: TimetableResult): Promise<void> {
  const supabase = getSupabaseClient();
  const now = new Date().toISOString();

  await supabase
    .from("timetable_cache")
    .upsert({
      academia_email: email,
      timetable,
      cached_at: now,
      updated_at: now,
    }, { onConflict: "academia_email" });
}

async function writeCalendars(
  email: string,
  calendars: Record<string, CalendarResult>,
): Promise<void> {
  const supabase = getSupabaseClient();
  const now = new Date().toISOString();

  for (const [sem, calendar] of Object.entries(calendars)) {
    await supabase
      .from("calendar_cache")
      .upsert({
        academia_email: email,
        sem,
        calendar,
        cached_at: now,
        updated_at: now,
      }, { onConflict: "academia_email,sem" });
  }
}

async function writeFaculty(
  email: string,
  advisors: Advisor[],
): Promise<void> {
  if (!advisors.length) return;
  const supabase = getSupabaseClient();
  const now = new Date().toISOString();

  for (const advisor of advisors) {
    if (!advisor.name) continue;
    const cacheKey = advisor.name.toLowerCase().trim();
    await supabase
      .from("faculty_cache")
      .upsert({
        cache_key: cacheKey,
        profile_data: {
          name: advisor.name,
          role: advisor.role,
          email: advisor.email,
          phone: advisor.phone,
          source_email: email,
        },
        fetched_at: now,
      }, { onConflict: "cache_key" });
  }
}

// ─── Low-attendance notification ─────────────────────────────────────────────

async function checkLowAttendanceNotify(
  email: string,
  attendance: AttendanceRecord[],
): Promise<void> {
  if (!attendance.length) return;
  const supabase = getSupabaseClient();

  const lowSubjects = attendance.filter((r) => {
    const pct = parseFloat(r.attendancePct);
    return Number.isFinite(pct) && pct < 75;
  });

  if (!lowSubjects.length) return;

  // Check if we already sent a notification for these subjects recently (fingerprint dedupe)
  const fingerprint = lowSubjects
    .map((s) => s.courseCode)
    .sort()
    .join(",");

  const { data: recent } = await supabase
    .from("notifications")
    .select("data")
    .eq("academia_email", email)
    .eq("type", "low_attendance")
    .order("created_at", { ascending: false })
    .limit(1);

  if (recent && recent.length > 0) {
    const lastData = recent[0].data as Record<string, unknown>;
    const lastFingerprint = String(lastData?.fingerprint ?? "");
    if (lastFingerprint === fingerprint) return; // Already notified for same subjects
  }

  await supabase.from("notifications").insert({
    academia_email: email,
    type: "low_attendance",
    title: "Low Attendance Alert",
    body: `${lowSubjects.length} subject(s) below 75%: ${lowSubjects.map((s) => s.courseCode).join(", ")}`,
    data: { fingerprint, subjects: lowSubjects },
  });
}

// ─── Per-user sync ───────────────────────────────────────────────────────────

interface UserSyncResult {
  email: string;
  success: boolean;
  error?: string;
  classification?: string;
  sectionsFetched: string[];
}

async function syncUser(
  email: string,
  encryptedPassword: string,
): Promise<UserSyncResult> {
  const supabase = getSupabaseClient();
  const result: UserSyncResult = {
    email,
    success: false,
    sectionsFetched: [],
  };

  const budgetStart = Date.now();

  try {
    // 1. Decrypt password
    const password = await decryptPassword(encryptedPassword);

    // 2. Login
    const session = new AcademiaLoginSession();
    const loginResult = await session.login(email, password);
    result.classification = loginResult.classification;

    if (!loginResult.success) {
      result.error = loginResult.error ?? "login failed";

      // Handle invalid credentials — disable auto_login + notify
      if (loginResult.classification === CLASS_INVALID_CREDS) {
        await supabase
          .from("academia_credentials")
          .update({
            auto_login_enabled: false,
            updated_at: new Date().toISOString(),
          })
          .eq("academia_email", email);

        await supabase.from("notifications").insert({
          academia_email: email,
          type: "auto_login_disabled",
          title: "Auto-Login Disabled",
          body: "Your academia password appears to have changed. Please re-enter your credentials.",
          data: { classification: loginResult.classification },
        });
      }

      // Record sync error
      await supabase.from("sync_errors").insert({
        job_name: "academia",
        academia_email: email,
        error: result.error,
      });

      return result;
    }

    // 3. Prime portal session
    await session.primePortalSession();

    // 4. Fetch all sections sequentially (within budget)
    const sectionsFetched: string[] = [];

    // Attendance bundle (studentInfo + attendance + marks)
    if (Date.now() - budgetStart < PER_USER_BUDGET_MS) {
      try {
        const attResult = await fetchAttendanceBundle(session);
        if (Object.keys(attResult.studentInfo).length > 0) {
          await writeStudentProfile(email, attResult.studentInfo);
          sectionsFetched.push("studentInfo");
        }
        if (attResult.attendance.length > 0) {
          await writeAttendance(email, attResult.attendance);
          await checkLowAttendanceNotify(email, attResult.attendance);
          sectionsFetched.push("attendance");
        }
        if (attResult.marks.length > 0) {
          await writeMarks(email, attResult.marks);
          sectionsFetched.push("marks");
        }
      } catch (err) {
        result.error = `attendance bundle: ${(err as Error).message}`;
      }
    }

    // Timetable bundle
    if (Date.now() - budgetStart < PER_USER_BUDGET_MS) {
      try {
        const ttResult = await fetchTimetableBundle(session);
        if (ttResult.timetable) {
          await writeTimetable(email, ttResult.timetable);
          await writeFaculty(email, ttResult.timetable.advisors);
          sectionsFetched.push("timetable");
        }
      } catch (err) {
        result.error = result.error
          ? `${result.error}; timetable: ${(err as Error).message}`
          : `timetable: ${(err as Error).message}`;
      }
    }

    // Calendars (odd + even)
    if (Date.now() - budgetStart < PER_USER_BUDGET_MS) {
      try {
        const calResult = await fetchCalendars(session, ["odd", "even"]);
        if (Object.keys(calResult.calendars).length > 0) {
          await writeCalendars(email, calResult.calendars);
          sectionsFetched.push("calendar");
        }
      } catch (err) {
        result.error = result.error
          ? `${result.error}; calendar: ${(err as Error).message}`
          : `calendar: ${(err as Error).message}`;
      }
    }

    // 5. Update last_auto_login
    await supabase
      .from("academia_credentials")
      .update({
        last_auto_login: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("academia_email", email);

    result.success = sectionsFetched.length > 0;
    result.sectionsFetched = sectionsFetched;

    // Record partial errors if any
    if (result.error) {
      await supabase.from("sync_errors").insert({
        job_name: "academia",
        academia_email: email,
        error: result.error,
      });
    }

    return result;
  } catch (err) {
    result.error = (err as Error).message;
    await supabase.from("sync_errors").insert({
      job_name: "academia",
      academia_email: email,
      error: result.error,
    });
    return result;
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ─── Main handler ────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const auth = checkAuth(req);
  if (!auth.ok) {
    return new Response(JSON.stringify(auth.body), {
      status: auth.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = getSupabaseClient();

  // Parse offset/limit from request body or query
  let offset = 0;
  let limit = CHUNK_SIZE;

  try {
    const body = await req.json();
    if (typeof body.offset === "number") offset = body.offset;
    if (typeof body.limit === "number") limit = Math.min(body.limit, 20);
  } catch {
    // Use defaults
  }

  // Read credentials chunk
  const { data: credentials, error: credError } = await supabase
    .from("academia_credentials")
    .select("academia_email, encrypted_password, auto_login_enabled")
    .eq("auto_login_enabled", true)
    .order("academia_email")
    .range(offset, offset + limit - 1);

  if (credError) {
    return new Response(
      JSON.stringify({ error: "failed to read credentials", detail: credError.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!credentials || credentials.length === 0) {
    // No more users — update scraper status
    await supabase
      .from("scraper_status")
      .upsert({
        job_name: "academia",
        last_run_at: new Date().toISOString(),
        last_success_at: new Date().toISOString(),
      }, { onConflict: "job_name" });

    return new Response(
      JSON.stringify({ done: true, offset, processed: 0, results: [] }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }

  const results: UserSyncResult[] = [];

  // Process users sequentially within the chunk
  for (const cred of credentials) {
    const userResult = await syncUser(cred.academia_email, cred.encrypted_password);
    results.push(userResult);
  }

  const successCount = results.filter((r) => r.success).length;
  const errorCount = results.length - successCount;

  // Update scraper status
  await supabase
    .from("scraper_status")
    .upsert({
      job_name: "academia",
      last_run_at: new Date().toISOString(),
      last_success_at: successCount > 0 ? new Date().toISOString() : null,
      last_error: errorCount > 0
        ? `${errorCount}/${results.length} users failed`
        : null,
      records_written: successCount,
    }, { onConflict: "job_name" });

  // Fire-and-forget: self-invoke next chunk
  const nextOffset = offset + limit;
  const selfUrl = Deno.env.get("SUPABASE_URL") + "/functions/v1/academia-sync";
  const cronSecret = Deno.env.get("CRON_SECRET");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  try {
    fetch(selfUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${serviceKey}`,
        "X-Cron-Secret": cronSecret ?? "",
      },
      body: JSON.stringify({ offset: nextOffset, limit }),
    }).catch(() => {
      // fire-and-forget — ignore errors
    });
  } catch {
    // ignore
  }

  return new Response(
    JSON.stringify({
      offset,
      processed: results.length,
      successCount,
      errorCount,
      results: results.map((r) => ({
        email: r.email,
        success: r.success,
        sections: r.sectionsFetched,
        error: r.error,
        classification: r.classification,
      })),
      nextOffset,
    }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Connection": "keep-alive",
      },
    },
  );
});
