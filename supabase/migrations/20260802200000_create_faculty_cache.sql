-- Migration: create_faculty_cache
-- Persists scraped faculty profiles so we don't re-scrape SRM on every request.

CREATE TABLE IF NOT EXISTS public.faculty_cache (
  cache_key TEXT NOT NULL PRIMARY KEY,
  profile_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  fetched_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.faculty_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.faculty_cache
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
