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
