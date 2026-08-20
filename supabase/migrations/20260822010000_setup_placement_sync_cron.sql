-- Migration: set up pg_cron job to trigger placement-sync Edge Function every 5 minutes
-- Per the architecture guide: Haveloc runs every 5 minutes for job tracking.
-- The Edge Function handles chunked processing and self-invocation.

-- Reuse _cron_config table from academia-sync migration
INSERT INTO _cron_config (key, value) VALUES
  ('placement_cron_secret', 'Kp7Xm2vQ9wRtYnB4fL8jH3sZ6dG5pA1e')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Schedule placement-sync every 5 minutes
SELECT cron.schedule(
  'placement-sync',
  '*/5 * * * *',
  $$
    SELECT net.http_post(
      url := (SELECT value FROM _cron_config WHERE key = 'supabase_url') || '/functions/v1/placement-sync',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (SELECT value FROM _cron_config WHERE key = 'service_role_key'),
        'X-Cron-Secret', (SELECT value FROM _cron_config WHERE key = 'placement_cron_secret')
      ),
      body := jsonb_build_object(
        'offset', 0,
        'fetchGlobal', true
      )
    );
  $$
);
