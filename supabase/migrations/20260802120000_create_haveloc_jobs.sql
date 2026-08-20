-- Migration: create_haveloc_jobs
-- Canonical global job and notice tables (deduped by job_uuid/notice_uuid).
-- Per-user applications table. These are global — not deleted by cleanup.

CREATE TABLE public.haveloc_jobs (
  job_uuid TEXT NOT NULL PRIMARY KEY,
  job_id TEXT,
  title TEXT,
  company_name TEXT,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_haveloc_jobs_last_seen ON public.haveloc_jobs (last_seen_at DESC);

CREATE TABLE public.haveloc_notices (
  notice_uuid TEXT NOT NULL PRIMARY KEY,
  notice_id TEXT,
  title TEXT,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.haveloc_applications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL,
  job_uuid TEXT NOT NULL REFERENCES public.haveloc_jobs(job_uuid) ON DELETE CASCADE,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(academia_email, job_uuid)
);

CREATE INDEX idx_haveloc_applications_email ON public.haveloc_applications (academia_email);

ALTER TABLE public.haveloc_jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.haveloc_jobs
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

ALTER TABLE public.haveloc_notices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.haveloc_notices
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

ALTER TABLE public.haveloc_applications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.haveloc_applications
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
