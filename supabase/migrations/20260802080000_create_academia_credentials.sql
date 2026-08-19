-- Migration: create_academia_credentials
-- Stores encrypted academia + student portal passwords for auto-login.
-- Uses AES-256-CBC encryption in the backend (ENCRYPTION_KEY env var).

CREATE TABLE public.academia_credentials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL UNIQUE,
  encrypted_password TEXT NOT NULL,
  encrypted_sp_password TEXT,
  last_auto_login TIMESTAMPTZ,
  auto_login_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.academia_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON public.academia_credentials
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
