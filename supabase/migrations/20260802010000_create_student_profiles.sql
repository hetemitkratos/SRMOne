-- Migration: create_student_profiles
-- Caches student info from SRM portal for faster dashboard loads.

CREATE TABLE public.student_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL UNIQUE,
  name TEXT,
  reg_number TEXT,
  photo_url TEXT,
  cgpa NUMERIC(5,2),
  branch TEXT,
  section TEXT,
  semester TEXT,
  phone TEXT,
  email TEXT,
  parent_email TEXT,
  parent_phone TEXT,
  mentor TEXT,
  program TEXT,
  campus TEXT,
  raw_data JSONB,
  cached_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.student_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.student_profiles
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
