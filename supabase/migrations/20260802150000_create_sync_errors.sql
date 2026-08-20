-- Migration: create_sync_errors
-- Per-user sync errors with 7-day auto-delete policy (storage hygiene).
-- Used for monitoring SP lockout incidents, captcha failures, etc.

CREATE TABLE public.sync_errors (
  id BIGSERIAL PRIMARY KEY,
  job_name TEXT NOT NULL,
  academia_email TEXT NOT NULL,
  error TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sync_errors_email ON public.sync_errors (academia_email);
CREATE INDEX idx_sync_errors_job ON public.sync_errors (job_name, created_at DESC);

-- Auto-delete rows older than 7 days (storage hygiene for free tier)
-- pg_cron will call this daily; the schedule is set in Phase 10.
CREATE OR REPLACE FUNCTION public.cleanup_old_sync_errors()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count INT;
BEGIN
  DELETE FROM public.sync_errors
    WHERE created_at < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

ALTER TABLE public.sync_errors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.sync_errors
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
