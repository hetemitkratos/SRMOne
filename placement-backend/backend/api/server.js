require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { runScraper } = require("../integrations/go/go_scraper_client");
const { encryptPassword, decryptPassword } = require("../utils/crypto");
const { storeCredentials, getCredentials, getAllAutoLoginCredentials, removeCredentials, updateAutoLoginStatus, supabase, createNotification, hasUnreadNotificationOfType, hasNotificationForEntity,
  getCachedPlacementProfile, cachePlacementProfile,
  getCachedJobs, cacheJobs,
  getCachedApplications, cacheApplications,
  getCachedNotices, cacheNotices,
  getCachedCompanies, cacheCompanies,
} = require("../utils/supabaseClient");

/** Stable id for a placement job/notice entity. */
function entityId(item) {
  if (!item || typeof item !== "object") return null;
  const raw = item.uuid ?? item.id ?? item.jobUuid ?? item.noticeId ?? null;
  if (raw == null || String(raw).trim() === "") return null;
  return String(raw);
}

/** Extract entity list from placement API payload shapes. */
function extractEntityList(payload) {
  if (!payload) return [];
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload._embedded?.entityModels)) return payload._embedded.entityModels;
  if (Array.isArray(payload.content)) return payload.content;
  if (Array.isArray(payload.data)) return payload.data;
  return [];
}

/**
 * Notify about items that are new vs the previous Supabase cache.
 * First fetch seeds cache without spamming. Later fetches notify on real diffs.
 */
async function notifyNewEntities({ academiaEmail, type, items, previousItems, titleFor, bodyFor, idKey }) {
  if (!academiaEmail || !items?.length) return;

  const prevIds = new Set(
    (previousItems || []).map(entityId).filter(Boolean)
  );
  const isFirstSnapshot = prevIds.size === 0;

  // Prefer newest first if createdDate exists
  const sorted = [...items].sort((a, b) => {
    const da = new Date(a.createdDate || a.created_at || a.postedDate || 0).getTime();
    const db = new Date(b.createdDate || b.created_at || b.postedDate || 0).getTime();
    return db - da;
  });

  // On first snapshot only consider items from the last 48h to avoid historic spam
  const cutoffMs = Date.now() - 48 * 60 * 60 * 1000;
  const candidates = sorted.filter((item) => {
    const id = entityId(item);
    if (!id) return false;
    if (!isFirstSnapshot) return !prevIds.has(id);
    const created = new Date(item.createdDate || item.created_at || item.postedDate || 0).getTime();
    return Number.isFinite(created) && created >= cutoffMs;
  });

  // Cap how many we fan out per refresh
  const toNotify = candidates.slice(0, 5);
  for (const item of toNotify) {
    const id = entityId(item);
    try {
      const already = await hasNotificationForEntity(academiaEmail, type, idKey, id);
      if (already) continue;
      await createNotification(academiaEmail, {
        type,
        title: titleFor(item),
        body: bodyFor(item),
        data: {
          [idKey]: id,
          jobId: item.id ?? undefined,
          jobUuid: item.uuid ?? undefined,
          noticeId: item.id ?? item.uuid ?? undefined,
          jobTitle: item.jobTitle || item.title || undefined,
          noticeTitle: item.title || item.subject || undefined,
          companyName: item.companyName || undefined,
        },
      });
    } catch (err) {
      console.error(`[notifications] ${type} create failed:`, err.message);
    }
  }
}

/** Diff+notify+cache the jobs section for one user. Shared by the section endpoint and the background poller. */
async function syncJobsSection(academiaEmail, result) {
  const jobs = extractEntityList(result);
  const prev = await getCachedJobs(academiaEmail).catch(() => null);
  const prevJobs = extractEntityList(prev?.jobs);
  await notifyNewEntities({
    academiaEmail,
    type: "new_job",
    items: jobs,
    previousItems: prevJobs,
    idKey: "jobId",
    titleFor: () => "New Job Posted",
    bodyFor: (job) => {
      const title = job.jobTitle || job.title || "New placement opportunity";
      const company = job.companyName ? ` at ${job.companyName}` : "";
      return `${title}${company} — check the Jobs page for details.`;
    },
  });
  await cacheJobs(academiaEmail, result, jobs.length).catch(() => {});
}

/** Diff+notify+cache the notices section for one user. Shared by the section endpoint and the background poller. */
async function syncNoticesSection(academiaEmail, result) {
  const notices = extractEntityList(result);
  const prev = await getCachedNotices(academiaEmail).catch(() => null);
  const prevNotices = extractEntityList(prev?.notices);
  await notifyNewEntities({
    academiaEmail,
    type: "new_notice",
    items: notices,
    previousItems: prevNotices,
    idKey: "noticeId",
    titleFor: () => "New Notice",
    bodyFor: (notice) => {
      const title = notice.title || notice.subject || "New notice from placement cell";
      return `${title} — check the Notices page for details.`;
    },
  });
  await cacheNotices(academiaEmail, result).catch(() => {});
}

const app = express();
app.set("trust proxy", 1);
const PORT = process.env.PORT || 3001;

const MAX_USERS = 8;
const SESSION_TTL_MS = 30 * 60 * 1000;

const sessions = {};

app.use(helmet({ contentSecurityPolicy: false }));

// CORS — restrict to allowed origins in production
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || "").split(",").map(s => s.trim()).filter(Boolean);
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.length === 0 || ALLOWED_ORIGINS.includes(origin) ||
        /^https?:\/\/(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.|localhost)/.test(origin)) {
      return cb(null, true);
    }
    return cb(new Error(`CORS: origin not allowed — ${origin}`));
  },
  credentials: true,
}));

app.use(express.json({ limit: "2mb" }));

// Health check endpoint (public, for Render/UptimeRobot)
app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "placement-backend", timestamp: Date.now() });
});

app.use((req, res, next) => {
  res.ok = (data) => res.json({ success: true, ...data });
  res.fail = (code, message) => res.status(code).json({ success: false, error: message });
  next();
});

const loginLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: "Too many login attempts. Please try again later." },
});

const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
});

function touch(email) {
  if (sessions[email]) sessions[email].lastActive = Date.now();
}

function destroySession(email, reason) {
  if (!sessions[email]) return;
  const session = sessions[email];
  if (session.token) {
    runScraper({ mode: "logout", token: session.token, phaveloc: session.phaveloc }).catch(() => {});
  }
  delete sessions[email];
}

function activeUserCount() {
  return Object.keys(sessions).filter((e) => sessions[e]).length;
}

function requireAuth(req, res, next) {
  const email = req.headers["x-user-email"];
  if (!email || !sessions[email]) {
    return res.fail(401, "Not authenticated. Please login.");
  }
  touch(email);
  req.email = email;
  req.session = sessions[email];
  next();
}

setInterval(() => {
  const now = Date.now();
  for (const email of Object.keys(sessions)) {
    if (now - sessions[email].lastActive > SESSION_TTL_MS) {
      destroySession(email, "expired");
    }
  }
}, 60 * 1000);

app.post("/login", loginLimiter, async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.fail(400, "username and password are required");
  }

  if (activeUserCount() >= MAX_USERS) {
    return res.fail(503, "Server is at maximum capacity. Please try again later.");
  }

  const sessionKey = username;

  try {
    const { parsed } = await runScraper({
      mode: "login",
      username,
      password,
    });

    if (!parsed.success) {
      return res.fail(500, parsed.error || "Login failed");
    }

    if (parsed.requiresMfa) {
      return res.ok({
        requiresMfa: true,
        mfaToken: parsed.mfaToken,
        publicUrl: parsed.publicUrl,
      });
    }

    sessions[sessionKey] = {
      token: parsed.token,
      encryptedToken: parsed.encryptedToken,
      sub: parsed.sub,
      uuid: parsed.uuid,
      phaveloc: parsed.phaveloc,
      publicUrl: parsed.publicUrl,
      lastActive: Date.now(),
      cache: {},
      fetchErrors: {},
    };

    return res.ok({
      message: "Login successful",
      username: sessionKey,
    });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

app.post("/verify-mfa", loginLimiter, async (req, res) => {
  const { mfaToken, totpCode, emailOtp, username } = req.body;
  if (!mfaToken) {
    return res.fail(400, "mfaToken is required");
  }
  if (!totpCode && !emailOtp) {
    return res.fail(400, "totpCode or emailOtp is required");
  }

  try {
    const { parsed } = await runScraper({
      mode: "verify_mfa",
      mfaToken,
      totpCode,
      emailOtp,
    });

    if (!parsed.success) {
      return res.fail(500, parsed.error || "MFA verification failed");
    }

    const sessionKey = username || "mfa_user";

    sessions[sessionKey] = {
      token: parsed.token,
      encryptedToken: parsed.encryptedToken,
      sub: parsed.sub,
      uuid: parsed.uuid,
      phaveloc: parsed.phaveloc,
      publicUrl: parsed.publicUrl,
      lastActive: Date.now(),
      cache: {},
      fetchErrors: {},
    };

    return res.ok({
      message: "MFA verification successful",
      username: sessionKey,
    });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

app.post("/send-mfa-email", loginLimiter, async (req, res) => {
  const { mfaToken } = req.body;
  if (!mfaToken) {
    return res.fail(400, "mfaToken is required");
  }

  try {
    const { parsed } = await runScraper({ mode: "send_mfa", mfaToken });
    if (!parsed.success) {
      return res.fail(500, parsed.error || "Failed to send MFA email");
    }
    return res.ok({ message: "Verification code sent to your registered email." });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

app.post("/logout", requireAuth, async (req, res) => {
  destroySession(req.email, "user_logout");
  return res.ok({ message: "Logged out successfully" });
});

app.get("/status", requireAuth, (req, res) => {
  res.ok({
    username: req.email,
    lastActive: req.session.lastActive,
    cachedSections: Object.keys(req.session.cache),
  });
});

async function hydrateSections(email, sections, extra = {}) {
  const session = sessions[email];
  if (!session) {
    const err = new Error("No session");
    err.expired = true;
    throw err;
  }
  touch(email);

  const missing = sections.filter((s) => !session.cache[s] && !session.fetchErrors?.[s]);
  if (missing.length === 0) {
    return sections.reduce((acc, s) => {
      if (session.cache[s]) {
        acc[s] = session.cache[s];
      } else if (session.fetchErrors?.[s]) {
        acc[s] = { error: session.fetchErrors[s] };
      }
      return acc;
    }, {});
  }

  if (session.fetchPromise) {
    await session.fetchPromise;
    return hydrateSections(email, sections, extra);
  }

  session.fetchPromise = (async () => {
    try {
      const { parsed } = await runScraper({
        mode: "fetch",
        token: session.token,
        phaveloc: session.phaveloc,
        sections: missing,
        ...extra,
      });

      if (!parsed.success) {
        throw new Error(parsed.error || "Fetch failed");
      }

      if (parsed.sections) {
        if (!session.fetchErrors) session.fetchErrors = {};
        for (const [section, data] of Object.entries(parsed.sections)) {
          if (data && data.error) {
            if (data.error.includes("authentication expired")) {
              destroySession(email, "expired");
              const err = new Error("Session expired. Please login again.");
              err.expired = true;
              throw err;
            }
            // Store error but don't cache — allow retry on explicit refresh
            session.fetchErrors[section] = data.error;
            continue;
          }
          session.cache[section] = data;
          delete session.fetchErrors[section];
        }
      }
    } finally {
      delete session.fetchPromise;
    }
  })();

  await session.fetchPromise;
  return hydrateSections(email, sections, extra);
}

function makeSectionEndpoint(sectionName, extraParams = {}) {
  return async (req, res) => {
    const academiaEmail = req.headers["x-academia-email"];
    try {
      const data = await hydrateSections(req.email, [sectionName], {
        ...extraParams,
        uuid: req.session.uuid,
        page: req.query.page ? parseInt(req.query.page) : 0,
        size: req.query.size ? parseInt(req.query.size) : 0,
        sort: req.query.sort || "",
        startDate: req.query.startDate || "",
        endDate: req.query.endDate || "",
        filters: req.body.filters || [],
      });
      const result = data[sectionName];

      // Cache + notify (must read previous cache BEFORE overwrite)
      if (academiaEmail && result && !result.error) {
        setImmediate(async () => {
          try {
            if (sectionName === "profile") {
              await cachePlacementProfile(academiaEmail, req.email, result).catch(() => {});
            } else if (sectionName === "jobs") {
              await syncJobsSection(academiaEmail, result);
            } else if (sectionName === "tracker") {
              await cacheApplications(academiaEmail, result).catch(() => {});
            } else if (sectionName === "notices") {
              await syncNoticesSection(academiaEmail, result);
            } else if (sectionName === "companies") {
              await cacheCompanies(academiaEmail, result).catch(() => {});
            }
          } catch (err) {
            console.error("[notifications] Section cache/notif error:", err.message);
          }
        });
      }

      return res.ok({ data: result });
    } catch (err) {
      // Fallback: try Supabase cache before returning error
      if (academiaEmail) {
        try {
          let cached = null;
          if (sectionName === "profile") {
            cached = await getCachedPlacementProfile(academiaEmail).catch(() => null);
            if (cached?.profile_data) {
              console.log(`[cache] Returning cached profile from Supabase for ${academiaEmail}`);
              return res.ok({ data: cached.profile_data, fromCache: true });
            }
          } else if (sectionName === "jobs") {
            cached = await getCachedJobs(academiaEmail).catch(() => null);
            if (cached?.jobs) {
              console.log(`[cache] Returning cached jobs from Supabase for ${academiaEmail}`);
              return res.ok({ data: cached.jobs, fromCache: true });
            }
          } else if (sectionName === "tracker") {
            cached = await getCachedApplications(academiaEmail).catch(() => null);
            if (cached?.applications) {
              console.log(`[cache] Returning cached applications from Supabase for ${academiaEmail}`);
              return res.ok({ data: cached.applications, fromCache: true });
            }
          } else if (sectionName === "notices") {
            cached = await getCachedNotices(academiaEmail).catch(() => null);
            if (cached?.notices) {
              console.log(`[cache] Returning cached notices from Supabase for ${academiaEmail}`);
              return res.ok({ data: cached.notices, fromCache: true });
            }
          } else if (sectionName === "companies") {
            cached = await getCachedCompanies(academiaEmail).catch(() => null);
            if (cached?.companies) {
              console.log(`[cache] Returning cached companies from Supabase for ${academiaEmail}`);
              return res.ok({ data: cached.companies, fromCache: true });
            }
          }
        } catch (_) {}
      }
      if (err.expired) return res.fail(401, err.message);
      return res.fail(500, err.message);
    }
  };
}

app.get("/companies", requireAuth, apiLimiter, makeSectionEndpoint("companies"));
app.get("/jobs", requireAuth, apiLimiter, makeSectionEndpoint("jobs"));
app.get("/tracker", requireAuth, apiLimiter, makeSectionEndpoint("tracker"));
app.get("/profile", requireAuth, apiLimiter, makeSectionEndpoint("profile"));
app.get("/notices", requireAuth, apiLimiter, makeSectionEndpoint("notices"));
app.get("/policies", requireAuth, apiLimiter, makeSectionEndpoint("policies"));
app.get("/global-policy", requireAuth, apiLimiter, makeSectionEndpoint("globalPolicy"));
app.get("/calendar", requireAuth, apiLimiter, makeSectionEndpoint("calendar"));
app.get("/insights", requireAuth, apiLimiter, makeSectionEndpoint("insights"));
app.get("/student-stats", requireAuth, apiLimiter, makeSectionEndpoint("studentStats"));
app.get("/placement-cycles", requireAuth, apiLimiter, makeSectionEndpoint("placementCycles"));
app.get("/social-media", requireAuth, apiLimiter, makeSectionEndpoint("socialMedia"));
app.get("/chat-inbox", requireAuth, apiLimiter, makeSectionEndpoint("chatInbox"));
app.get("/chat-unread", requireAuth, apiLimiter, makeSectionEndpoint("chatUnread"));

app.get("/jobView/:jobUuid", requireAuth, apiLimiter, async (req, res) => {
  const { jobUuid } = req.params;
  if (!jobUuid) return res.fail(400, "jobUuid is required");
  try {
    const { parsed } = await runScraper({
      mode: "fetch",
      token: req.session.token,
      phaveloc: req.session.phaveloc,
      sections: ["jobView"],
      jobUuid,
    });
    if (!parsed.success) return res.fail(500, parsed.error || "Fetch failed");
    const data = parsed.sections?.jobView;
    if (data && data.error) return res.fail(500, data.error);
    return res.ok({ data });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

app.get("/jobAttachments/:jobUuid", requireAuth, apiLimiter, async (req, res) => {
  const { jobUuid } = req.params;
  if (!jobUuid) return res.fail(400, "jobUuid is required");
  try {
    const { parsed } = await runScraper({
      mode: "fetch",
      token: req.session.token,
      phaveloc: req.session.phaveloc,
      sections: ["jobAttachments"],
      jobUuid,
    });
    if (!parsed.success) return res.fail(500, parsed.error || "Fetch failed");
    const data = parsed.sections?.jobAttachments;
    if (data && data.error) return res.fail(500, data.error);
    return res.ok({ data });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

app.get("/probeAttendance", requireAuth, apiLimiter, async (req, res) => {
  try {
    const { parsed } = await runScraper({
      mode: "fetch",
      token: req.session.token,
      phaveloc: req.session.phaveloc,
      sections: ["probeAttendance"],
      uuid: req.session.uuid,
      jobUuid: req.query.jobUuid || "",
    });
    if (!parsed.success) return res.fail(500, parsed.error || "Probe failed");
    const data = parsed.sections?.probeAttendance;
    if (data && data.error) return res.fail(500, data.error);
    return res.ok({ data });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

app.get("/all", requireAuth, apiLimiter, async (req, res) => {
  try {
    const allSections = [
      "companies", "jobs", "tracker", "profile", "notices",
      "policies", "globalPolicy", "calendar", "insights",
      "studentStats", "placementCycles", "socialMedia",
    ];
    const data = await hydrateSections(req.email, allSections, {
      uuid: req.session.uuid,
    });
    return res.ok({ data });
  } catch (err) {
    if (err.expired) return res.fail(401, err.message);
    return res.fail(500, err.message);
  }
});

app.post("/refresh", requireAuth, (req, res) => {
  const { section } = req.body;
  if (section) {
    delete req.session.cache[section];
    delete req.session.fetchErrors?.[section];
  } else {
    req.session.cache = {};
    req.session.fetchErrors = {};
  }
  return res.ok({ message: "Cache cleared" });
});

app.get("/jd", requireAuth, async (req, res) => {
  const session = req.session;
  const { fileUrl, jobUuid } = req.query;

  console.log("[JD] fileUrl:", fileUrl, "jobUuid:", jobUuid);
  console.log("[JD] session.token exists:", !!session.token, "phaveloc:", session.phaveloc);

  if (!fileUrl && !jobUuid) {
    return res.fail(400, "fileUrl or jobUuid query parameter is required");
  }

  try {
    const { parsed: result, stderr } = await runScraper({
      mode: "jd",
      token: session.token,
      phaveloc: session.phaveloc,
      fileUrl: fileUrl || "",
      jobUuid: jobUuid || "",
    });

    console.log("[JD] scraper response:", JSON.stringify({ success: result.success, error: result.error, hasFileData: !!result.fileData, fileName: result.fileName, contentType: result.contentType }));
    console.log("[JD] stderr:", stderr);

    if (!result.success || !result.fileData) {
      return res.fail(500, result.error || "File download failed");
    }

    const fileBuffer = Buffer.from(result.fileData, "base64");
    res.setHeader("Content-Type", result.contentType || "application/octet-stream");
    res.setHeader("Content-Disposition", `attachment; filename="${result.fileName || "attachment"}"`);
    res.send(fileBuffer);
  } catch (err) {
    console.error("[JD] error:", err.message);
    return res.fail(500, `Error fetching file: ${err.message}`);
  }
});

app.get("/captcha-info", (req, res) => {
  res.ok({
    sitekey: "6LdWmBMhAAAAAHT3bLTH6JDQ9MatcSw0WzY5zogx",
    type: "reCAPTCHA_v2",
    note: "Captcha is frontend-only on Haveloc. It gates the login page route but is NOT sent to the server API. The /sign-in endpoint does not require a captcha token.",
  });
});

// ─── Job Application ─────────────────────────────────────────────────────────

app.get("/resumes", requireAuth, apiLimiter, async (req, res) => {
  try {
    const { parsed } = await runScraper({
      mode: "fetch",
      token: req.session.token,
      phaveloc: req.session.phaveloc,
      sections: ["studentDocuments"],
      uuid: req.session.uuid,
    });
    if (!parsed.success) return res.fail(500, parsed.error || "Fetch failed");
    const data = parsed.sections?.studentDocuments;
    if (data && data.error) return res.fail(500, data.error);
    return res.ok({ data });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

app.post("/apply", requireAuth, apiLimiter, async (req, res) => {
  const { jobUuid, jobId, answers, resumeName } = req.body;
  if (!jobUuid) return res.fail(400, "jobUuid is required");
  if (!resumeName) return res.fail(400, "resumeName is required");

  try {
    const { parsed } = await runScraper({
      mode: "apply",
      token: req.session.token,
      phaveloc: req.session.phaveloc,
      jobUuid,
      jobId: jobId || 0,
      applyAnswers: answers || [],
      resumeName,
    });

    if (!parsed.success) {
      return res.fail(500, parsed.error || "Application failed");
    }

    // Invalidate tracker cache so next fetch shows updated status
    delete req.session.cache.tracker;
    delete req.session.fetchErrors?.tracker;

    return res.ok({ data: parsed.data });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

// ─── Placement Credential Storage (Supabase) ─────────────────────────────────
// These endpoints allow one-time connect + auto-login for placement accounts.

/**
 * POST /connect
 * Body: { academiaEmail, username, password }
 * Attempts placement login, stores encrypted credentials in Supabase on success.
 */
app.post("/connect", loginLimiter, async (req, res) => {
  const { academiaEmail, username, password } = req.body;
  if (!academiaEmail || !username || !password) {
    return res.fail(400, "academiaEmail, username, and password are required");
  }
  if (!supabase) {
    return res.fail(503, "Credential storage is not configured (Supabase not set up)");
  }

  try {
    // Attempt login via scraper
    const { parsed } = await runScraper({ mode: "login", username, password });

    if (!parsed.success) {
      return res.fail(500, parsed.error || "Placement login failed");
    }

    if (parsed.requiresMfa) {
      // Store creds even if MFA required — auto-login will need MFA step
      const encrypted = encryptPassword(password);
      await storeCredentials({
        academiaEmail,
        placementUsername: username,
        encryptedPassword: encrypted,
        hasMfa: true,
      });
      return res.ok({
        requiresMfa: true,
        mfaToken: parsed.mfaToken,
        message: "MFA required. Credentials stored for future auto-login.",
      });
    }

    // Login succeeded — store encrypted credentials
    const encrypted = encryptPassword(password);
    await storeCredentials({
      academiaEmail,
      placementUsername: username,
      encryptedPassword: encrypted,
      hasMfa: false,
    });

    // Create session
    const sessionKey = username;
    sessions[sessionKey] = {
      token: parsed.token,
      encryptedToken: parsed.encryptedToken,
      sub: parsed.sub,
      uuid: parsed.uuid,
      phaveloc: parsed.phaveloc,
      publicUrl: parsed.publicUrl,
      lastActive: Date.now(),
      cache: {},
      fetchErrors: {},
    };

    // Set cooldown so subsequent auto-login calls don't hit Haveloc again
    autoLoginCooldown.set(academiaEmail, Date.now());

    return res.ok({
      message: "Placement account connected successfully",
      username: sessionKey,
    });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

/**
 * POST /auto-login
 * Body: { academiaEmail }
 * Looks up stored credentials and silently logs in.
 * Cooldown: 5 minutes per email to avoid Haveloc rate limits.
 */
const autoLoginCooldown = new Map(); // email → timestamp
const AUTO_LOGIN_COOLDOWN_MS = 5 * 60 * 1000; // 5 minutes

app.post("/auto-login", loginLimiter, async (req, res) => {
  const { academiaEmail } = req.body;
  if (!academiaEmail) {
    return res.fail(400, "academiaEmail is required");
  }
  if (!supabase) {
    return res.ok({ connected: false, notConfigured: true });
  }

  // Check cooldown — if we recently attempted auto-login, skip
  const lastAttempt = autoLoginCooldown.get(academiaEmail);
  const now = Date.now();
  if (lastAttempt && (now - lastAttempt) < AUTO_LOGIN_COOLDOWN_MS) {
    // Check if we already have a valid session
    const creds = await getCredentials(academiaEmail);
    if (creds && creds.auto_login_enabled) {
      const sessionKey = creds.placement_username;
      if (sessions[sessionKey]) {
        return res.ok({ connected: true, username: sessionKey, cached: true });
      }
    }
    return res.ok({ connected: false, cooldown: true });
  }

  // Record this attempt
  autoLoginCooldown.set(academiaEmail, now);

  try {
    const creds = await getCredentials(academiaEmail);
    if (!creds || !creds.auto_login_enabled) {
      return res.ok({ connected: false });
    }

    // If we already have a valid session, don't hit Haveloc again
    const existingSessionKey = creds.placement_username;
    if (sessions[existingSessionKey]) {
      sessions[existingSessionKey].lastActive = Date.now();
      return res.ok({ connected: true, username: existingSessionKey, cached: true });
    }

    // Decrypt password and attempt login
    const password = decryptPassword(creds.encrypted_password);
    const { parsed } = await runScraper({
      mode: "login",
      username: creds.placement_username,
      password,
    });

    if (!parsed.success) {
      // Password may have changed — return not connected so user can re-connect
      return res.ok({ connected: false, error: parsed.error || "Auto-login failed" });
    }

    if (parsed.requiresMfa) {
      return res.ok({
        connected: true,
        requiresMfa: true,
        mfaToken: parsed.mfaToken,
        username: creds.placement_username,
      });
    }

    // Login succeeded — create session
    const sessionKey = creds.placement_username;
    sessions[sessionKey] = {
      token: parsed.token,
      encryptedToken: parsed.encryptedToken,
      sub: parsed.sub,
      uuid: parsed.uuid,
      phaveloc: parsed.phaveloc,
      publicUrl: parsed.publicUrl,
      lastActive: Date.now(),
      cache: {},
      fetchErrors: {},
    };

    // Update last_auto_login timestamp
    await updateAutoLoginStatus(academiaEmail);

    return res.ok({
      connected: true,
      username: sessionKey,
    });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

/**
 * POST /disconnect
 * Body: { academiaEmail }
 * Removes stored credentials from Supabase and destroys session.
 */
app.post("/disconnect", async (req, res) => {
  const { academiaEmail } = req.body;
  if (!academiaEmail) {
    return res.fail(400, "academiaEmail is required");
  }

  try {
    // Get creds to find username for session destruction
    const creds = await getCredentials(academiaEmail);
    if (creds) {
      destroySession(creds.placement_username, "user_disconnect");
      await removeCredentials(academiaEmail);
    }
    return res.ok({ message: "Placement account disconnected" });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

/**
 * GET /connection-status
 * Header: x-academia-email
 * Returns whether the user has stored placement credentials.
 */
app.get("/connection-status", async (req, res) => {
  const academiaEmail = req.headers["x-academia-email"];
  if (!academiaEmail) {
    return res.fail(400, "x-academia-email header is required");
  }
  if (!supabase) {
    return res.ok({ connected: false, notConfigured: true });
  }

  try {
    const creds = await getCredentials(academiaEmail);
    if (!creds) {
      return res.ok({ connected: false });
    }
    return res.ok({
      connected: true,
      username: creds.placement_username,
      hasMfa: creds.has_mfa,
      autoLoginEnabled: creds.auto_login_enabled,
      connectedAt: creds.connected_at,
      lastAutoLogin: creds.last_auto_login,
    });
  } catch (err) {
    return res.fail(500, err.message);
  }
});

/**
 * Background poller — checks jobs/notices for every user with auto-login
 * enabled, so notifications fire without the user having to open the
 * Jobs/Notices page. Runs sequentially with a delay between users to
 * avoid bursting the upstream Haveloc portal.
 */
const POLL_INTERVAL_MS = 20 * 60 * 1000; // 20 minutes
const POLL_USER_DELAY_MS = 4 * 1000; // stagger requests to upstream portal

let pollInProgress = false;

async function pollUserJobsAndNotices(cred) {
  const academiaEmail = cred.academia_email;
  const username = cred.placement_username;

  let session = sessions[username];
  if (!session) {
    if (cred.has_mfa) return; // can't silently auto-login MFA accounts
    const password = decryptPassword(cred.encrypted_password);
    const { parsed } = await runScraper({ mode: "login", username, password });
    if (!parsed.success || parsed.requiresMfa) return;
    session = sessions[username] = {
      token: parsed.token,
      encryptedToken: parsed.encryptedToken,
      sub: parsed.sub,
      uuid: parsed.uuid,
      phaveloc: parsed.phaveloc,
      publicUrl: parsed.publicUrl,
      lastActive: Date.now(),
      cache: {},
      fetchErrors: {},
    };
    await updateAutoLoginStatus(academiaEmail).catch(() => {});
  } else {
    session.lastActive = Date.now();
  }

  // Force a fresh upstream fetch instead of serving the in-memory cache.
  delete session.cache.jobs;
  delete session.cache.notices;
  delete session.fetchErrors?.jobs;
  delete session.fetchErrors?.notices;

  const data = await hydrateSections(username, ["jobs", "notices"], { uuid: session.uuid });

  if (data.jobs && !data.jobs.error) {
    await syncJobsSection(academiaEmail, data.jobs);
  }
  if (data.notices && !data.notices.error) {
    await syncNoticesSection(academiaEmail, data.notices);
  }
}

async function pollAllUsersForNewPostings() {
  if (pollInProgress || !supabase) return;
  pollInProgress = true;
  try {
    const creds = await getAllAutoLoginCredentials();
    for (const cred of creds) {
      try {
        await pollUserJobsAndNotices(cred);
      } catch (err) {
        console.error(`[poll] failed for ${cred.academia_email}:`, err.message);
      }
      await new Promise((resolve) => setTimeout(resolve, POLL_USER_DELAY_MS));
    }
  } catch (err) {
    console.error("[poll] pollAllUsersForNewPostings failed:", err.message);
  } finally {
    pollInProgress = false;
  }
}

setInterval(() => {
  pollAllUsersForNewPostings();
}, POLL_INTERVAL_MS);
// First pass shortly after boot so notifications don't wait a full interval.
setTimeout(() => {
  pollAllUsersForNewPostings();
}, 30 * 1000);

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Placement backend running on http://0.0.0.0:${PORT}`);
});
