-- =====================================================
-- 0013_staff_activity.sql
-- 대표 (ceo@nationalgym.kr) 전용 — 직원별 활동 통계 조회 함수.
-- 로그인 시각, 메모/업무/회의록 작성 카운트 + 마지막 수정 시각 집계.
-- SECURITY DEFINER 로 auth.users 우회 접근, 호출자 이메일 검증.
-- =====================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_staff_activity()
RETURNS TABLE (
  user_id uuid,
  name text,
  email text,
  role text,
  last_sign_in_at timestamptz,
  account_created_at timestamptz,
  notes_count bigint,
  last_note_edit timestamptz,
  tasks_total bigint,
  tasks_done bigint,
  last_task_update timestamptz,
  meetings_total bigint,
  last_meeting_update timestamptz,
  last_activity timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  caller_email text;
BEGIN
  SELECT au.email INTO caller_email
  FROM public.users u
  JOIN auth.users au ON au.id = u.auth_user_id
  WHERE u.id = current_user_id();

  IF caller_email IS NULL OR caller_email <> 'ceo@nationalgym.kr' THEN
    RAISE EXCEPTION 'Access denied: ceo@nationalgym.kr only';
  END IF;

  RETURN QUERY
  SELECT
    u.id::uuid                                                                   AS user_id,
    u.name::text                                                                 AS name,
    au.email::text                                                               AS email,
    u.role::text                                                                 AS role,
    au.last_sign_in_at                                                           AS last_sign_in_at,
    au.created_at                                                                AS account_created_at,
    (SELECT COUNT(*) FROM public.notes n WHERE n.owner_id = u.id)                AS notes_count,
    (SELECT MAX(n.updated_at) FROM public.notes n WHERE n.owner_id = u.id)       AS last_note_edit,
    (SELECT COUNT(*) FROM public.tasks t WHERE t.assignee_id = u.id)             AS tasks_total,
    (SELECT COUNT(*) FROM public.tasks t WHERE t.assignee_id = u.id AND t.status='done') AS tasks_done,
    (SELECT MAX(t.updated_at) FROM public.tasks t WHERE t.assignee_id = u.id)    AS last_task_update,
    (SELECT COUNT(*) FROM public.meeting_notes m WHERE m.author_id = u.id)       AS meetings_total,
    (SELECT MAX(m.updated_at) FROM public.meeting_notes m WHERE m.author_id = u.id) AS last_meeting_update,
    GREATEST(
      au.last_sign_in_at,
      (SELECT MAX(n.updated_at) FROM public.notes n WHERE n.owner_id = u.id),
      (SELECT MAX(t.updated_at) FROM public.tasks t WHERE t.assignee_id = u.id),
      (SELECT MAX(m.updated_at) FROM public.meeting_notes m WHERE m.author_id = u.id)
    )                                                                            AS last_activity
  FROM public.users u
  LEFT JOIN auth.users au ON au.id = u.auth_user_id
  WHERE u.role = 'manager'
  ORDER BY u.name;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_staff_activity() TO authenticated;

COMMIT;
