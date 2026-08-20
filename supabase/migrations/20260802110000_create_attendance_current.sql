-- Migration: create_attendance_current
-- Per-user latest attendance with source tracking.
-- academia-sync always writes; sp-sync writes only if academia row
-- missing or stale >12h. attendance_snapshots remains daily history
-- (never deleted by cleanup).

CREATE TABLE public.attendance_current (
  academia_email TEXT NOT NULL PRIMARY KEY,
  source TEXT NOT NULL CHECK (source IN ('academia', 'studentportal')),
  subjects JSONB NOT NULL DEFAULT '[]'::jsonb,
  overall_pct NUMERIC(5,2),
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.attendance_current ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.attendance_current
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
