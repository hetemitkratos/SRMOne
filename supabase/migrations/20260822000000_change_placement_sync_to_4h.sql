-- Reschedule placement-sync from every 5 minutes to every 4 hours

-- Unschedule the old job
SELECT cron.unschedule('placement-sync');

-- Reschedule every 4 hours
SELECT cron.schedule(
  'placement-sync',
  '0 */4 * * *',
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
