-- Migration: daily cleanup of inactive user temporary placement data
-- Per the architecture guide: Delete eligible user-specific temporary/cache data
-- after 5 days of inactivity. Keep auth.users, core profile, and global placement data.
-- Global tables (jobs, companies, notices, policies) are NEVER deleted by cleanup.

-- Schedule daily cleanup at 03:00 IST (21:30 UTC)
SELECT cron.schedule(
  'cleanup-inactive-placement-data',
  '30 21 * * *',
  $$
    -- Delete per-user placement cache for users inactive for 5+ days
    -- Inactivity is determined by last_auto_login in placement_credentials
    -- or last_seen_at in student_profiles (whichever is more recent)

    DELETE FROM public.placement_profile_cache
    WHERE academia_email IN (
      SELECT c.academia_email
      FROM public.placement_credentials c
      LEFT JOIN public.student_profiles p ON p.academia_email = c.academia_email
      WHERE COALESCE(c.last_auto_login, c.connected_at, p.last_seen_at) < NOW() - INTERVAL '5 days'
    );

    DELETE FROM public.placement_tracker_cache
    WHERE academia_email IN (
      SELECT c.academia_email
      FROM public.placement_credentials c
      LEFT JOIN public.student_profiles p ON p.academia_email = c.academia_email
      WHERE COALESCE(c.last_auto_login, c.connected_at, p.last_seen_at) < NOW() - INTERVAL '5 days'
    );

    DELETE FROM public.placement_applications_cache
    WHERE academia_email IN (
      SELECT c.academia_email
      FROM public.placement_credentials c
      LEFT JOIN public.student_profiles p ON p.academia_email = c.academia_email
      WHERE COALESCE(c.last_auto_login, c.connected_at, p.last_seen_at) < NOW() - INTERVAL '5 days'
    );

    DELETE FROM public.placement_student_stats_cache
    WHERE academia_email IN (
      SELECT c.academia_email
      FROM public.placement_credentials c
      LEFT JOIN public.student_profiles p ON p.academia_email = c.academia_email
      WHERE COALESCE(c.last_auto_login, c.connected_at, p.last_seen_at) < NOW() - INTERVAL '5 days'
    );

    DELETE FROM public.placement_social_media_cache
    WHERE academia_email IN (
      SELECT c.academia_email
      FROM public.placement_credentials c
      LEFT JOIN public.student_profiles p ON p.academia_email = c.academia_email
      WHERE COALESCE(c.last_auto_login, c.connected_at, p.last_seen_at) < NOW() - INTERVAL '5 days'
    );

    DELETE FROM public.placement_student_documents_cache
    WHERE academia_email IN (
      SELECT c.academia_email
      FROM public.placement_credentials c
      LEFT JOIN public.student_profiles p ON p.academia_email = c.academia_email
      WHERE COALESCE(c.last_auto_login, c.connected_at, p.last_seen_at) < NOW() - INTERVAL '5 days'
    );

    DELETE FROM public.placement_chat_inbox_cache
    WHERE academia_email IN (
      SELECT c.academia_email
      FROM public.placement_credentials c
      LEFT JOIN public.student_profiles p ON p.academia_email = c.academia_email
      WHERE COALESCE(c.last_auto_login, c.connected_at, p.last_seen_at) < NOW() - INTERVAL '5 days'
    );

    DELETE FROM public.placement_chat_unread_cache
    WHERE academia_email IN (
      SELECT c.academia_email
      FROM public.placement_credentials c
      LEFT JOIN public.student_profiles p ON p.academia_email = c.academia_email
      WHERE COALESCE(c.last_auto_login, c.connected_at, p.last_seen_at) < NOW() - INTERVAL '5 days'
    );

    -- Log the cleanup run
    INSERT INTO public.cleanup_log (users_scanned, records_deleted)
    VALUES (
      0,
      jsonb_build_object('run_at', NOW(), 'type', 'placement_cache_cleanup')
    );
  $$
);
