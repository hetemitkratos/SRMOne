-- Set up pg_cron job to trigger academia-sync Edge Function every 2 hours
-- The Edge Function handles chunked processing and self-invocation

-- Store non-sensitive config in a table for cron access
-- Sensitive secrets (service_role_key) are set via post-migration SQL
CREATE TABLE IF NOT EXISTS _cron_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO _cron_config (key, value) VALUES
  ('supabase_url', 'https://kolpioxbznypmvivbdhn.supabase.co'),
  ('cron_secret', 'JuzXb=my9rYO2DHGkqIFnBL0@gxljp?1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Lock down access
REVOKE ALL ON _cron_config FROM anon, authenticated;
GRANT SELECT ON _cron_config TO postgres;

-- Schedule the academia-sync function every 2 hours
-- service_role_key is injected via supabase db query after migration
SELECT cron.schedule(
  'academia-sync',
  '0 */2 * * *',
  $$
    SELECT net.http_post(
      url := (SELECT value FROM _cron_config WHERE key = 'supabase_url') || '/functions/v1/academia-sync',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (SELECT value FROM _cron_config WHERE key = 'service_role_key'),
        'X-Cron-Secret', (SELECT value FROM _cron_config WHERE key = 'cron_secret')
      ),
      body := jsonb_build_object(
        'offset', 0,
        'limit', 10
      )
    );
  $$
);
