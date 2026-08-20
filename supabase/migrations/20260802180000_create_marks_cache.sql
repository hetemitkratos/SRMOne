-- Migration: create_marks_cache
-- Per-user cached marks from academia sync.

CREATE TABLE IF NOT EXISTS public.marks_cache (
  academia_email TEXT NOT NULL PRIMARY KEY,
  marks JSONB NOT NULL DEFAULT '[]'::jsonb,
  cached_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.marks_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.marks_cache
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
