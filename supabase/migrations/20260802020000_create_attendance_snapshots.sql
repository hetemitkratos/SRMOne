-- Migration: create_attendance_snapshots
-- Stores periodic attendance snapshots for trend tracking over time.

CREATE TABLE public.attendance_snapshots (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL,
  snapshot_date DATE NOT NULL,
  overall_percentage NUMERIC(5,2),
  subjects JSONB NOT NULL DEFAULT '[]'::jsonb,
  total_classes INT,
  attended_classes INT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_attendance_email_date ON public.attendance_snapshots (academia_email, snapshot_date DESC);

ALTER TABLE public.attendance_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.attendance_snapshots
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
