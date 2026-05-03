-- =====================================================
-- 0006_notification_triggers.sql
-- DB 트리거가 Edge Function 'notify' 를 호출
-- pg_net 의 net.http_post 사용
--
-- _app_settings 테이블에 supabase_url + anon_key 저장 (migrate.mjs가 채움)
-- 트리거가 그 값을 읽어 Edge Function 호출
-- =====================================================

BEGIN;

-- pg_net (Supabase 기본 활성)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 앱 런타임 설정 저장 테이블 (URL/key 등 트리거에서 필요한 값)
CREATE TABLE IF NOT EXISTS public._app_settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public._app_settings IS '트리거가 참조하는 런타임 설정 (URL, key 등)';

-- Edge Function 호출 헬퍼
CREATE OR REPLACE FUNCTION public._call_notify(p_event text, p_record jsonb, p_old jsonb DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url text;
  v_key text;
BEGIN
  SELECT value INTO v_url FROM public._app_settings WHERE key = 'supabase_url';
  SELECT value INTO v_key FROM public._app_settings WHERE key = 'supabase_anon_key';

  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE WARNING 'notify settings missing in _app_settings; skipping';
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := v_url || '/functions/v1/notify',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'event', p_event,
      'record', p_record,
      'old', p_old
    )
  );
EXCEPTION WHEN others THEN
  RAISE WARNING 'notify call failed: %', SQLERRM;
END;
$$;

-- ── 트리거: tasks (INSERT, status UPDATE) ─────────────
CREATE OR REPLACE FUNCTION public._tg_tasks_notify()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public._call_notify('task_created', to_jsonb(NEW));
  ELSIF TG_OP = 'UPDATE' AND NEW.status = 'done' AND (OLD.status IS DISTINCT FROM 'done') THEN
    PERFORM public._call_notify('task_completed', to_jsonb(NEW), to_jsonb(OLD));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tasks_notify ON public.tasks;
CREATE TRIGGER trg_tasks_notify
  AFTER INSERT OR UPDATE OF status ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public._tg_tasks_notify();

-- ── 트리거: task_comments (INSERT) ─────────────
CREATE OR REPLACE FUNCTION public._tg_task_comments_notify()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  PERFORM public._call_notify('task_commented', to_jsonb(NEW));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_task_comments_notify ON public.task_comments;
CREATE TRIGGER trg_task_comments_notify
  AFTER INSERT ON public.task_comments
  FOR EACH ROW EXECUTE FUNCTION public._tg_task_comments_notify();

-- ── 트리거: meeting_notes (INSERT, status UPDATE) ─────────────
CREATE OR REPLACE FUNCTION public._tg_meeting_notes_notify()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public._call_notify('meeting_created', to_jsonb(NEW));
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'draft' AND NEW.status = 'completed' THEN
    PERFORM public._call_notify('meeting_status_changed', to_jsonb(NEW), to_jsonb(OLD));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_meeting_notes_notify ON public.meeting_notes;
CREATE TRIGGER trg_meeting_notes_notify
  AFTER INSERT OR UPDATE OF status ON public.meeting_notes
  FOR EACH ROW EXECUTE FUNCTION public._tg_meeting_notes_notify();

-- ── 트리거: meeting_comments (INSERT) ─────────────
CREATE OR REPLACE FUNCTION public._tg_meeting_comments_notify()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  PERFORM public._call_notify('meeting_commented', to_jsonb(NEW));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_meeting_comments_notify ON public.meeting_comments;
CREATE TRIGGER trg_meeting_comments_notify
  AFTER INSERT ON public.meeting_comments
  FOR EACH ROW EXECUTE FUNCTION public._tg_meeting_comments_notify();

COMMIT;
