-- Migration: create_job_bookmarks
-- Stores bookmarked/saved jobs from Haveloc with notes and application status.

CREATE TABLE public.job_bookmarks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL,
  job_uuid TEXT NOT NULL,
  job_title TEXT,
  company_name TEXT,
  job_data JSONB,
  notes TEXT,
  application_status TEXT DEFAULT 'bookmarked',
  bookmarked_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(academia_email, job_uuid)
);

CREATE INDEX idx_bookmarks_email ON public.job_bookmarks (academia_email);

ALTER TABLE public.job_bookmarks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.job_bookmarks
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
