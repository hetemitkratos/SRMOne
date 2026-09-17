-- Migration: create_academia_sessions
-- Persists the portal session cookies (academia + student portal) per user so
-- a backend restart or idle timeout does not force a fresh login / captcha.
-- Cookie JSON is AES-256-CBC encrypted by the backend (ENCRYPTION_KEY), same
-- scheme as academia_credentials.

CREATE TABLE public.academia_sessions (
  academia_email TEXT PRIMARY KEY,
  encrypted_academia_cookies TEXT,
  academia_meta JSONB,
  academia_saved_at TIMESTAMPTZ,
  encrypted_sp_cookies TEXT,
  sp_saved_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.academia_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON public.academia_sessions
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
