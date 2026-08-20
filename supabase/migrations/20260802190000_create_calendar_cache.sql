-- Migration: create_calendar_cache
-- Per-user cached calendar from academia sync, keyed by semester.

CREATE TABLE IF NOT EXISTS public.calendar_cache (
  academia_email TEXT NOT NULL,
  sem TEXT NOT NULL DEFAULT 'even',
  calendar JSONB NOT NULL DEFAULT '[]'::jsonb,
  cached_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(academia_email, sem)
);

ALTER TABLE public.calendar_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.calendar_cache
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
