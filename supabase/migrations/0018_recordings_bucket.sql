-- =====================================================
-- 0018_recordings_bucket.sql
-- 회의 / 메모 음성 녹음 저장용 Storage 버킷.
-- attachments 와 분리 — 자동 삭제 정책 적용 가능 + 권한 분리.
-- =====================================================

BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('recordings', 'recordings', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "recordings_authenticated_all" ON storage.objects;
CREATE POLICY "recordings_authenticated_all" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'recordings')
  WITH CHECK (bucket_id = 'recordings');

COMMIT;
