-- Migration: add_last_seen_at_and_photo_storage
-- Adds last_seen_at (for 5-day inactive cleanup) and photo_storage_path
-- (for Supabase Storage photo cache) to student_profiles.
-- student_profiles.id (UUID) becomes the session token sub.

ALTER TABLE public.student_profiles
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.student_profiles
  ADD COLUMN IF NOT EXISTS photo_storage_path TEXT;

CREATE INDEX IF NOT EXISTS idx_student_profiles_last_seen
  ON public.student_profiles (last_seen_at);
