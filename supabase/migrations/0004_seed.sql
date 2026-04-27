-- =====================================================
-- 0004_seed.sql
-- 내셔널짐 PT 업무공유 PWA
-- 초기 데이터 — branches, users, user_branches
--
-- 실행 후 별도 작업:
--   1. Supabase Dashboard > Authentication > Users 에서 아래 3개 이메일로
--      비밀번호 계정 생성 (Send invite 또는 직접 입력)
--      - admin@nationalgym.local
--      - manager.jung@nationalgym.local
--      - manager.kim@nationalgym.local
--   2. 0002의 on_auth_user_created 트리거가 자동으로
--      auth.users.id 를 public.users.auth_user_id 에 채움
--   3. 실제 이름·전화·이메일 변경 시 UPDATE users SET ... WHERE email = ...
-- =====================================================

BEGIN;

-- 1) branches (3개 지점)
INSERT INTO branches (name) VALUES
  ('내셔널짐 PT 용산점'),
  ('내셔널짐 PT 서초점'),
  ('내셔널짐 피티앤골프 스튜디오')
ON CONFLICT (name) DO NOTHING;

-- 2) users (admin 1명 + manager 2명, 더미 이메일·전화)
INSERT INTO users (email, name, phone, role) VALUES
  ('admin@nationalgym.local',        '최현승', '010-0000-0000', 'admin'),
  ('manager.jung@nationalgym.local', '정인재', '010-1111-1111', 'manager'),
  ('manager.kim@nationalgym.local',  '김근희', '010-2222-2222', 'manager')
ON CONFLICT (email) DO NOTHING;

-- 3) user_branches (매니저-지점 매핑)
--    정인재: 용산 + 서초
--    김근희: 스튜디오
--    admin(최현승)은 row 없음 → 전 지점 접근(is_admin() 경로)
INSERT INTO user_branches (user_id, branch_id)
SELECT u.id, b.id
FROM users u
CROSS JOIN branches b
WHERE
  (u.email = 'manager.jung@nationalgym.local'
    AND b.name IN ('내셔널짐 PT 용산점', '내셔널짐 PT 서초점'))
  OR
  (u.email = 'manager.kim@nationalgym.local'
    AND b.name = '내셔널짐 피티앤골프 스튜디오')
ON CONFLICT DO NOTHING;

COMMIT;
