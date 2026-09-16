-- Remove all pg_cron scheduled jobs.
-- Sync is moving back to the Render-hosted backends; the Edge Function
-- cron triggers (academia-sync, placement-sync) and the nightly cleanup
-- job are no longer needed.

DO $$
DECLARE
  j RECORD;
BEGIN
  FOR j IN
    SELECT jobid FROM cron.job
    WHERE jobname IN (
      'academia-sync',
      'placement-sync',
      'cleanup-inactive-placement-data'
    )
  LOOP
    PERFORM cron.unschedule(j.jobid);
  END LOOP;
END $$;

DROP TABLE IF EXISTS _cron_config;
