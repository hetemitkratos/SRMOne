/**
 * Supabase client for storing/retrieving encrypted placement credentials.
 * Uses the service role key — backend-only, never exposed to frontend.
 */
const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = process.env.SUPABASE_URL || "";
const supabaseKey = process.env.SUPABASE_SERVICE_KEY || "";

if (!supabaseUrl || !supabaseKey || supabaseKey === "your-service-role-key-here") {
  console.warn("[supabase] SUPABASE_URL or SUPABASE_SERVICE_KEY not configured. Credential storage disabled.");
}

const supabase = (supabaseUrl && supabaseKey && supabaseKey !== "your-service-role-key-here")
  ? createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
  : null;

const TABLE = "placement_credentials";

/**
 * Store or update placement credentials for an academia email.
 */
async function storeCredentials({ academiaEmail, placementUsername, encryptedPassword, hasMfa = false }) {
  if (!supabase) throw new Error("Supabase not configured");
  const { data, error } = await supabase
    .from(TABLE)
    .upsert(
      {
        academia_email: academiaEmail,
        placement_username: placementUsername,
        encrypted_password: encryptedPassword,
        has_mfa: hasMfa,
        connected_at: new Date().toISOString(),
        auto_login_enabled: true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "academia_email" }
    )
    .select()
    .single();
  if (error) throw new Error(`Supabase store error: ${error.message}`);
  return data;
}

/**
 * Get stored credentials for an academia email.
 * Returns null if not found.
 */
async function getCredentials(academiaEmail) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from(TABLE)
    .select("*")
    .eq("academia_email", academiaEmail)
    .single();
  if (error) {
    if (error.code === "PGRST116") return null; // no rows
    throw new Error(`Supabase get error: ${error.message}`);
  }
  return data;
}

/**
 * Remove stored credentials for an academia email.
 */
async function removeCredentials(academiaEmail) {
  if (!supabase) return;
  const { error } = await supabase
    .from(TABLE)
    .delete()
    .eq("academia_email", academiaEmail);
  if (error) throw new Error(`Supabase delete error: ${error.message}`);
}

/**
 * List all credentials with auto-login enabled — used by the background
 * poller to check for new jobs/notices without waiting for the user to
 * open the app.
 */
async function getAllAutoLoginCredentials() {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from(TABLE)
    .select("academia_email, placement_username, encrypted_password, has_mfa")
    .eq("auto_login_enabled", true);
  if (error) {
    console.error("[supabase] getAllAutoLoginCredentials:", error.message);
    return [];
  }
  return data || [];
}

/**
 * Update the last_auto_login timestamp and optionally toggle auto_login_enabled.
 */
async function updateAutoLoginStatus(academiaEmail, enabled = null) {
  if (!supabase) return;
  const updates = { last_auto_login: new Date().toISOString(), updated_at: new Date().toISOString() };
  if (enabled !== null) updates.auto_login_enabled = enabled;
  const { error } = await supabase
    .from(TABLE)
    .update(updates)
    .eq("academia_email", academiaEmail);
  if (error) throw new Error(`Supabase update error: ${error.message}`);
}

module.exports = {
  supabase,
  storeCredentials,
  getCredentials,
  getAllAutoLoginCredentials,
  removeCredentials,
  updateAutoLoginStatus,
  // Notification helpers (shared notifications table)
  createNotification,
  hasUnreadNotificationOfType,
  hasNotificationForEntity,
  // Placement caching
  getCachedPlacementProfile,
  cachePlacementProfile,
  getCachedJobs,
  cacheJobs,
  getCachedApplications,
  cacheApplications,
  getCachedNotices,
  cacheNotices,
  getCachedCompanies,
  cacheCompanies,
};

// ─── Notifications (shared with academia backend) ────────────────────────────

async function createNotification(email, { type, title, body, data = {} }) {
  if (!supabase) return null;
  const { data: notif, error } = await supabase
    .from("notifications")
    .insert({ academia_email: email, type, title, body, data })
    .select()
    .single();
  if (error) console.error("[supabase] createNotification:", error.message);
  return notif;
}

async function hasUnreadNotificationOfType(email, type) {
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
 * Returns true if we already created a notification for this entity id
 * (e.g. jobId / noticeId) under the given type — prevents spam & stale repeats.
 */
async function hasNotificationForEntity(email, type, entityKey, entityId) {
  if (!supabase || entityId == null || entityId === "") return false;
  const idStr = String(entityId);
  const { data, error } = await supabase
    .from("notifications")
    .select("id, data")
    .eq("academia_email", email)
    .eq("type", type)
    .order("created_at", { ascending: false })
    .limit(40);
  if (error) {
    console.error("[supabase] hasNotificationForEntity:", error.message);
    return false;
  }
  return (data || []).some((n) => {
    const d = n.data || {};
    const candidates = [d[entityKey], d.jobId, d.jobUuid, d.noticeId, d.id].filter((v) => v != null);
    return candidates.some((v) => String(v) === idStr);
  });
}

// ─── Placement Profile Cache ─────────────────────────────────────────────────

async function getCachedPlacementProfile(academiaEmail) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("placement_profiles")
    .select("profile_data, cached_at")
    .eq("academia_email", academiaEmail)
    .maybeSingle();
  if (error) { console.error("[supabase] getCachedPlacementProfile:", error.message); return null; }
  return data;
}

async function cachePlacementProfile(academiaEmail, placementUsername, profileData) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("placement_profiles")
    .upsert({
      academia_email: academiaEmail,
      placement_username: placementUsername,
      profile_data: profileData,
      cached_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" });
  if (error) console.error("[supabase] cachePlacementProfile:", error.message);
  return null;
}

// ─── Placement Jobs Cache ────────────────────────────────────────────────────

async function getCachedJobs(academiaEmail) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("placement_jobs_cache")
    .select("jobs, total_count, cached_at")
    .eq("academia_email", academiaEmail)
    .maybeSingle();
  if (error) { console.error("[supabase] getCachedJobs:", error.message); return null; }
  return data;
}

async function cacheJobs(academiaEmail, jobs, totalCount) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("placement_jobs_cache")
    .upsert({
      academia_email: academiaEmail,
      jobs,
      total_count: totalCount,
      cached_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" });
  if (error) console.error("[supabase] cacheJobs:", error.message);
  return null;
}

// ─── Placement Applications Cache ────────────────────────────────────────────

async function getCachedApplications(academiaEmail) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("placement_applications")
    .select("applications, cached_at")
    .eq("academia_email", academiaEmail)
    .maybeSingle();
  if (error) { console.error("[supabase] getCachedApplications:", error.message); return null; }
  return data;
}

async function cacheApplications(academiaEmail, applications) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("placement_applications")
    .upsert({
      academia_email: academiaEmail,
      applications,
      cached_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" });
  if (error) console.error("[supabase] cacheApplications:", error.message);
  return null;
}

// ─── Placement Notices Cache ─────────────────────────────────────────────────

async function getCachedNotices(academiaEmail) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("placement_notices_cache")
    .select("notices, cached_at")
    .eq("academia_email", academiaEmail)
    .maybeSingle();
  if (error) { console.error("[supabase] getCachedNotices:", error.message); return null; }
  return data;
}

async function cacheNotices(academiaEmail, notices) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("placement_notices_cache")
    .upsert({
      academia_email: academiaEmail,
      notices,
      cached_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" });
  if (error) console.error("[supabase] cacheNotices:", error.message);
  return null;
}

// ─── Placement Companies Cache ───────────────────────────────────────────────

async function getCachedCompanies(academiaEmail) {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("placement_companies_cache")
    .select("companies, cached_at")
    .eq("academia_email", academiaEmail)
    .maybeSingle();
  if (error) { console.error("[supabase] getCachedCompanies:", error.message); return null; }
  return data;
}

async function cacheCompanies(academiaEmail, companies) {
  if (!supabase) return null;
  const { error } = await supabase
    .from("placement_companies_cache")
    .upsert({
      academia_email: academiaEmail,
      companies,
      cached_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, { onConflict: "academia_email" });
  if (error) console.error("[supabase] cacheCompanies:", error.message);
  return null;
}
