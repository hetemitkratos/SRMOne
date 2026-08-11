/**
 * server.js — SRM Academia API Server (Go-only backend)
 *
 * Architecture:
 *   - Uses the Go scraper binary exclusively for all SRM portal interactions
 *   - Sessions stored in-memory: sessions[email] = { cookies, cache, meta, … }
 *   - Sessions expire after 30 minutes of inactivity (auto-destroyed)
 *   - ALL scraped data is cached server-side → repeat requests are instant
 *   - NO password storage, NO auto re-login
 *
 * Endpoints:
 *   POST /login                  → login via Go scraper, create session
 *   GET  /init?email=            → fetch student + timetable + calendar in parallel
 *   GET  /attendance?email=      → fetch attendance
 *   GET  /marks?email=           → fetch marks
 *   GET  /timetable?email=       → fetch timetable (+ advisors)
 *   GET  /student?email=         → fetch student info
 *   GET  /calendar?email=&sem=   → fetch academic calendar
 *   GET  /summary?email=         → dashboard-ready Academia snapshot
 *   GET  /schedule?email=        → schedule (computed from timetable + calendar cache)
 *   GET  /all?email=             → fetch everything at once
 *   GET  /student-photo?email=   → proxy student profile photo (Zoho previewengine)
 *   GET  /faculty-photo?url=     → proxy SRM faculty photo (hotlink bypass)
 *   GET  /faculty?name=          → faculty info via Go faculty scraper
 *   POST /logout                 → destroy session
 *   GET  /status                 → server health + active sessions
 */

import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import { runAcademiaScraper, getAcademiaScraperRuntime } from "../integrations/go/go_scraper_client.js";
import { buildScheduleFromData } from "../utils/schedule_utils.js";
import * as supabaseClient from "../utils/supabaseClient.js";

// ─── Config ───────────────────────────────────────────────────────────────────

const PORT = process.env.PORT || 3000;
const SESSION_TTL_MS = 30 * 60 * 1000;      // 30 minutes inactivity timeout
const CLEANUP_INTERVAL_MS = 5 * 60 * 1000;  // check every 5 minutes
const MAX_USERS = 8;
const GO_CLASS_AUTHENTICATED = "authenticated_session_established";

function parseOriginEnv(value) {
  return (value || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

// Allowed CORS origins — set ALLOWED_ORIGINS in production (comma-separated).
const ALLOWED_ORIGINS = Array.from(new Set([
  "http://localhost:5173",
  "http://localhost:4173",
  "https://srm-academia-dashboard.vercel.app",
  "https://srm-academia-dashboard-s9ky.vercel.app",
  ...parseOriginEnv(process.env.ALLOWED_ORIGIN),
  ...parseOriginEnv(process.env.ALLOWED_ORIGINS),
]));

// ─── State ────────────────────────────────────────────────────────────────────

/**
 * In-memory session store.
 * sessions[email] = { cookies, lastActive, cache, meta }
 * Passwords are NEVER stored.
 */
const sessions = {};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function log(tag, msg) {
  console.log(`[${new Date().toISOString()}] [${tag}] ${msg}`);
}

function hasOwn(obj, key) {
  return Object.prototype.hasOwnProperty.call(obj, key);
}

function normalizeMarksRecords(records) {
  if (!Array.isArray(records)) return [];
  return records.map((record) => ({
    ...record,
    tests: Array.isArray(record?.tests) ? record.tests : [],
  }));
}

function isStudentPhotoProxyUrl(photoUrl) {
  const lowerUrl = String(photoUrl || "").toLowerCase();
  return (
    lowerUrl.includes("previewengine") ||
    lowerUrl.includes("creatorexport.zoho.com") ||
    (lowerUrl.includes("zoho.com") && lowerUrl.includes("/image/")) ||
    (lowerUrl.includes("academia.srmist.edu.in") && lowerUrl.includes("download-file?filepath="))
  );
}

function normalizeGoSections(sections = []) {
  const valid = new Set(["studentInfo", "attendance", "marks", "timetable"]);
  return [...new Set(
    sections
      .map((section) => String(section || "").trim())
      .filter((section) => valid.has(section))
  )];
}

function normalizeCalendarSems(sems = []) {
  return [...new Set(
    sems
      .map((sem) => String(sem || "").trim().toLowerCase())
      .filter((sem) => sem === "odd" || sem === "even")
  )];
}

function hasCachedSection(session, section) {
  if (!session?.cache) return false;
  // Sections marked as unavailable (e.g. attendance 403) should not be re-fetched
  if (session.meta?.sectionsUnavailable?.[section]) return true;
  switch (section) {
    case "studentInfo": return hasOwn(session.cache, "studentInfo");
    case "attendance": return hasOwn(session.cache, "attendance");
    case "marks": return hasOwn(session.cache, "marks");
    case "timetable": return hasOwn(session.cache, "timetable");
    default: return false;
  }
}

function markSectionUnavailable(session, section, reason = "") {
  if (!session?.cache) return;
  session.meta = {
    ...(session.meta || {}),
    sectionsUnavailable: {
      ...(session.meta?.sectionsUnavailable || {}),
      [section]: reason || true,
    },
  };
}

function hasCachedCalendar(session, sem) {
  if (!session?.cache || !hasOwn(session.cache, `calendar_${sem}`)) return false;
  // null sentinel means we already tried and the portal page was unavailable
  return session.cache[`calendar_${sem}`] !== undefined;
}

function markCalendarUnavailable(session, sem, reason = "") {
  if (!session?.cache) return;
  if (!hasOwn(session.cache, `calendar_${sem}`)) {
    session.cache[`calendar_${sem}`] = null;
  }
  session.meta = {
    ...(session.meta || {}),
    calendarUnavailable: {
      ...(session.meta?.calendarUnavailable || {}),
      [sem]: reason || true,
    },
  };
}

function mergeGoDataIntoCache(session, data = {}) {
  if (!session?.cache || !data) return;

  if (data.studentInfo && Object.keys(data.studentInfo).length) {
    session.cache.studentInfo = {
      ...(session.cache.studentInfo || {}),
      ...data.studentInfo,
    };
    if (session.cache.studentInfo.PhotoUrl) {
      session.cache.photo = session.cache.studentInfo.PhotoUrl;
    }
  }

  if (Array.isArray(data.attendance) && data.attendance.length) {
    session.cache.attendance = data.attendance;
  }

  if (Array.isArray(data.marks) && data.marks.length) {
    session.cache.marks = normalizeMarksRecords(data.marks);
    // Persist to Supabase
    supabaseClient.cacheMarks(session.meta?.email, session.cache.marks).catch(() => {});
  }

  if (data.timetable && Array.isArray(data.timetable.courses)) {
    session.cache.timetable = data.timetable;
    // Persist to Supabase
    supabaseClient.cacheTimetable(session.meta?.email, data.timetable).catch(() => {});
  }

  if (data.calendars && typeof data.calendars === "object") {
    for (const [sem, calendar] of Object.entries(data.calendars)) {
      if (calendar && Array.isArray(calendar.months)) {
        session.cache[`calendar_${sem}`] = calendar;
        // Persist to Supabase
        supabaseClient.cacheCalendar(session.meta?.email, sem, calendar).catch(() => {});
      }
    }
  }

  if (data.errors && typeof data.errors === "object" && Object.keys(data.errors).length) {
    session.meta = {
      ...(session.meta || {}),
      lastErrors: data.errors,
    };
  }
}

function needsGoStudentPhotoRefresh(session) {
  return (
    session?.backend === "go" &&
    !!session.cache?.studentInfo &&
    !session.cache.studentInfo.PhotoUrl &&
    !session.cache.photo
  );
}

async function refreshGoStudentInfo(email) {
  const session = sessions[email];
  if (!session) throw Object.assign(new Error("No session"), { expired: true });
  if (session.backend !== "go") return session.cache?.studentInfo || null;

  const existingStudentInfo = session.cache?.studentInfo
    ? { ...session.cache.studentInfo }
    : null;

  delete session.cache.studentInfo;
  try {
    await hydrateGoSession(email, { sections: ["studentInfo"] });
  } catch (error) {
    if (existingStudentInfo) {
      session.cache.studentInfo = existingStudentInfo;
    }
    throw error;
  }

  return session.cache?.studentInfo || existingStudentInfo;
}

function needsStudentPhotoFallback(session) {
  const photoUrl = session?.cache?.studentInfo?.PhotoUrl || session?.cache?.photo || "";
  const lowerUrl = String(photoUrl || "").toLowerCase();
  return (
    session?.backend === "go" &&
    (!photoUrl || lowerUrl.includes("creatorexport.zoho.com"))
  );
}

function cookieHeader(session) {
  const cookies = session?.cookies || [];
  return cookies.map((c) => `${c.name}=${c.value}`).join("; ");
}


/**
 * Fetches the student photo via plain HTTP using the stored session cookies.
 * Mirrors what the Go scraper does, but in Node.js so it can run anytime:
 *   1. GET the Student_Profile_Report page with session cookies
 *   2. Parse the Your_Photo <img src> from the embedded JSON blob
 *   3. Download the image bytes → cache as a data: URI
 */
async function ensureUsableStudentPhoto(email) {
  const session = sessions[email];
  if (!session) throw Object.assign(new Error("No session"), { expired: true });

  if (!needsStudentPhotoFallback(session)) {
    return session.cache?.studentInfo?.PhotoUrl || session.cache?.photo || null;
  }

  if (session.photoRecoveryPromise) {
    return session.photoRecoveryPromise;
  }

  session.photoRecoveryPromise = (async () => {
    try {
      const cookies = cookieHeader(session);
      const headers = {
        "Cookie": cookies,
        "Referer": "https://academia.srmist.edu.in/#Report:Student_Profile_Report",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      };

      // ── Step 1: fetch the profile report page ────────────────────────────
      const profileURL = "https://academia.srmist.edu.in/srm_university/academia-academic-services/report/Student_Profile_Report";
      log("PHOTO", `HTTP fetch profile report for ${email}`);
      const pageRes = await fetch(profileURL, { headers });
      if (!pageRes.ok) {
        log("PHOTO", `Profile report returned ${pageRes.status} for ${email}`);
        return null;
      }
      const html = await pageRes.text();

      // ── Step 2: extract photo URL from the embedded JSON blob ──────────────
      // The page embeds: {"HTML":... "MODEL":{"DATAJSONARRAY":[{"Your_Photo":"<a ...><img downqual=\"/...\" src=\"/...\" />"}]}}
      // Zoho Creator uses lazy-loading: the real URL is in downqual/medqual/lowqual attrs, not src.
      let photoSrc = "";

      function extractPhotoUrl(rawHtml) {
        // Decode HTML entities so &amp; becomes & before URL matching
        const decoded = rawHtml.replace(/&amp;/g, "&").replace(/&#x26;/g, "&");

        // Priority 1: lowqual/medqual/downqual/src with Your_Photo + filepath
        for (const attr of ["lowqual", "medqual", "downqual", "src"]) {
          const m = decoded.match(new RegExp(attr + '=["\']([^"\']+Your_Photo[^"\']+filepath[^"\']+)', "i"));
          if (m && m[1]) return m[1];
        }
        // Priority 2: download-file?filepath= path
        const df = decoded.match(/\/[^\s"']*\/Your_Photo\/download-file\?[^\s"'<>]+/);
        if (df) return df[0];
        // Priority 3: Zoho /image/ path
        const img = decoded.match(/\/[^\s"']*\/Your_Photo\/image\/[^\s"'<>]+/);
        if (img) return img[0];
        return "";
      }

      // Try structured JSON parse first
      const jsonStart = html.indexOf('{"HTML":');
      if (jsonStart >= 0) {
        try {
          const obj = JSON.parse(html.slice(jsonStart));
          const photoHtml = obj?.MODEL?.DATAJSONARRAY?.[0]?.["Your_Photo"] || "";
          if (photoHtml) {
            log("PHOTO", `Your_Photo HTML (first 500): ${photoHtml.slice(0, 500)}`);
            photoSrc = extractPhotoUrl(photoHtml);
          }
        } catch (e) {
          log("PHOTO", `JSON parse failed: ${e.message}`);
        }
      }

      // Fallback: substring search in raw HTML
      if (!photoSrc) {
        const marker = '"Your_Photo":"';
        const idx = html.indexOf(marker);
        if (idx >= 0) {
          const end = html.indexOf('"}', idx + marker.length);
          if (end >= 0) {
            const raw = html.slice(idx + marker.length, end).replace(/\\"/g, '"').replace(/\\\//g, '/');
            log("PHOTO", `Your_Photo fallback HTML (first 500): ${raw.slice(0, 500)}`);
            photoSrc = extractPhotoUrl(raw);
          }
        }
      }

      if (!photoSrc) {
        log("PHOTO", `Could not extract photo URL from profile report for ${email}`);
        return null;
      }

      // Resolve relative URLs
      if (photoSrc.startsWith("/")) {
        photoSrc = "https://academia.srmist.edu.in" + photoSrc;
      }

      log("PHOTO", `HTTP photo candidate for ${email}: ${photoSrc.slice(0, 120)}`);

      // ── Step 3: download the image bytes ─────────────────────────────────
      const imgRes = await fetch(photoSrc, {
        headers: {
          "Cookie": cookies,
          "Referer": "https://academia.srmist.edu.in/#Report:Student_Profile_Report",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
          "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        },
      });

      if (!imgRes.ok) {
        log("PHOTO", `Photo download returned ${imgRes.status} for ${email} (${photoSrc.slice(0, 80)})`);
        return null;
      }

      let contentType = imgRes.headers.get("content-type") || "";
      if (!contentType.startsWith("image/") || contentType.includes("octet-stream")) {
        // Guess from extension
        const lower = photoSrc.toLowerCase();
        contentType = lower.includes(".png") ? "image/png"
          : lower.includes(".webp") ? "image/webp"
            : "image/jpeg";
      }

      const buf = await imgRes.arrayBuffer();
      if (!buf.byteLength) {
        log("PHOTO", `Photo download returned empty body for ${email}`);
        return null;
      }

      const dataUri = `data:${contentType};base64,${Buffer.from(buf).toString("base64")}`;
      log("PHOTO", `HTTP photo OK for ${email} (${buf.byteLength} bytes, ${contentType})`);

      session.cache.photo = dataUri;
      if (session.cache.studentInfo) {
        session.cache.studentInfo.PhotoUrl = dataUri;
      }
      return dataUri;
    } catch (err) {
      log("PHOTO", `HTTP photo fetch error for ${email}: ${err.message}`);
      return null;
    } finally {
      delete session.photoRecoveryPromise;
    }
  })();

  return session.photoRecoveryPromise;
}

function goErrorLooksAuthFailure(text) {
  const t = String(text || "").toLowerCase();
  if (!t) return false;
  return (
    t.includes("session expired") ||
    t.includes("jsessionid missing") ||
    t.includes("jsessionid not established") ||
    t.includes("redirected to sign-in") ||
    t.includes("unauthorized") ||
    t.includes("not authenticated")
  );
}

function goResultLooksExpired(result) {
  if (!result) return false;
  if (result.classification === GO_CLASS_AUTHENTICATED && result.success) return false;

  // Explicit expiry from portal prime / auth checks (preferred signal).
  if (goErrorLooksAuthFailure(result.error)) return true;
  const sectionErrors = result.data?.errors || {};
  for (const msg of Object.values(sectionErrors)) {
    if (goErrorLooksAuthFailure(msg)) return true;
  }

  const urls = [
    result.finalUrl,
    ...(result.redirectSummary || []).flatMap((step) => [step.url, step.location]),
  ]
    .filter(Boolean)
    .map((value) => String(value).toLowerCase());

  // Hard bounce to Zoho accounts / sign-in (ignore bare "signin" in query noise).
  if (urls.some((value) =>
    value.includes("/accounts/") ||
    value.includes("sessions-reminder") ||
    /\/signin(?:\?|\/|$)/.test(value)
  )) {
    return true;
  }

  // Fragment 401/403 alone is NOT expiry — cold fetch-without-prime used to 403
  // right after a valid login and wrongly killed the session. Only expire if the
  // cookie jar no longer has JSESSIONID.
  const err = String(result.error || "").toLowerCase();
  if (/\b(401|403)\b/.test(err) || err.includes("forbidden")) {
    const names = Array.isArray(result.cookieNames)
      ? result.cookieNames.map(String)
      : [];
    if (!names.includes("JSESSIONID")) return true;
  }

  return false;
}

function requestedGoDataMissing(session, sections = [], calendarSems = []) {
  const missing = [];
  for (const section of normalizeGoSections(sections)) {
    if (!hasCachedSection(session, section)) missing.push(section);
  }
  for (const sem of normalizeCalendarSems(calendarSems)) {
    if (!hasCachedCalendar(session, sem)) missing.push(`calendar_${sem}`);
  }
  return missing;
}

function numericValue(value) {
  const parsed = typeof value === "number" ? value : parseFloat(String(value ?? "0"));
  return Number.isFinite(parsed) ? parsed : 0;
}

function getSemType(studentInfo = {}) {
  const semNum = parseInt(studentInfo?.Semester || "1", 10);
  return semNum % 2 === 0 ? "even" : "odd";
}

function buildAttendanceSnapshot(attendance = []) {
  if (!Array.isArray(attendance) || attendance.length === 0) {
    return {
      attendanceAverage: null,
      lowAttendanceCount: 0,
      attendanceCount: 0,
    };
  }

  const percentages = attendance.map((record) => numericValue(record?.attendancePct));
  const average = Math.round(percentages.reduce((sum, value) => sum + value, 0) / percentages.length);
  return {
    attendanceAverage: average,
    lowAttendanceCount: percentages.filter((value) => value < 75).length,
    attendanceCount: attendance.length,
  };
}

function buildAcademiaSummary(email, session) {
  const studentInfo = session.cache?.studentInfo || {};
  const semester = studentInfo.Semester || null;
  const semType = getSemType(studentInfo);
  const calendar = session.cache?.[`calendar_${semType}`] || null;
  const timetable = session.cache?.timetable || null;
  const attendance = session.cache?.attendance || [];

  let schedule = null;
  try {
    if (timetable && calendar && Object.keys(studentInfo).length) {
      schedule = buildScheduleFromData({ timetable, calendar, studentInfo });
    }
  } catch (err) {
    session.meta = {
      ...(session.meta || {}),
      lastSummaryScheduleError: err.message,
    };
  }

  const classes = Array.isArray(schedule?.classes) ? schedule.classes : [];
  const nextClass = classes[0] || null;

  return {
    email,
    studentInfo,
    semester,
    semType,
    calendar,
    timetable,
    schedule,
    todayDayOrder: schedule?.todayDayOrder || schedule?.dayOrder || null,
    classCount: classes.length,
    nextClass: nextClass ? {
      courseCode: nextClass.courseCode || "",
      courseTitle: nextClass.courseTitle || "",
      timing: nextClass.timing || "",
      hourIndex: nextClass.hourIndex ?? null,
      facultyName: nextClass.facultyName || "",
      roomNo: nextClass.roomNo || "",
    } : null,
    ...buildAttendanceSnapshot(attendance),
  };
}

async function runGoPayload(email, payload, tag) {
  const startedAt = Date.now();
  const { parsed, stderr, runtime, exitCode } = await runAcademiaScraper(payload);
  const elapsedMs = Date.now() - startedAt;

  if (stderr?.trim()) {
    log("GO", `${tag} stderr for ${email} (${runtime}): ${stderr.trim()}`);
  }

  if (!parsed) {
    throw new Error("academia scraper returned no JSON payload");
  }

  log(
    "GO",
    `${tag} ${email} runtime=${runtime} exit=${exitCode} success=${parsed.success} classification=${parsed.classification || "unknown"} duration=${elapsedMs}ms${
      parsed.error ? ` error=${parsed.error}` : ""
    }`
  );

  return { parsed, runtime, exitCode };
}

async function hydrateGoSession(email, { sections = [], calendarSems = [] } = {}) {
  const requestedSections = normalizeGoSections(sections);
  const requestedCalendarSems = normalizeCalendarSems(calendarSems);

  while (true) {
    const session = sessions[email];
    if (!session) throw Object.assign(new Error("No session"), { expired: true });

    touch(email);

    const missingSections = requestedSections.filter((s) => !hasCachedSection(session, s));
    const missingCalendarSems = requestedCalendarSems.filter((sem) => !hasCachedCalendar(session, sem));

    if (!missingSections.length && !missingCalendarSems.length) {
      return session.cache;
    }

    if (session.goFetchPromise) {
      try {
        await session.goFetchPromise;
      } catch (err) {
        const afterWaitSession = sessions[email];
        if (!afterWaitSession) throw Object.assign(new Error("Session expired. Please login again."), { expired: true });
        const stillMissing = requestedGoDataMissing(afterWaitSession, requestedSections, requestedCalendarSems);
        if (!stillMissing.length) return afterWaitSession.cache;
        throw err;
      }
      continue;
    }

    const fetchSections = missingSections;
    const fetchCalendarSems = missingCalendarSems;
    const fetchPromise = (async () => {
      const activeSession = sessions[email];
      if (!activeSession) throw Object.assign(new Error("No session"), { expired: true });

      const { parsed } = await runGoPayload(email, {
        mode: "fetch",
        email,
        cookies: activeSession.cookies || [],
        sections: fetchSections,
        calendarSems: fetchCalendarSems,
      }, `fetch sections=${fetchSections.join(",") || "-"} sems=${fetchCalendarSems.join(",") || "-"}`);

      const currentSession = sessions[email];
      if (!currentSession) throw Object.assign(new Error("No session"), { expired: true });

      if (Array.isArray(parsed.cookies) && parsed.cookies.length) {
        currentSession.cookies = parsed.cookies;
      }
      mergeGoDataIntoCache(currentSession, parsed.data);
      currentSession.meta = {
        ...(currentSession.meta || {}),
        classification: parsed.classification,
        lastFetchAt: Date.now(),
        lastErrors: parsed.data?.errors || null,
      };

      if (parsed.data?.errors && Object.keys(parsed.data.errors).length) {
        log("GO", `section errors for ${email}: ${JSON.stringify(parsed.data.errors)}`);
      }

      if (goResultLooksExpired(parsed)) {
        await destroySession(email, "expired (go session invalid)");
        throw Object.assign(new Error("Session expired. Please login again."), { expired: true });
      }

      const missingAfter = requestedGoDataMissing(currentSession, fetchSections, fetchCalendarSems);
      if (missingAfter.length) {
        const onlyCalendarMissing = missingAfter.every((item) => String(item).startsWith("calendar_"));
        if (onlyCalendarMissing) {
          for (const item of missingAfter) {
            const sem = String(item).replace(/^calendar_/, "");
            markCalendarUnavailable(
              currentSession,
              sem,
              parsed.data?.errors?.[`calendar_${sem}`] || parsed.error || "unavailable"
            );
          }
          log(
            "GO",
            `calendar unavailable for ${email} (continuing without it): ${missingAfter.join(", ")}${
              parsed.data?.errors ? ` details=${JSON.stringify(parsed.data.errors)}` : ""
            }`
          );
          return currentSession.cache;
        }
        // Sections that have recorded errors in parsed.data.errors were attempted
        // but failed (e.g. attendance 403). Treat these as soft failures — the
        // session is still valid, the data just couldn't be fetched this time.
        const sectionErrors = parsed.data?.errors || {};
        const softFailures = missingAfter.filter((item) => sectionErrors[item]);
        const hardFailures = missingAfter.filter((item) => !sectionErrors[item]);
        if (hardFailures.length === 0 && softFailures.length > 0) {
          for (const section of softFailures) {
            markSectionUnavailable(currentSession, section, sectionErrors[section]);
          }
          log(
            "GO",
            `soft section failures for ${email}: ${softFailures.join(", ")}${
              parsed.data?.errors ? ` details=${JSON.stringify(parsed.data.errors)}` : ""
            }`
          );
          return currentSession.cache;
        }
        const errMsg = parsed.error || `Missing data after Go fetch: ${missingAfter.join(", ")}`;
        // Belt-and-suspenders: auth failures that slipped past classification checks
        if (goErrorLooksAuthFailure(errMsg) || goResultLooksExpired(parsed)) {
          await destroySession(email, "expired (auth failure during fetch)");
          throw Object.assign(new Error("Session expired. Please login again."), { expired: true });
        }
        throw new Error(errMsg);
      }

      return currentSession.cache;
    })();

    session.goFetchPromise = fetchPromise;
    try {
      await fetchPromise;
    } finally {
      if (sessions[email]?.goFetchPromise === fetchPromise) {
        delete sessions[email].goFetchPromise;
      }
    }
  }
}

function warmAcademiaSession(email) {
  // Fire after a short delay so /init's fetch starts first (with fewer sections = faster).
  // warmAcademiaSession will join /init's goFetchPromise, then fetch attendance+marks
  // in a second background call.
  setTimeout(async () => {
    try {
      await hydrateGoSession(email, {
        sections: ["studentInfo", "attendance", "marks", "timetable"],
        calendarSems: ["odd", "even"],
      });
      warmTimetableFacultyPhotoUrls(email, "WARM");
      if (sessions[email]?.cache?.timetable) {
        warmFacultyCache(sessions[email].cache.timetable);
      }
      log("WARM", `Session cache warmed for ${email}`);
    } catch (err) {
      log("WARM", `Session warm-up failed for ${email}: ${err.message}`);
    }
  }, 1500);
}

/** Touch session (update lastActive) for a given email. */
function touch(email) {
  if (sessions[email]) sessions[email].lastActive = Date.now();
}

/** Destroy a session and remove it from memory. */
async function destroySession(email, reason = "destroyed") {
  const s = sessions[email];
  if (!s) return;
  log("SESSION", `Session for ${email} ${reason}`);
  delete sessions[email];
}

// ─── Session cleanup (inactivity) ─────────────────────────────────────────────

setInterval(async () => {
  const now = Date.now();
  for (const email of Object.keys(sessions)) {
    if (now - sessions[email].lastActive > SESSION_TTL_MS) {
      await destroySession(email, `expired (inactive > ${SESSION_TTL_MS / 60000}m)`);
    }
  }
}, CLEANUP_INTERVAL_MS);

// ─── Express App ──────────────────────────────────────────────────────────────

const app = express();

// Render (and Cloudflare) sit in front — required for express-rate-limit IP keys.
app.set("trust proxy", 1);

// Security headers
app.use(helmet());

// Health check endpoint (public, for Render/UptimeRobot)
app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "academia-backend", timestamp: Date.now() });
});

// CORS — only allow configured origins
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.includes(origin) || /^https?:\/\/(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.|localhost)/.test(origin)) return cb(null, true);
    return cb(new Error(`CORS: origin not allowed — ${origin}`));
  },
  methods: ["GET", "POST"],
  allowedHeaders: ["Content-Type"],
}));

// Rate limiter — general API (120 req/min per IP)
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  // Express does not consume the RFC7239 Forwarded header; Render may send it.
  validate: { forwardedHeader: false },
  message: { success: false, error: "Too many requests. Please slow down." },
});
app.use(apiLimiter);

// Login rate limiter — max 5 attempts per 15 min per IP
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  validate: { forwardedHeader: false },
  message: { success: false, error: "Too many login attempts. Try again in 15 minutes." },
  skipSuccessfulRequests: true,
});

app.use(express.json({ limit: "10kb" }));

// ── Middleware: JSON error wrapper ─────────────────────────────────────────────
app.use((req, res, next) => {
  res.fail = (status, message, extra = {}) =>
    res.status(status).json({ success: false, error: message, ...extra });
  res.ok = (data) =>
    res.json({ success: true, ...data });
  next();
});

// ─── Routes ───────────────────────────────────────────────────────────────────

/**
 * GET /
 * Lightweight root route for health checks.
 */
app.get("/", (_req, res) => {
  res.ok({
    service: "srm-academia-api",
    backend: "go",
    health: "/status",
  });
});

/**
 * GET /status
 * Server health + active session count.
 */
app.get("/status", (_req, res) => {
  const { command, args, source } = getAcademiaScraperRuntime();
  const active = Object.entries(sessions).map(([email, s]) => ({
    email,
    idleSec: Math.floor((Date.now() - s.lastActive) / 1000),
  }));
  res.ok({
    backend: "go",
    scraperCommand: command,
    scraperArgs: args,
    scraperSource: source,
    activeSessions: active.length,
    sessions: active,
  });
});

/**
 * POST /login
 * Body: { email, password }
 * Logs in via Go scraper and stores the resulting session cookies.
 * Passwords are used only for login and NEVER stored.
 */
app.post("/login", loginLimiter, async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.fail(400, "email and password are required");

  if (!email.toLowerCase().endsWith("@srmist.edu.in"))
    return res.fail(400, "Only @srmist.edu.in email addresses are allowed.");

  if (!sessions[email] && Object.keys(sessions).length >= MAX_USERS) {
    log("LOGIN", `Max users reached — rejected ${email}`);
    return res.fail(503, "Max users reached. Try again later.");
  }

  // Blind reuse traps users when Zoho cookies died but the Node process still
  // holds the session (common on Render). Validate live; re-auth if stale.
  if (sessions[email]) {
    touch(email);
    try {
      const { parsed } = await runGoPayload(email, {
        mode: "fetch",
        email,
        cookies: sessions[email].cookies || [],
        sections: ["studentInfo"],
      }, "session-check");

      if (parsed.success && !goResultLooksExpired(parsed)) {
        if (Array.isArray(parsed.cookies) && parsed.cookies.length) {
          sessions[email].cookies = parsed.cookies;
        }
        mergeGoDataIntoCache(sessions[email], parsed.data);
        log("LOGIN", `Reused existing session for ${email}`);
        warmAcademiaSession(email);
        return res.ok({ message: "Session already active" });
      }

      log(
        "LOGIN",
        `Existing session invalid for ${email}: ${parsed.error || parsed.classification || "check failed"}`
      );
    } catch (err) {
      log("LOGIN", `Existing session check failed for ${email}: ${err.message}`);
    }
    await destroySession(email, "stale session on login — re-authenticating");
  }

  try {
    log("LOGIN", `Authenticating ${email} via Go scraper`);

    // login_and_fetch keeps cookies in-process for the first data pull (avoids
    // cold fetch-only 403 right after login). Soft section failures still succeed.
    const { parsed } = await runGoPayload(email, {
      mode: "login_and_fetch",
      email,
      password,
      sections: ["studentInfo", "attendance", "marks", "timetable"],
      calendarSems: ["odd", "even"],
    }, "login");

    const cookieCount = Array.isArray(parsed.cookies)
      ? parsed.cookies.length
      : (parsed.cookieNames?.length ?? 0);

    const traversedWarnings = (parsed.redirectSummary || []).some((step) =>
      /sessions-reminder|block-sessions|signin-block/.test(
        `${step.url || ""} ${step.location || ""}`.toLowerCase()
      )
    );
    if (traversedWarnings) {
      log("LOGIN", `Handled SRM warning/interstitial flow for ${email}`);
    }

    if (!(parsed.success && parsed.classification === GO_CLASS_AUTHENTICATED && cookieCount > 0)) {
      const status = parsed.classification === "invalid_credentials" ? 401 : 500;
      log("LOGIN", `Go login failed for ${email}: ${parsed.error || parsed.classification || "unknown error"}`);
      return res.fail(status, parsed.error || "Login failed");
    }

    sessions[email] = {
      cookies: parsed.cookies || [],
      lastActive: Date.now(),
      backend: "go",
      cache: {},
      meta: {
        email,
        classification: parsed.classification,
        cookieNames: parsed.cookieNames || [],
        finalUrl: parsed.finalUrl || "",
      },
    };
    mergeGoDataIntoCache(sessions[email], parsed.data);
    if (parsed.error) {
      log("LOGIN", `Login ok with partial fetch for ${email}: ${parsed.error}`);
    }

    log("LOGIN", `Login success for ${email}`);
    warmAcademiaSession(email);

    // Send welcome notification on first login (only if no welcome sent before)
    supabaseClient.hasNotificationOfType(email, "welcome").then((alreadySent) => {
      if (!alreadySent) {
        supabaseClient.createNotification(email, {
          type: "welcome",
          title: "Welcome to SRM One! 🎉",
          body: "You're all set. Track attendance, view timetables, check marks, and browse placements — all in one place.",
          data: { timestamp: new Date().toISOString() },
        }).catch((err) => log("NOTIFICATIONS", `Welcome notif failed for ${email}: ${err.message}`));
      }
    }).catch(() => {});

    return res.ok({ message: "Login successful", cookieCount });
  } catch (err) {
    log("LOGIN", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * POST /logout
 * Body: { email }
 */
app.post("/logout", async (req, res) => {
  const { email } = req.body;
  if (!email) return res.fail(400, "email is required");
  await destroySession(email, "logged out");
  res.ok({ message: "Session destroyed" });
});

/**
 * GET /attendance?email=
 */
app.get("/attendance", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");

  try {
    const s = sessions[email];
    // If attendance was already attempted and marked unavailable (e.g. portal
    // maintenance / 403), return empty immediately instead of re-fetching.
    if (s.meta?.sectionsUnavailable?.attendance) {
      return res.ok({ attendance: [], photosReady: true, unavailable: true });
    }
    if (!hasCachedSection(s, "attendance")) {
      await hydrateGoSession(email, { sections: ["attendance"] });
    }
    // Return immediately with whatever cached photos are available.
    // Photo enrichment happens in the background.
    const attendance = attachAttendanceFacultyPhotos(s);
    setImmediate(() => {
      ensureAttendanceFacultyPhotos(email).catch((err) =>
        log("ATTENDANCE", `Background photo enrichment failed for ${email}: ${err.message}`)
      );
    });
    
    // Auto-snapshot attendance for history tracking
    if (attendance && attendance.length > 0) {
      const overallPct = attendance.reduce((sum, subj) => sum + parseFloat(subj.attendancePct || 0), 0) / attendance.length;
      supabaseClient.saveAttendanceSnapshot(email, attendance, overallPct).catch(err => 
        log("ATTENDANCE", `Snapshot save failed: ${err.message}`)
      );

      // Low attendance alert — notify for subjects below 75% (once per subject)
      const lowAttendanceSubjects = attendance.filter((subj) => {
        const pct = parseFloat(subj.attendancePct || 0);
        return pct < 75;
      });
      if (lowAttendanceSubjects.length > 0) {
        supabaseClient.hasUnreadNotificationOfType(email, "low_attendance").then((hasUnread) => {
          if (!hasUnread) {
            const subjectList = lowAttendanceSubjects
              .map((s) => `${s.courseCode || s.subject || "Subject"}: ${s.attendancePct}%`)
              .join(", ");
            supabaseClient.createNotification(email, {
              type: "low_attendance",
              title: "⚠️ Low Attendance Alert",
              body: `${lowAttendanceSubjects.length} subject${lowAttendanceSubjects.length > 1 ? "s" : ""} below 75%: ${subjectList}. Check the attendance page for details.`,
              data: { subjects: lowAttendanceSubjects.map((s) => ({ courseCode: s.courseCode, pct: s.attendancePct })) },
            }).catch((err) => log("NOTIFICATIONS", `Low attendance notif failed: ${err.message}`));
          }
        }).catch(() => {});
      }
    }
    
    return res.ok({ attendance, photosReady: areFacultyPhotosReady(s) });
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("ATTENDANCE", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /marks?email=
 */
app.get("/marks", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");

  try {
    const s = sessions[email];
    if (s.meta?.sectionsUnavailable?.marks) {
      // Try Supabase cache before returning empty
      const cached = await supabaseClient.getCachedMarks(email).catch(() => null);
      if (cached?.marks) {
        log("MARKS", `Returning cached marks from Supabase for ${email}`);
        return res.ok({ marks: cached.marks, fromCache: true });
      }
      return res.ok({ marks: [], unavailable: true });
    }
    if (hasCachedSection(s, "marks")) {
      s.cache.marks = normalizeMarksRecords(s.cache.marks);
      supabaseClient.cacheMarks(email, s.cache.marks).catch(() => {});
      return res.ok({ marks: s.cache.marks });
    }

    await hydrateGoSession(email, { sections: ["marks"] });
    s.cache.marks = normalizeMarksRecords(s.cache.marks);
    if (s.cache.marks) {
      supabaseClient.cacheMarks(email, s.cache.marks).catch(() => {});
    }
    return res.ok({ marks: s.cache.marks });
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("MARKS", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /timetable?email=
 * Also returns advisors (Faculty Advisor, Academic Advisor).
 */
app.get("/timetable", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");

  try {
    const s = sessions[email];
    if (!hasCachedSection(s, "timetable")) {
      await hydrateGoSession(email, { sections: ["timetable"] });
    }
    if (s.cache.timetable) {
      // Persist to Supabase
      supabaseClient.cacheTimetable(email, s.cache.timetable).catch(() => {});
      setImmediate(() => warmTimetableFacultyPhotoUrls(email, "TIMETABLE"));
      return res.ok({ timetable: s.cache.timetable, photosReady: areFacultyPhotosReady(s) });
    }
    // Fallback: try Supabase cached timetable
    const cached = await supabaseClient.getCachedTimetable(email).catch(() => null);
    if (cached?.timetable) {
      log("TIMETABLE", `Returning cached timetable from Supabase for ${email}`);
      return res.ok({ timetable: cached.timetable, photosReady: false, fromCache: true });
    }
    return res.ok({ timetable: null, photosReady: false });
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("TIMETABLE", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /student?email=
 */
app.get("/student", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");

  try {
    const s = sessions[email];

    // If studentInfo was marked unavailable (e.g. attendance 403), skip to fallback
    if (!s.meta?.sectionsUnavailable?.studentInfo && hasCachedSection(s, "studentInfo")) {
      if (needsGoStudentPhotoRefresh(s)) {
        try {
          await refreshGoStudentInfo(email);
        } catch (refreshErr) {
          log("PHOTO", `student info refresh failed for ${email}: ${refreshErr.message}`);
        }
      }
      if (needsStudentPhotoFallback(s)) {
        try {
          await ensureUsableStudentPhoto(email);
        } catch (photoErr) {
          log("PHOTO", `student photo fallback failed for ${email}: ${photoErr.message}`);
        }
      }
      if (s.cache.studentInfo && !s.cache.studentInfo.PhotoUrl && s.cache.photo) {
        s.cache.studentInfo.PhotoUrl = s.cache.photo;
      }
      if (s.cache.studentInfo) {
        supabaseClient.cacheStudentProfile(email, s.cache.studentInfo).catch(err => 
          log("PROFILE", `Cache save failed: ${err.message}`)
        );
        return res.ok({ studentInfo: s.cache.studentInfo });
      }
    }

    // If not yet attempted and not marked unavailable, try fetching
    if (!s.meta?.sectionsUnavailable?.studentInfo) {
      await hydrateGoSession(email, { sections: ["studentInfo"] });
      if (s.cache.studentInfo) {
        if (needsStudentPhotoFallback(s)) {
          try {
            await ensureUsableStudentPhoto(email);
          } catch (photoErr) {
            log("PHOTO", `student photo fallback failed for ${email}: ${photoErr.message}`);
          }
        }
        if (!s.cache.studentInfo.PhotoUrl && s.cache.photo) {
          s.cache.studentInfo.PhotoUrl = s.cache.photo;
        }
        supabaseClient.cacheStudentProfile(email, s.cache.studentInfo).catch(err => 
          log("PROFILE", `Cache save failed: ${err.message}`)
        );
        return res.ok({ studentInfo: s.cache.studentInfo });
      }
    }
    // Fallback: studentInfo unavailable from Go scraper (e.g. attendance 403).
    // Try Supabase cached profile so the frontend doesn't break.
    const cached = await supabaseClient.getCachedProfile(email).catch(() => null);
    if (cached?.raw_data) {
      log("STUDENT", `Returning cached profile for ${email} (Go scraper could not fetch)`);
      return res.ok({ studentInfo: cached.raw_data });
    }
    return res.fail(500, "Could not fetch student info. The SRM portal may be temporarily unavailable.");
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("STUDENT", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /calendar?email=&sem=odd|even
 */
app.get("/calendar", async (req, res) => {
  const { email, sem = "even" } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");
  if (sem !== "odd" && sem !== "even")
    return res.fail(400, 'sem must be "odd" or "even"');

  try {
    const s = sessions[email];
    const cacheKey = `calendar_${sem}`;
    if (hasCachedCalendar(s, sem)) {
      const calendar = s.cache[cacheKey] && Array.isArray(s.cache[cacheKey].months) ? s.cache[cacheKey] : null;
      return res.ok({
        calendar,
        sem,
        available: !!calendar,
        ...(calendar
          ? {}
          : {
              error:
                s.meta?.calendarUnavailable?.[sem] ||
                s.meta?.lastErrors?.[`calendar_${sem}`] ||
                "Academic calendar page is unavailable right now",
            }),
      });
    }

    await hydrateGoSession(email, { calendarSems: [sem] });
    const calendar = s.cache[cacheKey] && Array.isArray(s.cache[cacheKey].months) ? s.cache[cacheKey] : null;
    if (!calendar) {
      // Fallback: try Supabase cached calendar
      const cached = await supabaseClient.getCachedCalendar(email, sem).catch(() => null);
      if (cached?.calendar) {
        log("CALENDAR", `Returning cached calendar from Supabase for ${email} (${sem})`);
        return res.ok({ calendar: cached.calendar, sem, available: true, fromCache: true });
      }
      return res.ok({
        calendar: null,
        sem,
        available: false,
        error:
          s.meta?.calendarUnavailable?.[sem] ||
          s.meta?.lastErrors?.[`calendar_${sem}`] ||
          "Academic calendar page is unavailable right now",
      });
    }

    // Check for upcoming holidays in the next 7 days and notify
    setImmediate(() => {
      try {
        const today = new Date();
        const nextWeek = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);
        const upcomingHolidays = [];
        for (const month of calendar.months || []) {
          for (const day of month.days || []) {
            if (!day.date) continue;
            const d = new Date(day.date);
            if (d >= today && d <= nextWeek && (day.type === "holiday" || day.isHoliday)) {
              upcomingHolidays.push({ date: day.date, event: day.event || day.title || "Holiday" });
            }
          }
        }
        if (upcomingHolidays.length > 0) {
          supabaseClient.hasUnreadNotificationOfType(email, "holiday_alert").then((hasUnread) => {
            if (!hasUnread) {
              const holiday = upcomingHolidays[0];
              const holidayDate = new Date(holiday.date).toLocaleDateString("en-IN", { day: "numeric", month: "short" });
              supabaseClient.createNotification(email, {
                type: "holiday_alert",
                title: "📅 Upcoming Holiday",
                body: `${holiday.event} on ${holidayDate}. No classes scheduled.${upcomingHolidays.length > 1 ? ` Plus ${upcomingHolidays.length - 1} more holiday(s) this week.` : ""}`,
                data: { holidays: upcomingHolidays },
              }).catch((err) => log("NOTIFICATIONS", `Holiday notif failed: ${err.message}`));
            }
          }).catch(() => {});
        }
      } catch (err) {
        log("CALENDAR", `Holiday check failed for ${email}: ${err.message}`);
      }
    });

    return res.ok({ calendar, sem, available: true });
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("CALENDAR", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /init?email=&sem=odd|even
 * Fast initial load: fetches student + timetable + calendar in parallel.
 * Returns all three at once so the dashboard can render immediately.
 */
app.get("/init", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");

  try {
    const s = sessions[email];

    // Fetch studentInfo + timetable + BOTH calendar sems in ONE scraper call
    // (parallel inside the Go binary) instead of two sequential calls.
    const semHint = String(req.query.sem || "").toLowerCase();
    const calendarSems = [];
    if (semHint === "odd" || semHint === "even") {
      if (!hasCachedCalendar(s, semHint)) calendarSems.push(semHint);
    } else {
      // Unknown sem yet — fetch both so we have the right one regardless
      if (!hasCachedCalendar(s, "odd")) calendarSems.push("odd");
      if (!hasCachedCalendar(s, "even")) calendarSems.push("even");
    }

    await hydrateGoSession(email, {
      sections: [
        ...(hasCachedSection(s, "studentInfo") ? [] : ["studentInfo"]),
        ...(hasCachedSection(s, "timetable") ? [] : ["timetable"]),
      ],
      calendarSems,
    });

    const sem = String(req.query.sem || getSemType(s.cache.studentInfo || {}) || "odd").toLowerCase();
    const calKey = `calendar_${sem}`;

    // Return data immediately with whatever cached photos are available.
    // Faculty photo enrichment + student photo fallback happen in the background
    // and will be picked up on subsequent requests.
    const calendar = s.cache[calKey] && Array.isArray(s.cache[calKey].months) ? s.cache[calKey] : null;
    // Student photo fallback is blocking (user wants it immediately)
    if (needsStudentPhotoFallback(s)) {
      try {
        await ensureUsableStudentPhoto(email);
      } catch (photoErr) {
        log("PHOTO", `init photo fallback failed for ${email}: ${photoErr.message}`);
      }
    }
    if (s.cache.studentInfo && !s.cache.studentInfo.PhotoUrl && s.cache.photo) {
      s.cache.studentInfo.PhotoUrl = s.cache.photo;
    }
    // Fallback: if studentInfo is missing (e.g. attendance 403), try Supabase cache
    let studentInfo = s.cache.studentInfo;
    if (!studentInfo) {
      const cached = await supabaseClient.getCachedProfile(email).catch(() => null);
      if (cached?.raw_data) studentInfo = cached.raw_data;
    }

    // Fallback: if timetable is missing, try Supabase cache
    let timetable = s.cache.timetable;
    if (!timetable) {
      const cachedTt = await supabaseClient.getCachedTimetable(email).catch(() => null);
      if (cachedTt?.timetable) timetable = cachedTt.timetable;
    }

    // Fallback: if calendar is missing, try Supabase cache
    let calendarFinal = calendar;
    if (!calendarFinal) {
      const cachedCal = await supabaseClient.getCachedCalendar(email, sem).catch(() => null);
      if (cachedCal?.calendar) calendarFinal = cachedCal.calendar;
    }

    const payload = {
      studentInfo,
      timetable,
      calendar: calendarFinal,
      sem,
      calendarAvailable: !!calendarFinal,
      photosReady: areFacultyPhotosReady(s),
    };
    // Faculty photo enrichment in the background — photos appear on next poll/refresh
    setImmediate(() => {
      warmTimetableFacultyPhotoUrls(email, "INIT");
      warmFacultyCache(s.cache.timetable);
    });
    return res.ok(payload);
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("INIT", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /summary?email=
 * Dashboard-ready snapshot in one request.
 */
app.get("/summary", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");

  try {
    const s = sessions[email];
    await hydrateGoSession(email, {
      sections: [
        ...(hasCachedSection(s, "studentInfo") ? [] : ["studentInfo"]),
        ...(hasCachedSection(s, "attendance") ? [] : ["attendance"]),
        ...(hasCachedSection(s, "timetable") ? [] : ["timetable"]),
      ],
      calendarSems: ["odd", "even"].filter((sem) => !hasCachedCalendar(s, sem)),
    });

    warmTimetableFacultyPhotoUrls(email, "SUMMARY");
    const activeSession = sessions[email];
    if (!activeSession) throw Object.assign(new Error("Session expired. Please login again."), { expired: true });
    const summary = buildAcademiaSummary(email, activeSession);
    return res.ok(summary);
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("SUMMARY", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /all?email=
 * Fetches student info, attendance, marks and timetable in one call.
 */
app.get("/all", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");

  try {
    const s = sessions[email];
    await hydrateGoSession(email, {
      sections: [
        ...(hasCachedSection(s, "studentInfo") ? [] : ["studentInfo"]),
        ...(hasCachedSection(s, "attendance") ? [] : ["attendance"]),
        ...(hasCachedSection(s, "marks") ? [] : ["marks"]),
        ...(hasCachedSection(s, "timetable") ? [] : ["timetable"]),
      ],
    });
    warmTimetableFacultyPhotoUrls(email, "ALL");

    if (needsStudentPhotoFallback(s)) {
      try {
        await ensureUsableStudentPhoto(email);
      } catch (photoErr) {
        log("PHOTO", `all photo fallback failed for ${email}: ${photoErr.message}`);
      }
    }

    return res.ok({
      studentInfo: s.cache.studentInfo,
      attendance: s.cache.attendance,
      marks: normalizeMarksRecords(s.cache.marks),
      timetable: s.cache.timetable,
    });
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("ALL", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /schedule?email=[&dayOrder=N]
 * Returns today's classes (or a specific day order if dayOrder=N is supplied).
 */
app.get("/schedule", async (req, res) => {
  const { email, dayOrder } = req.query;
  if (!email) return res.fail(400, "email query param is required");
  if (!sessions[email]) return res.fail(401, "No active session. Please login first.");
  const override = dayOrder && /^[1-9]$/.test(dayOrder) ? dayOrder : null;

  try {
    const s = sessions[email];

    if (override) {
      await hydrateGoSession(email, {
        sections: hasCachedSection(s, "timetable") ? [] : ["timetable"],
      });
      warmTimetableFacultyPhotoUrls(email, "SCHEDULE");
      const schedule = buildScheduleFromData({
        timetable: s.cache.timetable,
        overrideDayOrder: override,
      });
      return res.ok({ schedule });
    }

    // Fetch studentInfo + timetable + both calendars in ONE call (parallel in Go)
    await hydrateGoSession(email, {
      sections: [
        ...(hasCachedSection(s, "studentInfo") ? [] : ["studentInfo"]),
        ...(hasCachedSection(s, "timetable") ? [] : ["timetable"]),
      ],
      calendarSems: ["odd", "even"].filter((sem) => !hasCachedCalendar(s, sem)),
    });
    warmTimetableFacultyPhotoUrls(email, "SCHEDULE");

    const semNum = parseInt(s.cache.studentInfo?.Semester || "1", 10);
    const semType = semNum % 2 === 0 ? "even" : "odd";

    const schedule = buildScheduleFromData({
      studentInfo: s.cache.studentInfo,
      timetable: s.cache.timetable,
      calendar: s.cache[`calendar_${semType}`],
    });
    return res.ok({ schedule });
  } catch (err) {
    if (err.expired) return res.fail(401, "Session expired. Please login again.");
    log("SCHEDULE", `Error for ${email}: ${err.message}`);
    return res.fail(500, err.message);
  }
});

/**
 * GET /faculty-photo?url=https://www.srmist.edu.in/wp-content/...
 * Proxies faculty images with the correct Referer to bypass hotlink protection.
 */
app.get("/faculty-photo", async (req, res) => {
  const { url } = req.query;
  if (!url || !url.startsWith("https://www.srmist.edu.in/"))
    return res.fail(400, "Invalid or missing url param");

  try {
    const imgRes = await fetch(url, {
      headers: {
        "Referer": "https://www.srmist.edu.in/",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
      },
    });
    if (!imgRes.ok) return res.fail(imgRes.status, "Image fetch failed");

    const contentType = imgRes.headers.get("content-type") || "image/jpeg";
    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "public, max-age=86400");
    res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
    const buf = await imgRes.arrayBuffer();
    res.send(Buffer.from(buf));
  } catch (err) {
    log("PHOTO", `Proxy error for ${url}: ${err.message}`);
    res.fail(502, "Could not fetch image");
  }
});

/**
 * GET /student-photo?email=
 * Proxies the student profile photo from the Zoho previewengine.
 * The photo is on previewengine-accl.zoho.com (different from academia.srmist.edu.in)
 * so the browser cannot send session cookies to it directly. This endpoint fetches
 * it server-side using the stored session cookies and streams bytes back.
 */
app.get("/student-photo", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.fail(400, "email query param is required");

  const s = sessions[email];
  if (!s) return res.fail(401, "No active session. Please login first.");

  if (needsGoStudentPhotoRefresh(s)) {
    try {
      await refreshGoStudentInfo(email);
    } catch (refreshErr) {
      log("PHOTO", `student-photo refresh failed for ${email}: ${refreshErr.message}`);
    }
  }

  if (needsStudentPhotoFallback(s)) {
    try {
      await ensureUsableStudentPhoto(email);
    } catch (photoErr) {
      log("PHOTO", `student-photo fallback failed for ${email}: ${photoErr.message}`);
    }
  }

  const photoUrl =
    s.cache?.studentInfo?.PhotoUrl ||
    s.cache?.photo ||
    null;

  if (!photoUrl) {
    return res.fail(404, "No student photo available. Try re-fetching your profile.");
  }

  // If already a data URI, decode and send directly
  if (photoUrl.startsWith("data:")) {
    const commaIdx = photoUrl.indexOf(",");
    const mimeMatch = photoUrl.match(/^data:([^;]+);base64,/);
    const contentType = mimeMatch ? mimeMatch[1] : "image/jpeg";
    const b64 = commaIdx >= 0 ? photoUrl.slice(commaIdx + 1) : "";
    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "public, max-age=3600");
    return res.send(Buffer.from(b64, "base64"));
  }

  if (!isStudentPhotoProxyUrl(photoUrl)) {
    return res.fail(400, "Photo URL is not a supported student photo URL.");
  }

  try {
    touch(email);

    let cookieHeader = "";
    if (Array.isArray(s.cookies) && s.cookies.length > 0) {
      cookieHeader = s.cookies.map((c) => `${c.name}=${c.value}`).join("; ");
    }

    const imgRes = await fetch(photoUrl, {
      headers: {
        "Cookie": cookieHeader,
        "Referer": "https://academia.srmist.edu.in/",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
      },
    });

    if (!imgRes.ok) {
      log("PHOTO", `student-photo proxy got ${imgRes.status} for ${email}`);
      return res.fail(imgRes.status, `Photo request returned ${imgRes.status}`);
    }

    const contentType = imgRes.headers.get("content-type") || "image/jpeg";
    if (!contentType.startsWith("image/")) {
      log("PHOTO", `student-photo non-image response "${contentType}" for ${email}`);
      return res.fail(502, "Photo endpoint did not return an image. Session may be expired.");
    }

    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "public, max-age=3600");
    res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
    const buf = await imgRes.arrayBuffer();
    log("PHOTO", `student-photo proxy OK for ${email} (${buf.byteLength} bytes)`);
    return res.send(Buffer.from(buf));
  } catch (err) {
    log("PHOTO", `student-photo proxy error for ${email}: ${err.message}`);
    return res.fail(502, "Could not fetch student photo.");
  }
});

// ─── Faculty proxy ─────────────────────────────────────────────────────────────



function nameToSlug(rawName) {
  return rawName
    .replace(/\(.*?\)/g, "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

const facultyCache = new Map();
const FACULTY_CACHE_TTL = 60 * 60 * 1000; // 1 hour
const SCRAPER_URL = process.env.SCRAPER_URL || "http://localhost:8080";
const SCRAPER_KEY = process.env.SCRAPER_KEY || "";
const scraperHeaders = () => (SCRAPER_KEY ? { "X-Scraper-Key": SCRAPER_KEY } : {});

function facultyNameCacheKey(rawName) {
  const cleanName = String(rawName || "").replace(/\(.*?\)/g, "").trim();
  if (!cleanName) return "";
  return cleanName.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function getFreshFacultyCacheEntry(rawName) {
  const cacheKey = facultyNameCacheKey(rawName);
  if (!cacheKey) return null;
  const cached = facultyCache.get(cacheKey);
  if (!cached) return null;
  if (Date.now() - cached.fetchedAt >= FACULTY_CACHE_TTL) return null;
  return cached;
}

async function fetchFacultyProfileForTimetable(rawName, email) {
  const params = new URLSearchParams({ name: rawName });
  if (email) params.set("email", email);

  const res = await fetch(`http://127.0.0.1:${PORT}/faculty?${params.toString()}`, {
    headers: { "User-Agent": "faculty-photo-attach/1.0" },
  });
  if (!res.ok) return null;

  const payload = await res.json().catch(() => null);
  if (!payload?.success || !payload.faculty) return null;
  return payload.faculty;
}

async function resolveFacultyPhotoUrl(rawName, email) {
  if (!rawName) return "";
  const cached = getFreshFacultyCacheEntry(rawName);
  if (cached) return cached.data?.photo_url || "";
  try {
    const faculty = await fetchFacultyProfileForTimetable(rawName, email);
    return faculty?.photo_url || "";
  } catch {
    return "";
  }
}

/**
 * Returns true if all faculty names in the timetable + attendance have cached photos.
 * Used to set `photosReady` in API responses so the frontend knows whether to poll.
 */
function areFacultyPhotosReady(session) {
  if (!session?.cache) return true;

  const timetable = session.cache.timetable;
  if (timetable) {
    const courses = Array.isArray(timetable.courses) ? timetable.courses : [];
    const advisors = Array.isArray(timetable.advisors) ? timetable.advisors : [];
    const allNames = [
      ...courses.map((c) => c.facultyName).filter(Boolean),
      ...advisors.map((a) => a.name).filter(Boolean),
    ];
    for (const name of allNames) {
      if (!getFreshFacultyCacheEntry(name)) return false;
    }
  }

  const attendance = session.cache.attendance;
  if (Array.isArray(attendance)) {
    for (const rec of attendance) {
      if (rec.facultyName && !getFreshFacultyCacheEntry(rec.facultyName)) return false;
    }
  }

  return true;
}

async function ensureTimetableFacultyPhotoUrls(email) {
  const session = sessions[email];
  if (!session?.cache?.timetable) return null;

  const timetable = session.cache.timetable;
  const courses = Array.isArray(timetable.courses) ? timetable.courses : [];
  const advisors = Array.isArray(timetable.advisors) ? timetable.advisors : [];

  const coursesReady = courses.every((course) => !course.facultyName || hasOwn(course, "facultyPhotoUrl"));
  const advisorsReady = advisors.every((advisor) => !advisor.name || hasOwn(advisor, "photoUrl"));
  if (coursesReady && advisorsReady) return timetable;

  if (session.timetableFacultyPhotoPromise) {
    return session.timetableFacultyPhotoPromise;
  }

  session.timetableFacultyPhotoPromise = (async () => {
    const names = [
      ...courses.map((course) => course.facultyName).filter(Boolean),
      ...advisors.map((advisor) => advisor.name).filter(Boolean),
    ];
    const uniqueNames = [...new Set(names)];
    const entries = await Promise.all(
      uniqueNames.map(async (name) => [name, await resolveFacultyPhotoUrl(name, email)])
    );
    const photoByName = Object.fromEntries(entries);

    session.cache.timetable = {
      ...timetable,
      courses: courses.map((course) => ({
        ...course,
        facultyPhotoUrl: course.facultyName ? (photoByName[course.facultyName] || "") : "",
      })),
      advisors: advisors.map((advisor) => ({
        ...advisor,
        photoUrl: advisor.name ? (photoByName[advisor.name] || "") : "",
      })),
    };

    return session.cache.timetable;
  })();

  try {
    return await session.timetableFacultyPhotoPromise;
  } finally {
    delete session.timetableFacultyPhotoPromise;
  }
}

function attachAttendanceFacultyPhotos(session) {
  const attendance = session?.cache?.attendance;
  if (!Array.isArray(attendance) || !attendance.length) return attendance || [];

  const photoByName = {};
  const photoByCourse = {};
  for (const course of session?.cache?.timetable?.courses || []) {
    if (course.courseCode) photoByCourse[course.courseCode] = course.facultyPhotoUrl || "";
    if (course.facultyName) photoByName[course.facultyName] = course.facultyPhotoUrl || "";
  }

  return attendance.map((rec) => {
    if (hasOwn(rec, "facultyPhotoUrl") && rec.facultyPhotoUrl) return rec;
    const fromCourse = rec.courseCode ? photoByCourse[rec.courseCode] : "";
    const fromName = rec.facultyName ? photoByName[rec.facultyName] : "";
    const cached = rec.facultyName ? getFreshFacultyCacheEntry(rec.facultyName) : null;
    const fromFacultyCache = cached?.data?.photo_url || "";
    return {
      ...rec,
      facultyPhotoUrl: fromCourse || fromName || fromFacultyCache || rec.facultyPhotoUrl || "",
    };
  });
}

async function ensureAttendanceFacultyPhotos(email) {
  const session = sessions[email];
  if (!session?.cache?.attendance?.length) return session?.cache?.attendance || [];

  if (!hasCachedSection(session, "timetable")) {
    try {
      await hydrateGoSession(email, { sections: ["timetable"] });
    } catch {
      /* best effort */
    }
  }

  if (hasCachedSection(session, "timetable")) {
    await ensureTimetableFacultyPhotoUrls(email);
  }

  const uniqueNames = [...new Set(
    (session.cache.attendance || [])
      .map((rec) => rec.facultyName)
      .filter(Boolean)
  )];

  const photoByName = {};
  await Promise.all(uniqueNames.map(async (name) => {
    photoByName[name] = await resolveFacultyPhotoUrl(name, email);
  }));

  session.cache.attendance = (session.cache.attendance || []).map((rec) => ({
    ...rec,
    facultyPhotoUrl: rec.facultyName ? (photoByName[rec.facultyName] || "") : (rec.facultyPhotoUrl || ""),
  }));

  session.cache.attendance = attachAttendanceFacultyPhotos(session);
  return session.cache.attendance;
}

function warmTimetableFacultyPhotoUrls(email, tag = "FACULTY") {
  setImmediate(() => {
    ensureTimetableFacultyPhotoUrls(email).catch((err) => {
      log(tag, `Background timetable photo enrichment failed for ${email}: ${err.message}`);
    });
  });
}

// Warms the faculty cache in the background for all teachers in a timetable.
// Calls our own /faculty endpoint (which has full slug fallback logic) instead
// of the Go scraper search directly — so ALL teachers get pre-cached, not just
// those found via WordPress search.
function warmFacultyCache(timetable) {
  if (!timetable) return;
  const names = [
    ...new Set([
      ...(timetable.courses || []).map((c) => c.facultyName).filter(Boolean),
      ...(timetable.advisors || []).map((a) => a.name).filter(Boolean),
    ]),
  ];
  if (!names.length) return;
  log("FACULTY", `Warming cache for ${names.length} teacher(s) in background`);

  names.forEach((rawName, i) => {
    setTimeout(async () => {
      const cleanName = rawName.replace(/\(.*?\)/g, "").trim();
      const cacheKey = facultyNameCacheKey(rawName);
      if (facultyCache.has(cacheKey)) return;

      try {
        const r = await fetch(
          `http://localhost:${PORT}/faculty?name=${encodeURIComponent(rawName)}`,
          { headers: { "User-Agent": "warm-up/1.0" } }
        );
        if (r.ok) {
          const d = await r.json();
          if (d.success && d.faculty) {
            log("FACULTY", `✓ Warm: ${cleanName} → photo=${d.faculty.photo_url ? "yes" : "none"}`);
          }
        }
      } catch { /* best-effort — ignore errors */ }
    }, i * 200);
  });
}

/**
 * GET /faculty?name=Dr.S.Aruna%20(101257)&email=user@srmist.edu.in
 * Proxies to the Go faculty scraper at localhost:8080.
 * No session required — SRM faculty pages are public.
 */
app.get("/faculty", async (req, res) => {
  let rawName = req.query.name;
  const email = req.query.email;
  if (!rawName) return res.fail(400, "name query param is required");

  rawName = rawName.replace(/<[^>]*>/g, "").trim();
  if (rawName.length > 200) return res.fail(400, "name param too long");
  if (!rawName) return res.fail(400, "name param is invalid");

  const cleanName = rawName.replace(/\(.*?\)/g, "").trim();
  // Strip title prefix (Dr./Prof./etc.)
  const noTitle = cleanName.replace(/^(prof|mrs|ms|mr|dr)\.?\s*/i, "").trim();
  // Remove single-letter dotted initials like "H." at the START only
  // "H.Karthikeyan" → "Karthikeyan", but "Monica Bhavani M" → "Monica Bhavani M" (unchanged)
  const hasLeadingInitial = /^[A-Z]\./.test(noTitle);
  const searchName = noTitle
    .replace(/^([A-Z]\.)+\s*/g, "")  // strip leading "H." or "H.K." etc.
    .replace(/\./g, " ")              // remaining dots → spaces
    .trim();
  // Build search terms: for "H.Karthikeyan" → ["Karthikeyan", "Karthikeyan"] (same, deduplicated)
  //                      for "Monica Bhavani M" → ["Monica Bhavani M", "Bhavani"] (full name first)
  const longestWord = searchName.split(/\s+/).sort((a, b) => b.length - a.length)[0] || searchName;
  // Always try full searchName first; only use longestWord as extra fallback when there are 2+ words
  const searchTerms = (() => {
    const terms = [searchName];
    if (hasLeadingInitial && longestWord !== searchName) terms.push(longestWord); // "H.Karthikeyan" → also try "Karthikeyan"
    if (!hasLeadingInitial && searchName.includes(" ")) terms.push(longestWord);  // "Monica Bhavani M" → also try "Bhavani"
    return [...new Set(terms)];
  })();

  // Use cleanName for slug (employee ID already stripped) so slug candidates are correct
  const naiveSlug = nameToSlug(cleanName);
  if (!naiveSlug) return res.fail(400, "Could not derive a slug from the given name");

  const cacheKey = facultyNameCacheKey(cleanName);

  const cached = facultyCache.get(cacheKey);
  if (cached && Date.now() - cached.fetchedAt < FACULTY_CACHE_TTL) {
    if (cached.data === null) return res.fail(404, "Faculty not found");
    return res.ok({ faculty: cached.data });
  }

  // Check Supabase DB cache (persists across server restarts)
  try {
    const dbCached = await supabaseClient.getCachedFacultyProfile(cacheKey);
    if (dbCached?.profile_data) {
      const age = Date.now() - new Date(dbCached.fetched_at).getTime();
      if (age < FACULTY_CACHE_TTL) {
        // Refresh in-memory cache too
        const entry = { data: dbCached.profile_data, fetchedAt: new Date(dbCached.fetched_at).getTime() };
        facultyCache.set(cacheKey, entry);
        facultyCache.set(naiveSlug, entry);
        return res.ok({ faculty: dbCached.profile_data });
      }
    }
  } catch (e) {
    // Non-fatal — fall through to scraping
  }

  // Deduplicate concurrent requests for the same teacher
  if (!global.facultyInFlight) global.facultyInFlight = new Map();
  if (global.facultyInFlight.has(cacheKey)) {
    try {
      const data = await global.facultyInFlight.get(cacheKey);
      if (data === null) return res.fail(404, "Faculty not found");
      return res.ok({ faculty: data });
    } catch {
      // If the in-flight promise rejected, we'll try again below (shouldn't happen)
    }
  }

  // Define the work as a promise so we can cache it in-flight
  const fetchFacultyWork = async () => {
    let selectedProfile = null;

    try {
      let profiles = [];
      for (const term of searchTerms) {
        try {
          const searchRes = await fetch(`${SCRAPER_URL}/api/search-profiles?name=${encodeURIComponent(term)}`, { headers: scraperHeaders() });
          if (searchRes.ok) {
            const data = await searchRes.json();
            profiles = data.profiles || [];
            log("FACULTY", `Search "${term}" → ${profiles.length} result(s) for "${cleanName}"`);
            if (profiles.length > 0) break;
          }
        } catch (_) { /* SCRAPER_URL unreachable, try next term or fall back below */ }
      }

      // Fallback: if SCRAPER_URL is unreachable, try Supabase faculty_cache
      if (profiles.length === 0) {
        for (const slug of [nameToSlug(cleanName), ...searchTerms.map(nameToSlug)]) {
          try {
            const cached = await supabaseClient.getCachedFacultyProfile(slug);
            if (cached?.profile_data) {
              profiles = [cached.profile_data];
              log("FACULTY", `Search fallback via Supabase cache: ${slug}`);
              break;
            }
          } catch (_) { /* try next */ }
        }
      }

      if (profiles.length === 1) {
        selectedProfile = profiles[0];
      } else if (profiles.length > 1) {
        const normalizeName = (n) =>
          (n || "").toLowerCase()
            .replace(/^(prof|mrs|ms|mr|dr)\.?\s*/i, "")
            .replace(/[^a-z\s]/g, "")
            .split(/\s+/).filter(Boolean).join(" ");
        const targetNorm = normalizeName(cleanName);

        let candidates = profiles.filter((p) => normalizeName(p.name) === targetNorm);
        if (candidates.length === 0) candidates = profiles;

        if (candidates.length === 1) {
          selectedProfile = candidates[0];
        } else {
          let studentContext = "";
          if (email && sessions[email]?.cache?.studentInfo) {
            const si = sessions[email].cache.studentInfo;
            studentContext = [si.Department, si.Program, si.Section].filter(Boolean).join(" ");
          }

          if (studentContext) {
            const ctxWords = studentContext.toLowerCase().split(/\W+/).filter((w) => w.length > 3);
            let bestScore = 0;
            let bestMatch = null;
            for (const p of candidates) {
              const combinedCtx = [p.department, p.campus].filter(Boolean).join(" ");
              const deptWords = combinedCtx.toLowerCase().split(/\W+/).filter((w) => w.length > 3);
              const score = deptWords.filter((w) => ctxWords.some((cw) => cw.includes(w) || w.includes(cw))).length;
              if (score > bestScore) { bestScore = score; bestMatch = p; }
            }
            if (bestMatch && bestScore > 0) selectedProfile = bestMatch;
          }

          if (!selectedProfile) selectedProfile = candidates[0];
        }
      }
    } catch (searchErr) {
      log("FACULTY", `Search failed for "${cleanName}": ${searchErr.message} — falling back to slug`);
    }

    if (!selectedProfile) {
      // SRM slugs vary wildly — try multiple permutations before giving up
      const TITLE_PREFIXES = ["dr", "mr", "mrs", "prof"];
      const parts = noTitle.split(/[\s.]+/).filter(Boolean);
      const trailingInitial = parts.length > 1 && parts[parts.length - 1].length === 1
        ? parts[parts.length - 1].toLowerCase() : null;
      // Detect leading single-letter initial(s) (e.g., "R.Mangalagowri" → ["r"])
      const leadingInitials = [];
      let startIdx = 0;
      while (startIdx < parts.length - 1 && parts[startIdx].length === 1) {
        leadingInitials.push(parts[startIdx].toLowerCase());
        startIdx++;
      }
      const leadingInit = leadingInitials.join("") || null;
      const bodyParts = (trailingInitial ? parts.slice(0, -1) : parts)
        .slice(startIdx)
        .map(p => p.toLowerCase());
      const bodySlug = bodyParts.join("-");

      const slugCandidates = [...new Set([
        // 1. Naive slug (e.g. kaviyaraj-r, dr-monica-bhavani-m)
        naiveSlug,
        // 2. All title prefixes + body + trailing initial  → mr-kaviyaraj-r ✓
        ...trailingInitial ? TITLE_PREFIXES.map(t => `${t}-${bodySlug}-${trailingInitial}`) : [],
        // 3. All title prefixes + trailing initial + body  → dr-m-monica-bhavani ✓
        ...trailingInitial ? TITLE_PREFIXES.map(t => `${t}-${trailingInitial}-${bodySlug}`) : [],
        // 4. No prefix + body + trailing initial           → kaviyaraj-r, monica-bhavani-m
        trailingInitial ? `${bodySlug}-${trailingInitial}` : null,
        // 5. No prefix + initial + body                    → r-kaviyaraj
        trailingInitial ? `${trailingInitial}-${bodySlug}` : null,
        // 6. All title prefixes + body (no initial)        → dr-kaviyaraj, mr-kaviyaraj
        ...TITLE_PREFIXES.map(t => `${t}-${bodySlug}`),
        // 7. Body only (no title, no initial)              → kaviyaraj, monica-bhavani
        bodySlug,
        // 8. rawName dots→spaces variation
        nameToSlug(rawName.replace(/\./g, " ").trim()),
        // 9. Leading initial moved to end (e.g., mangalagowri-r, dr-mangalagowri-r)
        ...leadingInit ? [
          `${bodySlug}-${leadingInit}`,
          ...TITLE_PREFIXES.map(t => `${t}-${bodySlug}-${leadingInit}`),
        ] : [],
      ])].filter(Boolean);

      log("FACULTY", `Trying ${slugCandidates.length} slug(s) for "${cleanName}": ${slugCandidates.join(", ")}`);

      for (const slug of slugCandidates) {
        try {
          const goRes = await fetch(`${SCRAPER_URL}/api/faculty/${slug}`, { headers: scraperHeaders() });
          if (goRes.ok) {
            selectedProfile = await goRes.json();
            log("FACULTY", `Found "${cleanName}" via slug: ${slug}`);
            break;
          }
        } catch (_) { /* try next */ }
      }

      // Fallback: if SCRAPER_URL is unreachable, try Supabase faculty_cache
      if (!selectedProfile) {
        for (const slug of slugCandidates) {
          try {
            const cached = await supabaseClient.getCachedFacultyProfile(slug);
            if (cached?.profile_data) {
              selectedProfile = cached.profile_data;
              log("FACULTY", `Found "${cleanName}" via Supabase cache: ${slug}`);
              break;
            }
          } catch (_) { /* try next */ }
        }
      }

      if (!selectedProfile) {
        // Return null so the outer promise wrapper can handle the 404 for all waiters
        return null;
      }
    }

    if (selectedProfile) {
      const queryTokens = searchName.toLowerCase().split(/\s+/).filter((w) => w.length > 1);
      const profileName = (selectedProfile.name || "").toLowerCase()
        .replace(/^(prof|mrs|ms|mr|dr)\.?\s*/i, "");
      const profileTokens = profileName.split(/[^a-z]+/).filter((w) => w.length > 1);
      const matchCount = queryTokens.filter((t) => profileTokens.some((pt) => pt.includes(t) || t.includes(pt))).length;
      const minRequired = Math.min(2, queryTokens.length);

      if (matchCount < minRequired) {
        // Return null so the in-flight promise resolves to null
        return null;
      }
    }

    return selectedProfile;
  };

  try {
    // Start the work and store the promise in the global map
    const workPromise = fetchFacultyWork();
    global.facultyInFlight.set(cacheKey, workPromise);
    
    // Wait for the result
    const selectedProfile = await workPromise;
    
    // Cleanup the in-flight map
    global.facultyInFlight.delete(cacheKey);

    if (!selectedProfile) {
      facultyCache.set(cacheKey, { data: null, fetchedAt: Date.now() });
      return res.fail(404, "Faculty not found");
    }

    const cacheEntry = { data: selectedProfile, fetchedAt: Date.now() };
    facultyCache.set(cacheKey, cacheEntry);
    facultyCache.set(naiveSlug, cacheEntry);

    // Save to Supabase DB cache (persists across restarts)
    supabaseClient.saveCachedFacultyProfile(cacheKey, selectedProfile).catch((e) => {
      log("FACULTY", `DB cache save failed for "${cleanName}": ${e.message}`);
    });

    return res.ok({ faculty: selectedProfile });
  } catch (err) {
    global.facultyInFlight.delete(cacheKey); // cleanup on error
    log("FACULTY", `Error fetching "${cleanName}": ${err.message}`);
    return res.fail(502, "Faculty scraper unavailable. Make sure the Go server is running on port 8080.");
  }
});

// ─── AI Proxy ─────────────────────────────────────────────────────────────────
// Forwards chat requests to the configured Ollama cloud endpoint.
// The API key lives server-side only — never exposed to the app bundle.

const OLLAMA_URL   = (process.env.OLLAMA_URL   || "https://ollama.com/api").replace(/\/$/, "");
const OLLAMA_MODEL = process.env.OLLAMA_MODEL  || "gemma4:31b-cloud";
const OLLAMA_KEY   = process.env.OLLAMA_API_KEY || "";

app.post("/ai/chat", express.json({ limit: "64kb" }), async (req, res) => {
  try {
    const { messages, format } = req.body || {};
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: "messages array required" });
    }

    const endpoint = OLLAMA_URL.endsWith("/api")
      ? `${OLLAMA_URL}/chat`
      : `${OLLAMA_URL}/api/chat`;

    const headers = { "Content-Type": "application/json" };
    if (OLLAMA_KEY) headers["Authorization"] = `Bearer ${OLLAMA_KEY}`;

    const upstream = await fetch(endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify({
        model: OLLAMA_MODEL,
        stream: false,
        format: format || "json",
        options: { temperature: 0.1 },
        messages,
      }),
    });

    const data = await upstream.json();
    if (!upstream.ok) {
      return res.status(502).json({ error: data?.error || `Upstream returned ${upstream.status}` });
    }
    return res.json(data);
  } catch (err) {
    log("AI", `Proxy error: ${err.message}`);
    return res.status(502).json({ error: "AI service unreachable" });
  }
});

// ─── Supabase Endpoints ───────────────────────────────────────────────────────

// GET /profile/cache?email= — Get cached student profile
app.get("/profile/cache", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    const profile = await supabaseClient.getCachedProfile(email);
    if (!profile) return res.status(404).json({ success: false, message: "No cached profile" });
    return res.json({ success: true, data: profile });
  } catch (err) {
    log("PROFILE", `Cache fetch error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to fetch cached profile" });
  }
});

// POST /profile/cache — Cache student profile
app.post("/profile/cache", async (req, res) => {
  const { email, studentInfo } = req.body;
  if (!email || !studentInfo) return res.status(400).json({ success: false, message: "Missing email or studentInfo" });
  try {
    const profile = await supabaseClient.cacheStudentProfile(email, studentInfo);
    return res.json({ success: true, data: profile });
  } catch (err) {
    log("PROFILE", `Cache save error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to cache profile" });
  }
});

// GET /attendance/history?email=&days=30 — Get attendance history
app.get("/attendance/history", async (req, res) => {
  const { email, days = 30 } = req.query;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    const history = await supabaseClient.getAttendanceHistory(email, parseInt(days));
    return res.json({ success: true, data: history });
  } catch (err) {
    log("ATTENDANCE", `History fetch error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to fetch attendance history" });
  }
});

// POST /attendance/snapshot — Save attendance snapshot
app.post("/attendance/snapshot", async (req, res) => {
  const { email, subjects, overallPct } = req.body;
  if (!email || !subjects) return res.status(400).json({ success: false, message: "Missing email or subjects" });
  try {
    const snapshot = await supabaseClient.saveAttendanceSnapshot(email, subjects, overallPct);
    return res.json({ success: true, data: snapshot });
  } catch (err) {
    log("ATTENDANCE", `Snapshot save error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to save snapshot" });
  }
});

// GET /settings?email= — Get user settings
app.get("/settings", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    const settings = await supabaseClient.getUserSettings(email);
    return res.json({ success: true, data: settings || {} });
  } catch (err) {
    log("SETTINGS", `Fetch error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to fetch settings" });
  }
});

// POST /settings — Upsert user settings
app.post("/settings", async (req, res) => {
  const { email, settings } = req.body;
  if (!email || !settings) return res.status(400).json({ success: false, message: "Missing email or settings" });
  try {
    const updated = await supabaseClient.upsertUserSettings(email, settings);
    return res.json({ success: true, data: updated });
  } catch (err) {
    log("SETTINGS", `Upsert error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to save settings" });
  }
});

// GET /notifications?email=&unreadOnly=false — Get notifications
app.get("/notifications", async (req, res) => {
  const { email, unreadOnly = "false" } = req.query;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    const notifications = await supabaseClient.getNotifications(email, unreadOnly === "true");
    return res.json({ success: true, data: notifications });
  } catch (err) {
    log("NOTIFICATIONS", `Fetch error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to fetch notifications" });
  }
});

// POST /notifications — Create notification
app.post("/notifications", async (req, res) => {
  const { email, type, title, body, data } = req.body;
  if (!email || !type || !title) return res.status(400).json({ success: false, message: "Missing required fields" });
  try {
    const notification = await supabaseClient.createNotification(email, { type, title, body, data });
    return res.json({ success: true, data: notification });
  } catch (err) {
    log("NOTIFICATIONS", `Create error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to create notification" });
  }
});

// PATCH /notifications/:id/read — Mark notification as read
app.patch("/notifications/:id/read", async (req, res) => {
  const { id } = req.params;
  try {
    await supabaseClient.markNotificationRead(id);
    return res.json({ success: true });
  } catch (err) {
    log("NOTIFICATIONS", `Mark read error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to mark notification as read" });
  }
});

// POST /notifications/read-all — Mark all notifications as read
app.post("/notifications/read-all", async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    await supabaseClient.markAllNotificationsRead(email);
    return res.json({ success: true });
  } catch (err) {
    log("NOTIFICATIONS", `Mark all read error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to mark all notifications as read" });
  }
});

// GET /notification-settings?email= — Get notification settings
app.get("/notification-settings", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    const settings = await supabaseClient.getNotificationSettings(email);
    return res.json({ success: true, data: settings || {} });
  } catch (err) {
    log("NOTIFICATION_SETTINGS", `Fetch error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to fetch notification settings" });
  }
});

// POST /notification-settings — Upsert notification settings
app.post("/notification-settings", async (req, res) => {
  const { email, settings } = req.body;
  if (!email || !settings) return res.status(400).json({ success: false, message: "Missing email or settings" });
  try {
    const updated = await supabaseClient.upsertNotificationSettings(email, settings);
    return res.json({ success: true, data: updated });
  } catch (err) {
    log("NOTIFICATION_SETTINGS", `Upsert error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to save notification settings" });
  }
});

// GET /bookmarks?email= — Get job bookmarks
app.get("/bookmarks", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    const bookmarks = await supabaseClient.getJobBookmarks(email);
    return res.json({ success: true, data: bookmarks });
  } catch (err) {
    log("BOOKMARKS", `Fetch error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to fetch bookmarks" });
  }
});

// POST /bookmarks — Add/update job bookmark
app.post("/bookmarks", async (req, res) => {
  const { email, jobUuid, jobTitle, companyName, jobData, notes } = req.body;
  if (!email || !jobUuid) return res.status(400).json({ success: false, message: "Missing email or jobUuid" });
  try {
    const bookmark = await supabaseClient.addJobBookmark(email, { jobUuid, jobTitle, companyName, jobData, notes });
    return res.json({ success: true, data: bookmark });
  } catch (err) {
    log("BOOKMARKS", `Add error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to add bookmark" });
  }
});

// PATCH /bookmarks/:jobUuid — Update bookmark
app.patch("/bookmarks/:jobUuid", async (req, res) => {
  const { jobUuid } = req.params;
  const { email, updates } = req.body;
  if (!email || !updates) return res.status(400).json({ success: false, message: "Missing email or updates" });
  try {
    const bookmark = await supabaseClient.updateJobBookmark(email, jobUuid, updates);
    return res.json({ success: true, data: bookmark });
  } catch (err) {
    log("BOOKMARKS", `Update error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to update bookmark" });
  }
});

// DELETE /bookmarks/:jobUuid?email= — Remove bookmark
app.delete("/bookmarks/:jobUuid", async (req, res) => {
  const { jobUuid } = req.params;
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    await supabaseClient.removeJobBookmark(email, jobUuid);
    return res.json({ success: true });
  } catch (err) {
    log("BOOKMARKS", `Delete error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to delete bookmark" });
  }
});

// ─── Test Endpoints (for development) ────────────────────────────────────────

// POST /test/notification — Create a test notification
app.post("/test/notification", async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });
  try {
    const notification = await supabaseClient.createNotification(email, {
      type: "test",
      title: "Test Notification",
      body: "This is a test notification to verify real-time delivery works!",
      data: { timestamp: new Date().toISOString() }
    });
    return res.json({ success: true, data: notification });
  } catch (err) {
    log("TEST", `Test notification error: ${err.message}`);
    return res.status(500).json({ success: false, message: "Failed to create test notification" });
  }
});

// ─── Startup ──────────────────────────────────────────────────────────────────

function start() {
  const runtime = getAcademiaScraperRuntime();
  log("SERVER", `Go scraper: ${runtime.command}${runtime.args?.length ? ` ${runtime.args.join(" ")}` : ""} (source: ${runtime.source})`);

  app.listen(PORT, "0.0.0.0", () => {
    log("SERVER", `API server running on http://0.0.0.0:${PORT}`);
    log("SERVER", "Endpoints:");
    log("SERVER", "  POST /login              { email, password }");
    log("SERVER", "  GET  /init               ?email=&sem=odd|even");
    log("SERVER", "  GET  /attendance         ?email=");
    log("SERVER", "  GET  /marks              ?email=");
    log("SERVER", "  GET  /timetable          ?email=");
    log("SERVER", "  GET  /student            ?email=");
    log("SERVER", "  GET  /calendar           ?email=&sem=odd|even");
    log("SERVER", "  GET  /summary            ?email=");
    log("SERVER", "  GET  /schedule           ?email=");
    log("SERVER", "  GET  /all                ?email=");
    log("SERVER", "  GET  /student-photo      ?email=");
    log("SERVER", "  GET  /faculty-photo      ?url=");
    log("SERVER", "  GET  /faculty            ?name=&email=");
    log("SERVER", "  POST /logout             { email }");
    log("SERVER", "  GET  /status");
  });

  for (const sig of ["SIGINT", "SIGTERM"]) {
    process.on(sig, () => {
      log("SERVER", `${sig} received — shutting down...`);
      for (const email of Object.keys(sessions)) {
        destroySession(email, "server shutdown");
      }
      process.exit(0);
    });
  }
}

start();
