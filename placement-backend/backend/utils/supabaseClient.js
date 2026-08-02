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
  removeCredentials,
  updateAutoLoginStatus,
  // Notification helpers (shared notifications table)
  createNotification,
  hasUnreadNotificationOfType,
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
