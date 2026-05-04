import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../services/supabase_client.dart';
import '../../../shared/models/attachment.dart';

class AttachmentRepository {
  static const _bucket = 'attachments';

  Future<List<Attachment>> listForTask(String taskId) async {
    final res = await supabase
        .from('attachments')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    return (res as List).map((j) => Attachment.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Attachment>> listForMeeting(String meetingNoteId) async {
    final res = await supabase
        .from('attachments')
        .select()
        .eq('meeting_note_id', meetingNoteId)
        .order('created_at', ascending: true);
    return (res as List).map((j) => Attachment.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 파일 업로드 + 메타데이터 INSERT.
  /// 정확히 [taskId] 또는 [meetingNoteId] 중 하나만 지정해야 함.
  Future<Attachment> upload({
    required String uploaderId,
    String? taskId,
    String? meetingNoteId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    assert((taskId == null) != (meetingNoteId == null), 'taskId 또는 meetingNoteId 중 하나만');

    final parentSegment = taskId != null ? 'tasks/$taskId' : 'meetings/$meetingNoteId';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._\-가-힣]'), '_');
    final storagePath = '$parentSegment/${ts}_$safeName';

    await supabase.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    final res = await supabase
        .from('attachments')
        .insert({
          'task_id': taskId,
          'meeting_note_id': meetingNoteId,
          'uploader_id': uploaderId,
          'storage_path': storagePath,
          'file_name': fileName,
          'mime_type': mimeType,
          'size_bytes': bytes.length,
        })
        .select()
        .single();
    return Attachment.fromJson(res);
  }

  /// 미리보기/다운로드용 임시 서명 URL (1시간)
  Future<String> signedUrl(String storagePath) async {
    return supabase.storage.from(_bucket).createSignedUrl(storagePath, 3600);
  }

  Future<void> delete(Attachment a) async {
    // Storage 객체 먼저 (권한 있으면) → DB row
    try {
      await supabase.storage.from(_bucket).remove([a.storagePath]);
    } catch (_) {
      // Storage 삭제 실패해도 DB row는 지움 (RLS로 권한 없으면 어차피 막힘)
    }
    await supabase.from('attachments').delete().eq('id', a.id);
  }
}
