-- =====================================================
-- 0014_notes_soft_delete.sql
-- notes 에 deleted_at 컬럼 추가 — 매니저가 메모 삭제해도 row 는 남음.
-- 대표는 인사평가 / 감사 목적으로 삭제된 메모도 모두 열람 가능.
-- 매니저: deleted_at IS NULL 인 본인 / 공유 받은 메모만 보임 (RLS).
-- =====================================================

BEGIN;

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_notes_deleted_at
  ON public.notes(deleted_at) WHERE deleted_at IS NOT NULL;

-- 기존 SELECT 정책 교체 — 삭제된 row 는 매니저에게 안 보이도록
DROP POLICY IF EXISTS "notes_select_self_shared_or_admin" ON public.notes;
CREATE POLICY "notes_select_self_shared_or_admin" ON public.notes
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR (
      deleted_at IS NULL
      AND (
        owner_id = current_user_id()
        OR shared_with_user_id = current_user_id()
      )
    )
  );

-- UPDATE 정책도 동일하게: 매니저는 삭제 안 된 본인/공유 row 만 변경 가능
DROP POLICY IF EXISTS "notes_update_self_or_shared" ON public.notes;
CREATE POLICY "notes_update_self_or_shared" ON public.notes
  FOR UPDATE TO authenticated
  USING (
    is_admin()
    OR (
      (owner_id = current_user_id() OR shared_with_user_id = current_user_id())
    )
  )
  WITH CHECK (
    is_admin()
    OR (
      owner_id = current_user_id()
      OR shared_with_user_id = current_user_id()
    )
  );

-- DELETE 정책은 그대로 두지만, 클라이언트 코드는 이제 UPDATE deleted_at 으로 동작.
-- (admin 실수로 누른 hard delete 차단을 원하면 DELETE 정책 자체를 제거해도 됨)

COMMIT;
