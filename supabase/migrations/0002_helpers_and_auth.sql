-- =====================================================
-- 0002_helpers_and_auth.sql
-- 내셔널짐 PT 업무공유 PWA
-- RLS 헬퍼 함수, auth.users INSERT 트리거
-- =====================================================

BEGIN;

-- =====================================================
-- 1) RLS 헬퍼 함수
-- 모두 SECURITY DEFINER + search_path 고정
-- 이유: users 테이블 RLS와 무한 재귀 차단 + search_path 하이재킹 방어
-- =====================================================

-- 1-1) current_user_id: auth.uid()에 매칭되는 public.users.id
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.users WHERE auth_user_id = auth.uid()
$$;
COMMENT ON FUNCTION current_user_id() IS '현재 로그인 사용자의 public.users.id 반환. 미매칭 시 NULL';

-- 1-2) is_admin: 현재 사용자가 admin인지
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE auth_user_id = auth.uid()
      AND role = 'admin'
  )
$$;
COMMENT ON FUNCTION is_admin() IS '현재 로그인 사용자가 admin이면 true';

-- 1-3) user_has_branch: 현재 사용자가 해당 지점에 접근 가능한지
-- admin은 항상 true, manager는 user_branches 매핑 확인
CREATE OR REPLACE FUNCTION user_has_branch(target_branch_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    is_admin()
    OR EXISTS (
      SELECT 1 FROM public.user_branches ub
      JOIN public.users u ON u.id = ub.user_id
      WHERE u.auth_user_id = auth.uid()
        AND ub.branch_id = target_branch_id
    )
$$;
COMMENT ON FUNCTION user_has_branch(uuid) IS 'admin이거나 해당 지점이 user_branches에 매핑된 매니저면 true';

-- 인증된 클라이언트가 RLS 평가 시 호출 가능하도록 EXECUTE 권한 부여
GRANT EXECUTE ON FUNCTION current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION user_has_branch(uuid) TO authenticated;

-- =====================================================
-- 2) auth.users INSERT 트리거
-- Supabase Auth Dashboard에서 새 계정이 생성되면
-- 같은 이메일의 pre-seeded public.users row와 자동 매칭
-- =====================================================

CREATE OR REPLACE FUNCTION handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- pre-seeded users row 중 같은 이메일 + 미매칭 row가 있으면 연결
  -- 매칭 row 없으면 조용히 무시 (외부 가입 시도 차단 효과)
  UPDATE public.users
  SET auth_user_id = NEW.id,
      updated_at = NOW()
  WHERE email = NEW.email
    AND auth_user_id IS NULL;

  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION handle_new_auth_user() IS 'auth.users INSERT 시 같은 이메일의 public.users row에 auth_user_id 자동 연결';

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_auth_user();

COMMIT;
