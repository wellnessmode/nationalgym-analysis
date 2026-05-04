-- =====================================================
-- 0010_notes.sql
-- 개인 메모(private) + 공유 메모(shared, 대표↔매니저)
-- =====================================================

BEGIN;

-- 1) notes 테이블
CREATE TABLE IF NOT EXISTS public.notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  scope text NOT NULL CHECK (scope IN ('private', 'shared')),
  content text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  created_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (owner_id, scope)  -- 사용자당 private 1개 + shared 1개
);

COMMENT ON TABLE public.notes IS '개인 메모(private) 및 공유 메모(shared)';
COMMENT ON COLUMN public.notes.scope IS 'private: 본인만 / shared: owner + admin';

CREATE INDEX IF NOT EXISTS idx_notes_owner_id ON public.notes(owner_id);
CREATE INDEX IF NOT EXISTS idx_notes_scope_owner ON public.notes(scope, owner_id);

DROP TRIGGER IF EXISTS trg_notes_updated_at ON public.notes;
CREATE TRIGGER trg_notes_updated_at
  BEFORE UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 2) RLS
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- SELECT
DROP POLICY IF EXISTS "notes_select_private" ON public.notes;
CREATE POLICY "notes_select_private" ON public.notes
  FOR SELECT TO authenticated
  USING (scope = 'private' AND owner_id = current_user_id());

DROP POLICY IF EXISTS "notes_select_shared" ON public.notes;
CREATE POLICY "notes_select_shared" ON public.notes
  FOR SELECT TO authenticated
  USING (scope = 'shared' AND (owner_id = current_user_id() OR is_admin()));

-- INSERT (본인만 자기 노트 생성)
DROP POLICY IF EXISTS "notes_insert_owner" ON public.notes;
CREATE POLICY "notes_insert_owner" ON public.notes
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = current_user_id());

-- UPDATE
DROP POLICY IF EXISTS "notes_update_private" ON public.notes;
CREATE POLICY "notes_update_private" ON public.notes
  FOR UPDATE TO authenticated
  USING (scope = 'private' AND owner_id = current_user_id())
  WITH CHECK (scope = 'private' AND owner_id = current_user_id());

DROP POLICY IF EXISTS "notes_update_shared" ON public.notes;
CREATE POLICY "notes_update_shared" ON public.notes
  FOR UPDATE TO authenticated
  USING (scope = 'shared' AND (owner_id = current_user_id() OR is_admin()))
  WITH CHECK (scope = 'shared' AND (owner_id = current_user_id() OR is_admin()));

-- DELETE (오너 본인만)
DROP POLICY IF EXISTS "notes_delete_owner" ON public.notes;
CREATE POLICY "notes_delete_owner" ON public.notes
  FOR DELETE TO authenticated
  USING (owner_id = current_user_id());

COMMIT;
