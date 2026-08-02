require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { runScraper } = require("../integrations/go/go_scraper_client");
const { encryptPassword, decryptPassword } = require("../utils/crypto");
const { storeCredentials, getCredentials, removeCredentials, updateAutoLoginStatus, supabase } = require("../utils/supabaseClient");

const app = express();
const PORT = process.env.PORT || 3001;

const MAX_USERS = 8;
const SESSION_TTL_MS = 30 * 60 * 1000;

const sessions = {};

app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: true, credentials: true }));
app.use(express.json({ limit: "2mb" }));

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
      return res.ok({ data: data[sectionName] });
    } catch (err) {
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
 */
app.post("/auto-login", loginLimiter, async (req, res) => {
  const { academiaEmail } = req.body;
  if (!academiaEmail) {
    return res.fail(400, "academiaEmail is required");
  }
  if (!supabase) {
    return res.ok({ connected: false, notConfigured: true });
  }

  try {
    const creds = await getCredentials(academiaEmail);
    if (!creds || !creds.auto_login_enabled) {
      return res.ok({ connected: false });
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

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Placement backend running on http://0.0.0.0:${PORT}`);
});
