import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });
}

// ─── Cache table names ───────────────────────────────────────────────────────

const TABLES = {
  profile: "placement_profile_cache",
  jobs: "placement_jobs_cache",
  companies: "placement_companies_cache",
  tracker: "placement_tracker_cache",
  applications: "placement_applications_cache",
  notices: "placement_notices_cache",
  policies: "placement_policies_cache",
  globalPolicy: "placement_global_policy_cache",
  calendar: "placement_calendar_cache",
  insights: "placement_insights_cache",
  studentStats: "placement_student_stats_cache",
  socialMedia: "placement_social_media_cache",
  jobView: "placement_job_view_cache",
  jobAttachments: "placement_job_attachments_cache",
  studentDocuments: "placement_student_documents_cache",
  chatInbox: "placement_chat_inbox_cache",
  chatUnread: "placement_chat_unread_cache",
} as const;

// ─── Route handlers ──────────────────────────────────────────────────────────

async function getGlobalData(table: string, limit: number = 1000): Promise<Response> {
  const { data, error } = await supabase
    .from(table)
    .select("*")
    .order("updated_at", { ascending: false })
    .limit(limit);

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, data });
}

async function getUserData(table: string, academiaEmail: string): Promise<Response> {
  const { data, error } = await supabase
    .from(table)
    .select("*")
    .eq("academia_email", academiaEmail)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, data });
}

async function handleProfile(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);
  return getUserData(TABLES.profile, academiaEmail);
}

async function handleJobs(req: Request): Promise<Response> {
  return getGlobalData(TABLES.jobs, 500);
}

async function handleCompanies(req: Request): Promise<Response> {
  return getGlobalData(TABLES.companies, 500);
}

async function handleTracker(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);
  return getUserData(TABLES.tracker, academiaEmail);
}

async function handleApplications(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);
  return getUserData(TABLES.applications, academiaEmail);
}

async function handleNotices(req: Request): Promise<Response> {
  return getGlobalData(TABLES.notices, 200);
}

async function handlePolicies(req: Request): Promise<Response> {
  return getGlobalData(TABLES.policies, 100);
}

async function handleGlobalPolicy(req: Request): Promise<Response> {
  return getGlobalData(TABLES.globalPolicy, 1);
}

async function handleCalendar(req: Request): Promise<Response> {
  return getGlobalData(TABLES.calendar, 500);
}

async function handleInsights(req: Request): Promise<Response> {
  return getGlobalData(TABLES.insights, 1);
}

async function handleStudentStats(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);
  return getUserData(TABLES.studentStats, academiaEmail);
}

async function handleSocialMedia(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);
  return getUserData(TABLES.socialMedia, academiaEmail);
}

async function handleJobView(req: Request): Promise<Response> {
  const jobUuid = req.headers.get("x-job-uuid");
  if (!jobUuid) return json({ success: false, error: "x-job-uuid header is required" }, 400);
  const { data, error } = await supabase
    .from(TABLES.jobView)
    .select("*")
    .eq("job_uuid", jobUuid)
    .maybeSingle();
  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, data });
}

async function handleJobAttachments(req: Request): Promise<Response> {
  const jobUuid = req.headers.get("x-job-uuid");
  if (!jobUuid) return json({ success: false, error: "x-job-uuid header is required" }, 400);
  const { data, error } = await supabase
    .from(TABLES.jobAttachments)
    .select("*")
    .eq("job_uuid", jobUuid)
    .maybeSingle();
  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, data });
}

async function handleStudentDocuments(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);
  return getUserData(TABLES.studentDocuments, academiaEmail);
}

async function handleChatInbox(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);
  return getUserData(TABLES.chatInbox, academiaEmail);
}

async function handleChatUnread(req: Request): Promise<Response> {
  const academiaEmail = req.headers.get("x-academia-email");
  if (!academiaEmail) return json({ success: false, error: "x-academia-email header is required" }, 400);
  return getUserData(TABLES.chatUnread, academiaEmail);
}

async function handleSyncStatus(req: Request): Promise<Response> {
  const { data, error } = await supabase
    .from("placement_sync_status")
    .select("*")
    .order("last_run", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) return json({ success: false, error: error.message }, 500);
  return json({ success: true, data });
}

// ─── Router ──────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  let path = url.pathname.replace(/\/$/, "");
  const fnPrefix = "/functions/v1/placement-gateway";
  if (path.startsWith(fnPrefix)) path = path.slice(fnPrefix.length);
  const fnPrefix2 = "/placement-gateway";
  if (path.startsWith(fnPrefix2)) path = path.slice(fnPrefix2.length);

  const method = req.method.toUpperCase();

  if (method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, x-academia-email, x-job-uuid",
      },
    });
  }

  try {
    if (method !== "GET") return json({ error: "Method not allowed" }, 405);

    const routes: Record<string, (req: Request) => Promise<Response>> = {
      "/profile": handleProfile,
      "/jobs": handleJobs,
      "/companies": handleCompanies,
      "/tracker": handleTracker,
      "/applications": handleApplications,
      "/notices": handleNotices,
      "/policies": handlePolicies,
      "/global-policy": handleGlobalPolicy,
      "/calendar": handleCalendar,
      "/insights": handleInsights,
      "/student-stats": handleStudentStats,
      "/social-media": handleSocialMedia,
      "/job-view": handleJobView,
      "/job-attachments": handleJobAttachments,
      "/student-documents": handleStudentDocuments,
      "/chat-inbox": handleChatInbox,
      "/chat-unread": handleChatUnread,
      "/sync-status": handleSyncStatus,
    };

    const handler = routes[path];
    if (handler) return await handler(req);

    return json({ error: "Not found" }, 404);
  } catch (err) {
    return json({ success: false, error: (err as Error).message }, 500);
  }
});
