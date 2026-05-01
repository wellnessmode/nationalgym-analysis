-- =====================================================
-- 0005_update_emails.sql
-- 시드 이메일 (.local placeholder) → 실제 도메인 (.kr) 변경
-- 운영 환경에서 만든 auth.users 와 public.users 수동 링크
-- (auth 트리거는 INSERT 때만 fire하므로, 트리거 설치 전 또는 도메인 불일치 시
--  이미 만들어진 auth.users 는 자동 링크 안 됨)
-- =====================================================

BEGIN;

-- 1) public.users 이메일 실제 도메인으로 변경
UPDATE public.users
SET email = 'ceo@nationalgym.kr', updated_at = NOW()
WHERE email = 'admin@nationalgym.local';

UPDATE public.users
SET email = 'manager.jung@nationalgym.kr', updated_at = NOW()
WHERE email = 'manager.jung@nationalgym.local';

UPDATE public.users
SET email = 'manager.kim@nationalgym.kr', updated_at = NOW()
WHERE email = 'manager.kim@nationalgym.local';

-- 2) 이메일 매칭으로 auth.users → public.users 수동 링크
--    (이미 auth_user_id 가 채워진 row는 그대로 둠)
UPDATE public.users
SET auth_user_id = au.id, updated_at = NOW()
FROM auth.users au
WHERE public.users.email = au.email
  AND public.users.auth_user_id IS NULL;

COMMIT;
