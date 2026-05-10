-- =====================================================
-- 0015_soft_delete_note_rpc.sql
-- 메모 soft delete RPC. RLS WITH CHECK 충돌 우회.
-- 작성자 본인 또는 admin 만 호출 가능. 함수 내부에서 권한 확인.
-- =====================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.soft_delete_note(note_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid;
  note_owner uuid;
BEGIN
  caller := current_user_id();
  IF caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT owner_id INTO note_owner FROM public.notes WHERE id = note_id;
  IF note_owner IS NULL THEN
    RAISE EXCEPTION 'note not found';
  END IF;

  IF note_owner <> caller AND NOT is_admin() THEN
    RAISE EXCEPTION 'permission denied: only owner can soft delete';
  END IF;

  UPDATE public.notes
  SET deleted_at = NOW()
  WHERE id = note_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.soft_delete_note(uuid) TO authenticated;

COMMIT;
