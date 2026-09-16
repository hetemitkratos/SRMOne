-- Drop all placement/Haveloc tables and the sync-era bookkeeping tables.
-- The placement portal is being removed; sync moves back to the
-- Render-hosted backends which do not use these tables.

DROP TABLE IF EXISTS public.placement_credentials CASCADE;
DROP TABLE IF EXISTS public.job_bookmarks CASCADE;
DROP TABLE IF EXISTS public.haveloc_jobs CASCADE;
DROP TABLE IF EXISTS public.haveloc_notices CASCADE;
DROP TABLE IF EXISTS public.haveloc_applications CASCADE;

DROP TABLE IF EXISTS public.placement_jobs_cache CASCADE;
DROP TABLE IF EXISTS public.placement_companies_cache CASCADE;
DROP TABLE IF EXISTS public.placement_notices_cache CASCADE;
DROP TABLE IF EXISTS public.placement_policies_cache CASCADE;
DROP TABLE IF EXISTS public.placement_global_policy_cache CASCADE;
DROP TABLE IF EXISTS public.placement_calendar_cache CASCADE;
DROP TABLE IF EXISTS public.placement_insights_cache CASCADE;
DROP TABLE IF EXISTS public.placement_profile_cache CASCADE;
DROP TABLE IF EXISTS public.placement_tracker_cache CASCADE;
DROP TABLE IF EXISTS public.placement_applications_cache CASCADE;
DROP TABLE IF EXISTS public.placement_student_stats_cache CASCADE;
DROP TABLE IF EXISTS public.placement_social_media_cache CASCADE;
DROP TABLE IF EXISTS public.placement_student_documents_cache CASCADE;
DROP TABLE IF EXISTS public.placement_chat_inbox_cache CASCADE;
DROP TABLE IF EXISTS public.placement_chat_unread_cache CASCADE;
DROP TABLE IF EXISTS public.placement_job_view_cache CASCADE;
DROP TABLE IF EXISTS public.placement_job_attachments_cache CASCADE;
DROP TABLE IF EXISTS public.placement_sync_status CASCADE;

DROP TABLE IF EXISTS public.scraper_status CASCADE;
DROP TABLE IF EXISTS public.cleanup_log CASCADE;
DROP TABLE IF EXISTS public.sync_errors CASCADE;
