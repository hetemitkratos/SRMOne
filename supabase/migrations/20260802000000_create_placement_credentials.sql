-- Migration: create_placement_credentials
-- Creates the placement_credentials table for storing encrypted Haveloc credentials
-- keyed by academia email, enabling one-time connect + auto-login.

CREATE TABLE public.placement_credentials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL UNIQUE,
  placement_username TEXT NOT NULL,
  encrypted_password TEXT NOT NULL,
  has_mfa BOOLEAN DEFAULT FALSE,
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  last_auto_login TIMESTAMPTZ,
  auto_login_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.placement_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON public.placement_credentials
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
