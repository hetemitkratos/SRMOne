/**
 * Placement Sync Edge Function
 *
 * Triggered by pg_cron every 5 minutes. Fetches fresh data from Haveloc
 * for all connected users and stores it in Supabase cache tables.
 *
 * Per the architecture guide:
 * - Haveloc jobs are global (one canonical table, not per-user copies)
 * - User-specific data (tracker, profile, stats) is stored per-user
 * - Students read from DB cache, never trigger scrapers directly
 *
 * Uses chunked self-invocation to stay within Edge Function time limits.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  HavelocClientAsync,
  login,
  fetchSection,
} from "../_shared/haveloc-client.ts";
import { decryptPassword } from "../_shared/crypto.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const CREDS_TABLE = "placement_credentials";
const SYNC_STATUS_TABLE = "placement_sync_status";

// Cache tables
const GLOBAL_TABLES = {
  jobs: "placement_jobs_cache",
  companies: "placement_companies_cache",
  notices: "placement_notices_cache",
  policies: "placement_policies_cache",
  globalPolicy: "placement_global_policy_cache",
  calendar: "placement_calendar_cache",
  insights: "placement_insights_cache",
} as const;

const USER_TABLES = {
  profile: "placement_profile_cache",
  tracker: "placement_tracker_cache",
  applications: "placement_applications_cache",
  studentStats: "placement_student_stats_cache",
  socialMedia: "placement_social_media_cache",
  studentDocuments: "placement_student_documents_cache",
  chatInbox: "placement_chat_inbox_cache",
  chatUnread: "placement_chat_unread_cache",
} as const;

const CHUNK_SIZE = 3; // users per invocation

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ─── Auth check ──────────────────────────────────────────────────────────────

function checkAuth(req: Request): boolean {
  const authHeader = req.headers.get("Authorization");
  const cronSecret = req.headers.get("X-Cron-Secret");
  const expectedSecret = Deno.env.get("CRON_SECRET");

  if (expectedSecret && cronSecret === expectedSecret) return true;
  if (authHeader === `Bearer ${supabaseKey}`) return true;

  return false;
}

// ─── Sync logic ──────────────────────────────────────────────────────────────

interface SyncUser {
  academia_email: string;
  placement_username: string;
  encrypted_password: string;
  has_mfa: boolean;
  auto_login_enabled: boolean;
}

async function syncUser(user: SyncUser): Promise<{ success: boolean; sections: number; error?: string }> {
  if (user.has_mfa) {
    return { success: false, sections: 0, error: "MFA users require manual login" };
  }

  let password: string;
  try {
    password = await decryptPassword(user.encrypted_password);
  } catch {
    return { success: false, sections: 0, error: "Failed to decrypt password" };
  }

  const client = new HavelocClientAsync();

  try {
    const loginResult = await login(client, user.placement_username, password);
    if (loginResult.requiresMfa) {
      return { success: false, sections: 0, error: "MFA required" };
    }

    await client.setAuth(loginResult.token, loginResult.phaveloc);

    let sectionsFetched = 0;
    const uuid = loginResult.uuid;

    // ─── Global sections (only fetch from first user in chunk to avoid duplicates) ──
    // Global data is fetched once per sync cycle, not per user.
    // The first user in the chunk fetches global data.

    // ─── User-specific sections ──────────────────────────────────────────────
    if (uuid) {
      // Profile
      try {
        const profile = await fetchSection(client, "profile", { uuid });
        await supabase.from(USER_TABLES.profile).upsert({
          academia_email: user.academia_email,
          data: profile,
          updated_at: new Date().toISOString(),
        }, { onConflict: "academia_email" });
        sectionsFetched++;
      } catch (e) { console.error(`[sync] profile failed for ${user.academia_email}:`, (e as Error).message); }

      // Job tracker
      try {
        const tracker = await fetchSection(client, "tracker", { uuid });
        await supabase.from(USER_TABLES.tracker).upsert({
          academia_email: user.academia_email,
          data: tracker,
          updated_at: new Date().toISOString(),
        }, { onConflict: "academia_email" });
        sectionsFetched++;
      } catch (e) { console.error(`[sync] tracker failed:`, (e as Error).message); }

      // Student stats
      try {
        const stats = await fetchSection(client, "studentStats", { uuid });
        await supabase.from(USER_TABLES.studentStats).upsert({
          academia_email: user.academia_email,
          data: stats,
          updated_at: new Date().toISOString(),
        }, { onConflict: "academia_email" });
        sectionsFetched++;
      } catch (e) { console.error(`[sync] studentStats failed:`, (e as Error).message); }

      // Social media
      try {
        const social = await fetchSection(client, "socialMedia", { uuid });
        await supabase.from(USER_TABLES.socialMedia).upsert({
          academia_email: user.academia_email,
          data: social,
          updated_at: new Date().toISOString(),
        }, { onConflict: "academia_email" });
        sectionsFetched++;
      } catch (e) { console.error(`[sync] socialMedia failed:`, (e as Error).message); }

      // Student documents
      try {
        const docs = await fetchSection(client, "studentDocuments", { uuid });
        await supabase.from(USER_TABLES.studentDocuments).upsert({
          academia_email: user.academia_email,
          data: docs,
          updated_at: new Date().toISOString(),
        }, { onConflict: "academia_email" });
        sectionsFetched++;
      } catch (e) { console.error(`[sync] studentDocuments failed:`, (e as Error).message); }

      // Chat inbox
      try {
        const inbox = await fetchSection(client, "chatInbox", {});
        await supabase.from(USER_TABLES.chatInbox).upsert({
          academia_email: user.academia_email,
          data: inbox,
          updated_at: new Date().toISOString(),
        }, { onConflict: "academia_email" });
        sectionsFetched++;
      } catch (e) { console.error(`[sync] chatInbox failed:`, (e as Error).message); }

      // Chat unread
      try {
        const unread = await fetchSection(client, "chatUnread", {});
        await supabase.from(USER_TABLES.chatUnread).upsert({
          academia_email: user.academia_email,
          data: unread,
          updated_at: new Date().toISOString(),
        }, { onConflict: "academia_email" });
        sectionsFetched++;
      } catch (e) { console.error(`[sync] chatUnread failed:`, (e as Error).message); }
    }

    // Update last_auto_login
    await supabase.from(CREDS_TABLE)
      .update({ last_auto_login: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq("academia_email", user.academia_email);

    return { success: sectionsFetched > 0, sections: sectionsFetched };
  } catch (err) {
    const msg = (err as Error).message;
    console.error(`[sync] User ${user.academia_email} failed:`, msg);
    return { success: false, sections: 0, error: msg };
  }
}

async function syncGlobalData(client: HavelocClientAsync): Promise<number> {
  let sections = 0;

  // Jobs (global)
  try {
    const jobs = await fetchSection(client, "jobs", {});
    await supabase.from(GLOBAL_TABLES.jobs).upsert({
      id: "global",
      data: jobs,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });
    sections++;
  } catch (e) { console.error("[sync] jobs failed:", (e as Error).message); }

  // Companies (global)
  try {
    const companies = await fetchSection(client, "companies", {});
    await supabase.from(GLOBAL_TABLES.companies).upsert({
      id: "global",
      data: companies,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });
    sections++;
  } catch (e) { console.error("[sync] companies failed:", (e as Error).message); }

  // Notices (global)
  try {
    const notices = await fetchSection(client, "notices", {});
    await supabase.from(GLOBAL_TABLES.notices).upsert({
      id: "global",
      data: notices,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });
    sections++;
  } catch (e) { console.error("[sync] notices failed:", (e as Error).message); }

  // Policies (global)
  try {
    const policies = await fetchSection(client, "policies", {});
    await supabase.from(GLOBAL_TABLES.policies).upsert({
      id: "global",
      data: policies,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });
    sections++;
  } catch (e) { console.error("[sync] policies failed:", (e as Error).message); }

  // Global policy
  try {
    const gp = await fetchSection(client, "globalPolicy", {});
    await supabase.from(GLOBAL_TABLES.globalPolicy).upsert({
      id: "global",
      data: gp,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });
    sections++;
  } catch (e) { console.error("[sync] globalPolicy failed:", (e as Error).message); }

  // Calendar (global)
  try {
    const calendar = await fetchSection(client, "calendar", {});
    await supabase.from(GLOBAL_TABLES.calendar).upsert({
      id: "global",
      data: calendar,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });
    sections++;
  } catch (e) { console.error("[sync] calendar failed:", (e as Error).message); }

  // Insights (global)
  try {
    const insights = await fetchSection(client, "insights", {});
    await supabase.from(GLOBAL_TABLES.insights).upsert({
      id: "global",
      data: insights,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });
    sections++;
  } catch (e) { console.error("[sync] insights failed:", (e as Error).message); }

  return sections;
}

// ─── Main handler ────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Cron-Secret",
      },
    });
  }

  if (!checkAuth(req)) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json().catch(() => ({}));
    const offset = body.offset || 0;
    const fetchGlobal = body.fetchGlobal !== false; // default true for first chunk

    // Fetch chunk of connected users
    const { data: users, error } = await supabase
      .from(CREDS_TABLE)
      .select("*")
      .eq("auto_login_enabled", true)
      .order("academia_email")
      .range(offset, offset + CHUNK_SIZE - 1);

    if (error) {
      return json({ success: false, error: error.message }, 500);
    }

    if (!users || users.length === 0) {
      // No more users — record sync status
      await supabase.from(SYNC_STATUS_TABLE).insert({
        last_run: new Date().toISOString(),
        success: true,
        users_processed: offset,
        message: "Sync cycle complete",
      });

      return json({ success: true, message: "Sync cycle complete", usersProcessed: offset });
    }

    // Fetch global data from first user's session
    let globalSections = 0;
    if (fetchGlobal && users.length > 0) {
      const firstUser = users[0];
      if (!firstUser.has_mfa) {
        try {
          const password = await decryptPassword(firstUser.encrypted_password);
          const client = new HavelocClientAsync();
          const loginResult = await login(client, firstUser.placement_username, password);
          if (!loginResult.requiresMfa) {
            await client.setAuth(loginResult.token, loginResult.phaveloc);
            globalSections = await syncGlobalData(client);
          }
        } catch (e) {
          console.error("[sync] Global data fetch failed:", (e as Error).message);
        }
      }
    }

    // Sync each user
    const results: Array<{ email: string; success: boolean; sections: number; error?: string }> = [];
    for (const user of users) {
      const result = await syncUser(user);
      results.push({
        email: user.academia_email,
        success: result.success,
        sections: result.sections,
        error: result.error,
      });
    }

    const successCount = results.filter((r) => r.success).length;

    // Self-invoke for next chunk
    const nextOffset = offset + CHUNK_SIZE;
    const functionUrl = `${supabaseUrl}/functions/v1/placement-sync`;
    try {
      await fetch(functionUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${supabaseKey}`,
        },
        body: JSON.stringify({ offset: nextOffset, fetchGlobal: false }),
      });
    } catch (e) {
      console.error("[sync] Self-invocation failed:", (e as Error).message);
    }

    return json({
      success: true,
      offset,
      usersProcessed: users.length,
      successCount,
      globalSections,
      results,
      nextOffset,
    });
  } catch (err) {
    console.error("[sync] Fatal error:", (err as Error).message);
    return json({ success: false, error: (err as Error).message }, 500);
  }
});
