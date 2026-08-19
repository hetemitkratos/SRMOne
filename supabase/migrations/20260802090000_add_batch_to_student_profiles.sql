-- Migration: add_batch_to_student_profiles
-- Adds missing batch column that supabaseClient.js expects.

ALTER TABLE public.student_profiles
  ADD COLUMN IF NOT EXISTS batch TEXT;
