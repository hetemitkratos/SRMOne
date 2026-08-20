-- Reschedule academia-sync from every 2 hours to every 30 minutes

-- Unschedule the old job
SELECT cron.unschedule('academia-sync');

-- Reschedule every 30 minutes
SELECT cron.schedule(
  'academia-sync',
  '*/30 * * * *',
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
