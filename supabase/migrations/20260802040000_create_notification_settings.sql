-- Migration: create_notification_settings
-- Stores per-user notification preferences for push alerts.

CREATE TABLE public.notification_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL UNIQUE,
  new_jobs_enabled BOOLEAN DEFAULT TRUE,
  attendance_alert_enabled BOOLEAN DEFAULT TRUE,
  attendance_threshold NUMERIC(5,2) DEFAULT 75.00,
  deadline_reminders_enabled BOOLEAN DEFAULT TRUE,
  deadline_days_before INT DEFAULT 3,
  push_enabled BOOLEAN DEFAULT FALSE,
  push_subscription JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.notification_settings
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
