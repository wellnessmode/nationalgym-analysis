-- =====================================================
-- 0007_cron_due_reminder.sql
-- pg_cron으로 매일 KST 오전 9시 (UTC 자정) due-reminder Edge Function 호출
--
-- 사전 조건:
--   - pg_cron extension (Supabase 기본 활성)
--   - _app_settings에 supabase_url + supabase_anon_key 채워져 있음 (0006 + migrate.mjs)
--   - Edge Function 'due-reminder' 배포됨
-- =====================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 기존 잡 있으면 제거 (idempotent)
DO $$
BEGIN
  PERFORM cron.unschedule('due-reminder-daily');
EXCEPTION WHEN others THEN
  NULL;
END$$;

-- 매일 UTC 자정 = KST 09:00
SELECT cron.schedule(
  'due-reminder-daily',
  '0 0 * * *',
  $cron$
  SELECT net.http_post(
    url := (SELECT value FROM public._app_settings WHERE key = 'supabase_url') || '/functions/v1/due-reminder',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (SELECT value FROM public._app_settings WHERE key = 'supabase_anon_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $cron$
);

COMMIT;
