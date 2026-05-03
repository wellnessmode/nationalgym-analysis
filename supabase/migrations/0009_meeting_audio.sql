-- =====================================================
-- 0009_meeting_audio.sql
-- 회의록 음성 녹음용 Storage 버킷 + meeting_notes 컬럼 추가
-- =====================================================

BEGIN;

-- 1) Storage 버킷 (auth된 매니저만 자기 지점 음성 업로드/조회)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'meeting-audio',
  'meeting-audio',
  false,
  52428800, -- 50 MB
  ARRAY['audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/aac', 'audio/x-m4a']
)
ON CONFLICT (id) DO NOTHING;

-- 2) RLS 정책: 인증 사용자가 업로드·조회 가능 (RLS는 회의록 자체에서 이미 지점 격리됨)
DROP POLICY IF EXISTS "auth_can_upload_meeting_audio" ON storage.objects;
CREATE POLICY "auth_can_upload_meeting_audio" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'meeting-audio');

DROP POLICY IF EXISTS "auth_can_read_meeting_audio" ON storage.objects;
CREATE POLICY "auth_can_read_meeting_audio" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'meeting-audio');

DROP POLICY IF EXISTS "auth_can_delete_meeting_audio" ON storage.objects;
CREATE POLICY "auth_can_delete_meeting_audio" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'meeting-audio');

-- 3) meeting_notes 에 녹음/전사 관련 컬럼 추가
ALTER TABLE public.meeting_notes
  ADD COLUMN IF NOT EXISTS recording_url text,
  ADD COLUMN IF NOT EXISTS transcription_status text NOT NULL DEFAULT 'none'
    CHECK (transcription_status IN ('none', 'pending', 'completed', 'failed'));

COMMENT ON COLUMN public.meeting_notes.recording_url IS 'Supabase Storage 내 음성 파일 경로 (meeting-audio 버킷)';
COMMENT ON COLUMN public.meeting_notes.transcription_status IS 'AI 전사 상태: none / pending / completed / failed';

COMMIT;
