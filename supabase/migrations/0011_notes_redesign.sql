-- =====================================================
-- 0011_notes_redesign.sql
-- notes를 1:1 공유 모델로 재설계.
--   - 사용자당 메모 1개 (PK = owner_id)
--   - shared_with_user_id (nullable) — 공유 대상. NULL = 본인만 보는 private.
-- 0010 이후 데이터 거의 없는 상태에서 안전하게 drop & recreate.
-- =====================================================

BEGIN;

DROP TABLE IF EXISTS public.notes CASCADE;

CREATE TABLE public.notes (
  owner_id            uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  content             text NOT NULL DEFAULT '',
  shared_with_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_at          timestamptz NOT NULL DEFAULT NOW(),
  created_at          timestamptz NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.notes IS '사용자당 1개 메모. shared_with_user_id 있으면 그 사용자에게도 공개';

CREATE INDEX idx_notes_shared_with
  ON public.notes(shared_with_user_id)
  WHERE shared_with_user_id IS NOT NULL;

CREATE TRIGGER trg_notes_updated_at
  BEFORE UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- SELECT: 본인 OR 공유 받은 사용자
CREATE POLICY "notes_select_self_or_shared" ON public.notes
  FOR SELECT TO authenticated
  USING (
    owner_id = current_user_id()
    OR shared_with_user_id = current_user_id()
  );

-- INSERT: 본인의 노트만
CREATE POLICY "notes_insert_self" ON public.notes
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = current_user_id());

-- UPDATE: 본인 OR 공유 받은 사용자 (둘 다 content 편집 가능)
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

-- 공유 대상 변경은 owner만 — RLS는 column-level 안 되므로 트리거로 강제
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

COMMIT;
