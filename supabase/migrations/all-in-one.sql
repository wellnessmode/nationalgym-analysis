-- =====================================================
-- all-in-one.sql
-- 4개 마이그레이션 파일 병합본
-- Supabase SQL Editor에 한 번에 붙여넣어 순서대로 실행 가능
-- 각 파일은 독립 트랜잭션 (BEGIN/COMMIT) 유지
-- =====================================================

-- =====================================================
-- 0001_schema.sql
-- 내셔널짐 PT 업무공유 PWA
-- Enums, Tables, Indexes, updated_at 트리거
-- =====================================================

BEGIN;

-- =====================================================
-- 1) Enums
-- =====================================================
CREATE TYPE user_role AS ENUM ('admin', 'manager');
CREATE TYPE task_type AS ENUM ('directive', 'manager_task');
CREATE TYPE task_priority AS ENUM ('low', 'normal', 'high', 'urgent');
CREATE TYPE task_status AS ENUM ('todo', 'in_progress', 'done', 'on_hold');
CREATE TYPE meeting_status AS ENUM ('draft', 'completed');
CREATE TYPE notification_ref_type AS ENUM (
  'task', 'task_comment', 'meeting_note', 'meeting_comment'
);
CREATE TYPE notification_type AS ENUM (
  'assigned',
  'due_soon',
  'overdue',
  'commented',
  'completed',
  'new_meeting_agenda',
  'meeting_completed'
);

-- =====================================================
-- 2) updated_at 자동 갱신 함수
-- =====================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3) Tables
-- =====================================================

-- 3-1) branches: 지점
CREATE TABLE branches (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE branches IS '내셔널짐 지점';
COMMENT ON COLUMN branches.name IS '지점 정식 명칭 (예: 내셔널짐 PT 용산점)';

-- 3-2) users: 앱 사용자 (Supabase Auth와 1:1 매칭)
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id  uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email         text NOT NULL UNIQUE,
  name          text NOT NULL,
  phone         text,
  role          user_role NOT NULL,
  fcm_token     text,
  created_at    timestamptz NOT NULL DEFAULT NOW(),
  updated_at    timestamptz NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE users IS '앱 사용자. Supabase Auth와 1:1 매칭';
COMMENT ON COLUMN users.auth_user_id IS 'auth.users.id 매칭. 0002 트리거로 자동 채움';
COMMENT ON COLUMN users.email IS '로그인 이메일. auth.users.email과 동일 유지';
COMMENT ON COLUMN users.role IS 'admin: 대표 / manager: 매니저';
COMMENT ON COLUMN users.fcm_token IS 'FCM 웹푸시 토큰. 로그아웃 시 NULL';

CREATE INDEX idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX idx_users_role ON users(role);

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3-3) user_branches: 매니저-지점 다대다
-- 정인재가 용산+서초 두 지점 담당하므로 다대다 필요
CREATE TABLE user_branches (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id  uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, branch_id)
);
COMMENT ON TABLE user_branches IS '매니저-지점 매핑. admin은 row 없음(전 지점 접근)';

CREATE INDEX idx_user_branches_branch_id ON user_branches(branch_id);

-- 3-4) tasks: 업무·지시사항
CREATE TABLE tasks (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id     uuid NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  task_type     task_type NOT NULL,
  title         text NOT NULL,
  content       text,
  requester_id  uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  assignee_id   uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  due_date      date,
  priority      task_priority NOT NULL DEFAULT 'normal',
  status        task_status NOT NULL DEFAULT 'todo',
  memo          text,
  completed_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT NOW(),
  updated_at    timestamptz NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE tasks IS '업무·지시사항';
COMMENT ON COLUMN tasks.task_type IS 'directive: 대표가 매니저에게 내리는 지시 / manager_task: 매니저 자체 업무';
COMMENT ON COLUMN tasks.requester_id IS '요청자(directive면 admin, manager_task면 본인)';
COMMENT ON COLUMN tasks.assignee_id IS '담당자';
COMMENT ON COLUMN tasks.completed_at IS 'status가 done으로 바뀐 시각';

CREATE INDEX idx_tasks_branch_id ON tasks(branch_id);
CREATE INDEX idx_tasks_assignee_id ON tasks(assignee_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);

CREATE TRIGGER trg_tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3-5) task_comments: 업무 댓글(진행 기록)
CREATE TABLE task_comments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  content     text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE task_comments IS '업무 댓글·진행 기록';

CREATE INDEX idx_task_comments_task_id ON task_comments(task_id);

-- 3-6) meeting_notes: 회의록
CREATE TABLE meeting_notes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id     uuid NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  author_id     uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status        meeting_status NOT NULL DEFAULT 'draft',
  meeting_date  date NOT NULL,
  attendees     text,
  topic         text NOT NULL,
  content       text,
  action_items  text,
  completed_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT NOW(),
  updated_at    timestamptz NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE meeting_notes IS '회의록 (업무와 별도)';
COMMENT ON COLUMN meeting_notes.status IS 'draft: 회의 전 어젠다 / completed: 회의 후 확정';
COMMENT ON COLUMN meeting_notes.attendees IS '참석자 자유 텍스트';
COMMENT ON COLUMN meeting_notes.content IS '회의 내용·진행 사항·결정사항. draft에서는 NULL 허용';
COMMENT ON COLUMN meeting_notes.action_items IS '후속 조치';
COMMENT ON COLUMN meeting_notes.completed_at IS 'status가 completed로 바뀐 시각';

CREATE INDEX idx_meeting_notes_branch_id ON meeting_notes(branch_id);
CREATE INDEX idx_meeting_notes_meeting_date ON meeting_notes(meeting_date DESC);
CREATE INDEX idx_meeting_notes_status ON meeting_notes(status);

CREATE TRIGGER trg_meeting_notes_updated_at
  BEFORE UPDATE ON meeting_notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3-7) meeting_comments: 회의록 댓글
CREATE TABLE meeting_comments (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_note_id  uuid NOT NULL REFERENCES meeting_notes(id) ON DELETE CASCADE,
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  content          text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE meeting_comments IS '회의록 댓글';

CREATE INDEX idx_meeting_comments_meeting_note_id
  ON meeting_comments(meeting_note_id);

-- 3-8) notifications: 인앱 알림
CREATE TABLE notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ref_type    notification_ref_type NOT NULL,
  ref_id      uuid NOT NULL,
  type        notification_type NOT NULL,
  message     text NOT NULL,
  is_read     boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE notifications IS '인앱 알림. FCM 푸시와는 별도로 DB에도 적재';
COMMENT ON COLUMN notifications.ref_type IS '연결 대상 종류 (task / task_comment / meeting_note / meeting_comment)';
COMMENT ON COLUMN notifications.ref_id IS '연결 대상 PK. ref_type에 따라 어느 테이블인지 결정';

CREATE INDEX idx_notifications_user_id_created_at
  ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_user_id_is_read
  ON notifications(user_id, is_read);

COMMIT;

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

-- =====================================================
-- 0003_rls.sql
-- 내셔널짐 PT 업무공유 PWA
-- RLS 활성화 + 정책 전체
--
-- 명명 규칙: <table>_<action>_<scope>
--   action: select / insert / update / delete / all
--   scope:  admin / self / branch / authenticated / etc.
-- 같은 (table, action) 정책이 여러 개면 PostgreSQL이 OR 평가.
-- =====================================================

BEGIN;

-- =====================================================
-- 1) RLS 활성화
-- =====================================================
ALTER TABLE branches         ENABLE ROW LEVEL SECURITY;
ALTER TABLE users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_branches    ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks            ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_notes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications    ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 2) branches
-- 모든 인증 사용자 SELECT, 쓰기는 admin만
-- =====================================================
CREATE POLICY "branches_select_authenticated" ON branches
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "branches_all_admin" ON branches
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- =====================================================
-- 3) users
-- 모든 인증 사용자 SELECT (UI에서 이름·역할 표시 필요)
-- UPDATE는 admin 또는 본인만 (manager는 fcm_token 갱신용)
-- INSERT/DELETE 정책 없음 → 클라이언트 차단. admin이 SQL Editor에서 수동.
-- =====================================================
CREATE POLICY "users_select_authenticated" ON users
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "users_update_admin_or_self" ON users
  FOR UPDATE TO authenticated
  USING (is_admin() OR id = current_user_id())
  WITH CHECK (is_admin() OR id = current_user_id());

-- =====================================================
-- 4) user_branches
-- admin 전체 CRUD, manager는 본인 매핑만 SELECT
-- =====================================================
CREATE POLICY "user_branches_select_self_or_admin" ON user_branches
  FOR SELECT TO authenticated
  USING (is_admin() OR user_id = current_user_id());

CREATE POLICY "user_branches_all_admin" ON user_branches
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- =====================================================
-- 5) tasks
-- =====================================================

-- 5-1) SELECT: 접근 가능한 지점의 task 모두
CREATE POLICY "tasks_select_branch" ON tasks
  FOR SELECT TO authenticated
  USING (user_has_branch(branch_id));

-- 5-2) INSERT(admin): directive만, 본인이 requester
CREATE POLICY "tasks_insert_admin_directive" ON tasks
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    AND task_type = 'directive'
    AND requester_id = current_user_id()
  );

-- 5-3) INSERT(manager): manager_task만, 본인 지점, 본인이 requester+assignee
CREATE POLICY "tasks_insert_manager_self" ON tasks
  FOR INSERT TO authenticated
  WITH CHECK (
    NOT is_admin()
    AND task_type = 'manager_task'
    AND user_has_branch(branch_id)
    AND requester_id = current_user_id()
    AND assignee_id = current_user_id()
  );

-- 5-4) UPDATE(admin): 전체
CREATE POLICY "tasks_update_admin" ON tasks
  FOR UPDATE TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- 5-5) UPDATE(manager): 본인이 assignee 또는 requester인 task
-- 컬럼 단위(status·memo만) 제한은 앱 레이어에서 처리
CREATE POLICY "tasks_update_manager_involved" ON tasks
  FOR UPDATE TO authenticated
  USING (
    NOT is_admin()
    AND user_has_branch(branch_id)
    AND (assignee_id = current_user_id() OR requester_id = current_user_id())
  )
  WITH CHECK (
    user_has_branch(branch_id)
    AND (assignee_id = current_user_id() OR requester_id = current_user_id())
  );

-- 5-6) DELETE: admin만
CREATE POLICY "tasks_delete_admin" ON tasks
  FOR DELETE TO authenticated
  USING (is_admin());

-- =====================================================
-- 6) task_comments
-- =====================================================

CREATE POLICY "task_comments_select_branch" ON task_comments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tasks t
      WHERE t.id = task_comments.task_id
        AND user_has_branch(t.branch_id)
    )
  );

CREATE POLICY "task_comments_insert_branch_self" ON task_comments
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = current_user_id()
    AND EXISTS (
      SELECT 1 FROM tasks t
      WHERE t.id = task_comments.task_id
        AND user_has_branch(t.branch_id)
    )
  );

CREATE POLICY "task_comments_delete_admin" ON task_comments
  FOR DELETE TO authenticated
  USING (is_admin());

-- =====================================================
-- 7) meeting_notes
-- =====================================================

-- 7-1) SELECT: 접근 가능 지점
CREATE POLICY "meeting_notes_select_branch" ON meeting_notes
  FOR SELECT TO authenticated
  USING (user_has_branch(branch_id));

-- 7-2) INSERT: 본인 지점 + 본인이 author
CREATE POLICY "meeting_notes_insert_branch_self" ON meeting_notes
  FOR INSERT TO authenticated
  WITH CHECK (
    user_has_branch(branch_id)
    AND author_id = current_user_id()
  );

-- 7-3) UPDATE(admin): 전체
CREATE POLICY "meeting_notes_update_admin" ON meeting_notes
  FOR UPDATE TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- 7-4) UPDATE(manager): 본인 작성분만 (draft↔completed 전환 포함)
CREATE POLICY "meeting_notes_update_author" ON meeting_notes
  FOR UPDATE TO authenticated
  USING (
    NOT is_admin()
    AND author_id = current_user_id()
    AND user_has_branch(branch_id)
  )
  WITH CHECK (
    author_id = current_user_id()
    AND user_has_branch(branch_id)
  );

-- 7-5) DELETE: admin 또는 본인 작성분
CREATE POLICY "meeting_notes_delete_admin_or_author" ON meeting_notes
  FOR DELETE TO authenticated
  USING (
    is_admin()
    OR (author_id = current_user_id() AND user_has_branch(branch_id))
  );

-- =====================================================
-- 8) meeting_comments
-- =====================================================

CREATE POLICY "meeting_comments_select_branch" ON meeting_comments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM meeting_notes m
      WHERE m.id = meeting_comments.meeting_note_id
        AND user_has_branch(m.branch_id)
    )
  );

CREATE POLICY "meeting_comments_insert_branch_self" ON meeting_comments
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = current_user_id()
    AND EXISTS (
      SELECT 1 FROM meeting_notes m
      WHERE m.id = meeting_comments.meeting_note_id
        AND user_has_branch(m.branch_id)
    )
  );

CREATE POLICY "meeting_comments_delete_admin" ON meeting_comments
  FOR DELETE TO authenticated
  USING (is_admin());

-- =====================================================
-- 9) notifications
-- 본인 것만 SELECT/UPDATE. INSERT/DELETE는 service_role(Edge Function) 전용.
-- =====================================================
CREATE POLICY "notifications_select_self" ON notifications
  FOR SELECT TO authenticated
  USING (user_id = current_user_id());

CREATE POLICY "notifications_update_self" ON notifications
  FOR UPDATE TO authenticated
  USING (user_id = current_user_id())
  WITH CHECK (user_id = current_user_id());

COMMIT;

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
