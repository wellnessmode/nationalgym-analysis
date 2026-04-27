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
