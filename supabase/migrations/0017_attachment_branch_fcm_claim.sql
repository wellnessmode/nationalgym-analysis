-- =====================================================
-- 0017_attachment_branch_fcm_claim.sql
-- 두 가지 보안 패치:
--   (1) 회의록 첨부파일 SELECT 정책에 지점 체크 추가
--       — 매니저가 본인 지점 외 회의 첨부 metadata 조회 못 하도록.
--   (2) claim_fcm_token() RPC — 같은 브라우저에서 사용자 전환 시
--       이전 사용자의 fcm_token 자동 회수하여 잘못된 알림 전달 방지.
-- =====================================================

BEGIN;

-- (1) 회의 첨부파일 SELECT 정책 재정의 — 부모 회의록의 지점 체크
DROP POLICY IF EXISTS "attachments_select_via_parent" ON public.attachments;
CREATE POLICY "attachments_select_via_parent" ON public.attachments
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR (
      task_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.tasks t
        WHERE t.id = attachments.task_id
          AND user_has_branch(t.branch_id)
      )
    )
    OR (
      meeting_note_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.meeting_notes m
        WHERE m.id = attachments.meeting_note_id
          AND user_has_branch(m.branch_id)
      )
    )
  );

-- (2) FCM 토큰 소유권 이관 — 같은 토큰을 보유한 다른 row 비우고 자기 row 에 세팅
CREATE OR REPLACE FUNCTION public.claim_fcm_token(token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  me uuid;
BEGIN
  me := current_user_id();
  IF me IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF token IS NULL OR length(token) = 0 THEN
    -- 토큰 해제 (로그아웃)
    UPDATE public.users SET fcm_token = NULL WHERE id = me;
    RETURN;
  END IF;

  -- 다른 사용자가 같은 토큰을 갖고 있으면 회수
  UPDATE public.users SET fcm_token = NULL
   WHERE fcm_token = token AND id <> me;

  -- 본인 row 에 세팅
  UPDATE public.users SET fcm_token = token WHERE id = me;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_fcm_token(text) TO authenticated;

COMMIT;
