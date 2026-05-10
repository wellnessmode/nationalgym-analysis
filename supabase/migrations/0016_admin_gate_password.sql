-- =====================================================
-- 0016_admin_gate_password.sql
-- 대표 (ceo@nationalgym.kr) 의 '메모 체크' / '로그 체크' 메뉴 진입 시
-- 추가 비밀번호 게이트. bcrypt 해시 저장. RPC 로 설정·검증.
-- =====================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.admin_gate (
  id            integer PRIMARY KEY DEFAULT 1,
  password_hash text NOT NULL,
  updated_at    timestamptz NOT NULL DEFAULT NOW(),
  CHECK (id = 1)
);

-- 직접 접근 차단. 모든 read/write 는 RPC 통해서만.
ALTER TABLE public.admin_gate ENABLE ROW LEVEL SECURITY;

-- (정책 없음 → 일반 클라이언트는 SELECT/INSERT/UPDATE 모두 차단)

-- 호출자가 ceo@nationalgym.kr 인지 확인하는 헬퍼
CREATE OR REPLACE FUNCTION public._is_ceo()
RETURNS boolean
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
  RETURN caller_email = 'ceo@nationalgym.kr';
END;
$$;

-- 게이트 비밀번호 설정/변경 (ceo only)
CREATE OR REPLACE FUNCTION public.set_admin_gate_password(new_password text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NOT public._is_ceo() THEN
    RAISE EXCEPTION 'only ceo@nationalgym.kr can set the gate password';
  END IF;
  IF length(new_password) < 4 THEN
    RAISE EXCEPTION 'gate password must be at least 4 characters';
  END IF;

  INSERT INTO public.admin_gate (id, password_hash, updated_at)
  VALUES (1, crypt(new_password, gen_salt('bf')), NOW())
  ON CONFLICT (id) DO UPDATE
    SET password_hash = EXCLUDED.password_hash,
        updated_at    = NOW();
END;
$$;

-- 게이트 비밀번호 검증 (ceo only). 통과 시 true, 아니면 false.
-- 게이트 미설정 상태면 false 반환 (앱이 '아직 설정 안 됨' 안내).
CREATE OR REPLACE FUNCTION public.verify_admin_gate(input text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  stored_hash text;
BEGIN
  IF NOT public._is_ceo() THEN
    RETURN false;
  END IF;
  SELECT password_hash INTO stored_hash FROM public.admin_gate WHERE id = 1;
  IF stored_hash IS NULL THEN
    RETURN false;
  END IF;
  RETURN stored_hash = crypt(input, stored_hash);
END;
$$;

-- 게이트 설정 여부 조회 (ceo only). UI 분기용.
CREATE OR REPLACE FUNCTION public.admin_gate_is_set()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public._is_ceo() THEN
    RETURN false;
  END IF;
  RETURN EXISTS (SELECT 1 FROM public.admin_gate WHERE id = 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_admin_gate_password(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_admin_gate(text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_gate_is_set()            TO authenticated;

COMMIT;
