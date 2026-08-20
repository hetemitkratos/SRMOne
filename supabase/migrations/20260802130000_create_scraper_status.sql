-- Migration: create_scraper_status
-- Tracks last success/error per scraper job for freshness badges and monitoring.

CREATE TABLE public.scraper_status (
  job_name TEXT NOT NULL PRIMARY KEY,
  last_success_at TIMESTAMPTZ,
  last_error TEXT,
  last_run_at TIMESTAMPTZ,
  records_written INT DEFAULT 0
);

ALTER TABLE public.scraper_status ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.scraper_status
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
