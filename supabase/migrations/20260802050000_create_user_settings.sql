-- Migration: create_user_settings
-- Stores per-user UI preferences for multi-device sync.

CREATE TABLE public.user_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL UNIQUE,
  theme TEXT DEFAULT 'light',
  default_view TEXT DEFAULT 'overview',
  attendance_threshold NUMERIC(5,2) DEFAULT 75.00,
  calendar_view TEXT DEFAULT 'month',
  timetable_view TEXT DEFAULT 'week',
  show_weekends BOOLEAN DEFAULT TRUE,
  dashboard_widgets JSONB DEFAULT '[]'::jsonb,
  custom_data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.user_settings
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
