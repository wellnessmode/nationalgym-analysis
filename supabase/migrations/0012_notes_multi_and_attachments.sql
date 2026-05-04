-- =====================================================
-- 0012_notes_multi_and_attachments.sql
-- 1) notes를 iOS Notes 스타일 (사용자당 N개) 로 재설계
--    - id uuid PK, owner_id FK (1:N)
--    - title (선택) + content
--    - shared_with_user_id (개별 메모마다 공유 가능)
--    - 대표는 인사평가 목적으로 모든 매니저 메모 SELECT 가능
-- 2) attachments 테이블 신설 (task_id 또는 meeting_note_id 중 하나 참조)
--    - 파일 메타데이터. 실제 바이너리는 Supabase Storage 버킷 'attachments'.
-- =====================================================

BEGIN;

-- =========== NOTES 재설계 ===========
DROP TABLE IF EXISTS public.notes CASCADE;

CREATE TABLE public.notes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id            uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title               text NOT NULL DEFAULT '',
  content             text NOT NULL DEFAULT '',
  shared_with_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_at          timestamptz NOT NULL DEFAULT NOW(),
  created_at          timestamptz NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.notes IS '사용자별 메모(N개). shared_with_user_id 있으면 그 사용자에게도 공개. 대표는 전체 열람 가능.';

CREATE INDEX idx_notes_owner ON public.notes(owner_id);
CREATE INDEX idx_notes_shared_with
  ON public.notes(shared_with_user_id)
  WHERE shared_with_user_id IS NOT NULL;

CREATE TRIGGER trg_notes_updated_at
  BEFORE UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- SELECT: 본인 OR 공유 받은 사용자 OR 대표(전체 열람)
CREATE POLICY "notes_select_self_shared_or_admin" ON public.notes
  FOR SELECT TO authenticated
  USING (
    owner_id = current_user_id()
    OR shared_with_user_id = current_user_id()
    OR is_admin()
  );

-- INSERT: 본인 메모만 생성
CREATE POLICY "notes_insert_self" ON public.notes
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = current_user_id());

-- UPDATE: 본인 OR 공유 받은 사용자
CREATE POLICY "notes_update_self_or_shared" ON public.notes
  FOR UPDATE TO authenticated
  USING (
    owner_id = current_user_id()
    OR shared_with_user_id = current_user_id()
  )
  WITH CHECK (
    owner_id = current_user_id()
    OR shared_with_user_id = current_user_id()
  );

-- DELETE: 본인만
CREATE POLICY "notes_delete_self" ON public.notes
  FOR DELETE TO authenticated
  USING (owner_id = current_user_id());

-- 공유 대상 변경은 작성자만 가능 (RLS는 column-level X → 트리거로 강제)
CREATE OR REPLACE FUNCTION enforce_notes_share_owner_only()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF OLD.shared_with_user_id IS DISTINCT FROM NEW.shared_with_user_id
     AND OLD.owner_id <> current_user_id() THEN
    RAISE EXCEPTION '메모 공유 변경은 작성자만 가능합니다';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notes_share_owner_only ON public.notes;
CREATE TRIGGER trg_notes_share_owner_only
  BEFORE UPDATE OF shared_with_user_id ON public.notes
  FOR EACH ROW EXECUTE FUNCTION enforce_notes_share_owner_only();

-- =========== ATTACHMENTS ===========
CREATE TABLE IF NOT EXISTS public.attachments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id         uuid REFERENCES public.tasks(id) ON DELETE CASCADE,
  meeting_note_id uuid REFERENCES public.meeting_notes(id) ON DELETE CASCADE,
  uploader_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
  storage_path    text NOT NULL,        -- Supabase Storage 'attachments' 버킷 내 경로
  file_name       text NOT NULL,
  mime_type       text NOT NULL,
  size_bytes      bigint NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT NOW(),
  CHECK ((task_id IS NULL) <> (meeting_note_id IS NULL))  -- 정확히 하나만
);

COMMENT ON TABLE public.attachments IS '업무/회의록 첨부파일 메타데이터. 바이너리는 Storage 버킷 attachments.';

CREATE INDEX IF NOT EXISTS idx_attachments_task ON public.attachments(task_id) WHERE task_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_attachments_meeting ON public.attachments(meeting_note_id) WHERE meeting_note_id IS NOT NULL;

ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

-- SELECT: 부모 task / meeting_note 를 볼 수 있는 사람이면 첨부도 볼 수 있음
CREATE POLICY "attachments_select_via_parent" ON public.attachments
  FOR SELECT TO authenticated
  USING (
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
      )
    )
  );

-- INSERT: 부모를 편집할 수 있으면 첨부 추가 가능 (uploader_id = self)
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
            AND m.author_id = current_user_id()
        )
      )
    )
  );

-- DELETE: 업로더 본인 또는 admin
CREATE POLICY "attachments_delete_uploader_or_admin" ON public.attachments
  FOR DELETE TO authenticated
  USING (uploader_id = current_user_id() OR is_admin());

-- =========== STORAGE 버킷 (idempotent) ===========
-- 이미 존재하면 무시. RLS 정책은 storage.objects에 적용.
INSERT INTO storage.buckets (id, name, public)
VALUES ('attachments', 'attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Storage objects 정책: 인증된 사용자는 본인이 업로드한 객체에 접근. SELECT/INSERT/DELETE 모두 허용 (앱 레벨에서 제한).
DROP POLICY IF EXISTS "attachments_storage_authenticated_all" ON storage.objects;
CREATE POLICY "attachments_storage_authenticated_all" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'attachments')
  WITH CHECK (bucket_id = 'attachments');

COMMIT;
