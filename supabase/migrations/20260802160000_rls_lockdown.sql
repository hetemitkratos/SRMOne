-- Migration: rls_lockdown
-- Defense-in-depth: REVOKE all access from anon and authenticated roles
-- on every user table. No Supabase Auth is used — all data access flows
-- through Edge Functions using the service role key, scoped by session token.

-- Revoke default privileges
REVOKE ALL ON public.student_profiles FROM anon, authenticated;
REVOKE ALL ON public.attendance_snapshots FROM anon, authenticated;
REVOKE ALL ON public.attendance_current FROM anon, authenticated;
REVOKE ALL ON public.academia_credentials FROM anon, authenticated;
REVOKE ALL ON public.placement_credentials FROM anon, authenticated;
REVOKE ALL ON public.user_settings FROM anon, authenticated;
REVOKE ALL ON public.notification_settings FROM anon, authenticated;
REVOKE ALL ON public.notifications FROM anon, authenticated;
REVOKE ALL ON public.job_bookmarks FROM anon, authenticated;
REVOKE ALL ON public.haveloc_jobs FROM anon, authenticated;
REVOKE ALL ON public.haveloc_notices FROM anon, authenticated;
REVOKE ALL ON public.haveloc_applications FROM anon, authenticated;
REVOKE ALL ON public.scraper_status FROM anon, authenticated;
REVOKE ALL ON public.cleanup_log FROM anon, authenticated;
REVOKE ALL ON public.sync_errors FROM anon, authenticated;

-- Also revoke on sequences that anon/authenticated might use
REVOKE ALL ON SEQUENCE public.cleanup_log_id_seq FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.sync_errors_id_seq FROM anon, authenticated;

-- Ensure service_role retains access (policies already grant it, but
-- make sure the role itself can connect to these tables)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
