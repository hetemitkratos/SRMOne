-- Migration: enable_realtime_tables
-- Enables Supabase Realtime for notifications and job bookmarks.

ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.job_bookmarks;
