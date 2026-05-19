-- =====================================================
-- 0019_security_hardening.sql
-- 프로덕션 lv99 보안 강화. 매니저 권한 escalation / storage 누수 /
-- notification 정합성 / Edge Function 인증 우회 등 차단.
-- =====================================================

BEGIN;

-- =========== 1) users 컬럼 단위 변경 제한 ===========
-- 매니저가 자기 role 을 admin 으로 바꾸지 못하도록 트리거로 강제.
-- (RLS 의 USING/WITH CHECK 는 row-level 만 검사하므로 column-level 강제는 트리거)
CREATE OR REPLACE FUNCTION public.enforce_users_self_update_columns()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- admin 은 모두 허용
  IF is_admin() THEN RETURN NEW; END IF;

  -- 본인 row 가 아니면 RLS 가 막아주지만 안전 마진
  IF OLD.id <> current_user_id() THEN
    RAISE EXCEPTION '본인 row 만 수정 가능';
  END IF;

  -- 매니저가 셀프 업데이트 시 변경 가능한 컬럼은 fcm_token / name / phone 만.
  -- role / email / auth_user_id / id 는 매니저가 바꿀 수 없음.
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'id 변경 불가';
  END IF;
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'role 은 대표만 변경 가능';
  END IF;
  IF NEW.email IS DISTINCT FROM OLD.email THEN
    RAISE EXCEPTION 'email 변경은 대표 요청 후 SQL Editor 에서만';
  END IF;
  IF NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id THEN
    RAISE EXCEPTION 'auth_user_id 변경 불가';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_self_update_columns ON public.users;
CREATE TRIGGER trg_users_self_update_columns
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.enforce_users_self_update_columns();

-- =========== 2) notifications DELETE 정책 + cleanup RPC ===========
-- 본인 알림 삭제 가능 + 90일 이상 자동 정리 함수.
DROP POLICY IF EXISTS "notifications_delete_self" ON public.notifications;
CREATE POLICY "notifications_delete_self" ON public.notifications
  FOR DELETE TO authenticated
  USING (user_id = current_user_id() OR is_admin());

CREATE OR REPLACE FUNCTION public.notifications_cleanup_old()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n integer;
BEGIN
  DELETE FROM public.notifications
   WHERE created_at < NOW() - INTERVAL '90 days';
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.notifications_cleanup_old() TO authenticated;

-- =========== 3) Storage 객체 경로별 권한 격리 ===========
-- attachments 버킷: prefix 가 tasks/<id>/ 또는 meetings/<id>/ 일 때
-- 부모 task / meeting 의 지점에 접근 권한 있는 사용자만.
DROP POLICY IF EXISTS "attachments_storage_authenticated_all" ON storage.objects;

-- SELECT (다운로드 URL 생성용): 부모 row 의 지점에 user_has_branch 또는 is_admin
CREATE POLICY "attachments_storage_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'attachments' AND (
      is_admin()
      OR EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE name LIKE 'tasks/' || t.id::text || '/%'
          AND user_has_branch(t.branch_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.meeting_notes m
        WHERE name LIKE 'meetings/' || m.id::text || '/%'
          AND user_has_branch(m.branch_id)
      )
    )
  );

CREATE POLICY "attachments_storage_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'attachments' AND (
      is_admin()
      OR EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE name LIKE 'tasks/' || t.id::text || '/%'
          AND (t.assignee_id = current_user_id() OR t.requester_id = current_user_id())
      )
      OR EXISTS (
        SELECT 1 FROM public.meeting_notes m
        WHERE name LIKE 'meetings/' || m.id::text || '/%'
          AND user_has_branch(m.branch_id)
      )
    )
  );

CREATE POLICY "attachments_storage_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'attachments' AND is_admin()
  );

-- meeting-audio (0009 에서 생성) 와 recordings (0018) 같은 정책
DROP POLICY IF EXISTS "meeting_audio_authenticated_all" ON storage.objects;
CREATE POLICY "meeting_audio_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'meeting-audio' AND (
      is_admin()
      OR EXISTS (
        SELECT 1 FROM public.meeting_notes m
        WHERE name LIKE m.id::text || '/%'
          AND user_has_branch(m.branch_id)
      )
    )
  );

CREATE POLICY "meeting_audio_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'meeting-audio' AND (
      is_admin()
      OR EXISTS (
        SELECT 1 FROM public.meeting_notes m
        WHERE name LIKE m.id::text || '/%'
          AND m.author_id = current_user_id()
      )
    )
  );

-- recordings 버킷은 prefix 가 live/<uploader_id>/... — 본인 업로드만 SELECT.
-- (현재 사용 형식은 자기 자신만 접근. 추후 admin 도 감사 차원에서 SELECT 가능)
DROP POLICY IF EXISTS "recordings_authenticated_all" ON storage.objects;
CREATE POLICY "recordings_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'recordings' AND (
      is_admin()
      OR name LIKE 'live/' || current_user_id()::text || '/%'
    )
  );

CREATE POLICY "recordings_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'recordings'
    AND name LIKE 'live/' || current_user_id()::text || '/%'
  );

CREATE POLICY "recordings_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'recordings' AND (
      is_admin()
      OR name LIKE 'live/' || current_user_id()::text || '/%'
    )
  );

-- =========== 4) task DELETE 정책 — 작성자 본인도 삭제 가능 ===========
-- UI 가 'requester 도 삭제 가능' 으로 표시하므로 RLS 도 일치시킴.
DROP POLICY IF EXISTS "tasks_delete_admin" ON public.tasks;
CREATE POLICY "tasks_delete_admin_or_owner" ON public.tasks
  FOR DELETE TO authenticated
  USING (is_admin() OR requester_id = current_user_id());

-- =========== 5) 회의록 첨부 INSERT — 같은 지점이면 누구나 OK ===========
DROP POLICY IF EXISTS "attachments_insert_self" ON public.attachments;
CREATE POLICY "attachments_insert_self" ON public.attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    uploader_id = current_user_id()
    AND (
      is_admin()
      OR (
        task_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.tasks t
          WHERE t.id = attachments.task_id
            AND (t.assignee_id = current_user_id() OR t.requester_id = current_user_id())
        )
      )
      OR (
        meeting_note_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.meeting_notes m
          WHERE m.id = attachments.meeting_note_id
            AND user_has_branch(m.branch_id)
        )
      )
    )
  );

-- =========== 6) 메모 trigger NULL 방지 ===========
CREATE OR REPLACE FUNCTION enforce_notes_share_owner_only()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF OLD.shared_with_user_id IS DISTINCT FROM NEW.shared_with_user_id THEN
    IF current_user_id() IS NULL OR OLD.owner_id <> current_user_id() THEN
      RAISE EXCEPTION '메모 공유 변경은 작성자만 가능합니다';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

COMMIT;
