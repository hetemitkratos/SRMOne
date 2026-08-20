-- Migration: create_timetable_cache
-- Per-user cached timetable from academia sync.

CREATE TABLE IF NOT EXISTS public.timetable_cache (
  academia_email TEXT NOT NULL PRIMARY KEY,
  timetable JSONB NOT NULL DEFAULT '[]'::jsonb,
  cached_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.timetable_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.timetable_cache
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
