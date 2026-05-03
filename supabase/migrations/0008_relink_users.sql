-- =====================================================
-- 0008_relink_users.sql
-- public.users.auth_user_id 전부 NULL로 → 이메일 매칭으로 재링크
-- 모든 사용자가 동일 인물로 표시되는 버그 진단·수정용
-- =====================================================

BEGIN;

-- 1) 모든 링크 초기화
UPDATE public.users SET auth_user_id = NULL;

-- 2) 이메일로 1:1 재링크
UPDATE public.users
SET auth_user_id = au.id, updated_at = NOW()
FROM auth.users au
WHERE public.users.email = au.email;

COMMIT;
