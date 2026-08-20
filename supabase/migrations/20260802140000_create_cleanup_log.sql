-- Migration: create_cleanup_log
-- Records each cleanup run for audit and monitoring.

CREATE TABLE public.cleanup_log (
  id BIGSERIAL PRIMARY KEY,
  ran_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  users_scanned INT NOT NULL DEFAULT 0,
  records_deleted JSONB NOT NULL DEFAULT '{}'::jsonb
);

ALTER TABLE public.cleanup_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.cleanup_log
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
