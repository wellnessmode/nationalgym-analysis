import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../services/supabase_client.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/meeting_note.dart';

class MeetingNoteRepository {
  Future<List<MeetingNote>> list() async {
    final res = await supabase
        .from('meeting_notes')
        .select()
        .order('meeting_date', ascending: false);
    return (res as List).map((j) => MeetingNote.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<MeetingNote> getById(String id) async {
    final res = await supabase.from('meeting_notes').select().eq('id', id).single();
    return MeetingNote.fromJson(res);
  }

  Future<MeetingNote> create({
    required String branchId,
    required String authorId,
    required MeetingStatus status,
    required DateTime meetingDate,
    required String topic,
    String? attendees,
    String? content,
    String? actionItems,
  }) async {
    final patch = <String, dynamic>{
      'branch_id': branchId,
      'author_id': authorId,
      'status': status.dbValue,
      'meeting_date': meetingDate.toIso8601String().split('T').first,
      'topic': topic,
      'attendees': attendees,
      'content': content,
      'action_items': actionItems,
    };
    if (status == MeetingStatus.completed) {
      patch['completed_at'] = DateTime.now().toIso8601String();
    }
    final res = await supabase.from('meeting_notes').insert(patch).select().single();
    return MeetingNote.fromJson(res);
  }

  Future<MeetingNote> update(
    String id, {
    String? topic,
    String? attendees,
    String? content,
    String? actionItems,
    MeetingStatus? status,
    DateTime? meetingDate,
  }) async {
    final patch = <String, dynamic>{};
    if (topic != null) patch['topic'] = topic;
    if (attendees != null) patch['attendees'] = attendees;
    if (content != null) patch['content'] = content;
    if (actionItems != null) patch['action_items'] = actionItems;
    if (meetingDate != null) {
      patch['meeting_date'] = meetingDate.toIso8601String().split('T').first;
    }
    if (status != null) {
      patch['status'] = status.dbValue;
      if (status == MeetingStatus.completed) {
        patch['completed_at'] = DateTime.now().toIso8601String();
      }
    }
    final res = await supabase.from('meeting_notes').update(patch).eq('id', id).select().single();
    return MeetingNote.fromJson(res);
  }

  Future<void> delete(String id) async {
    await supabase.from('meeting_notes').delete().eq('id', id);
  }

  // ── Audio recording ──────────────────────────────────────────────

  /// Storage 'meeting-audio' 버킷에 음성 업로드.
  /// 경로: {meeting_note_id}/{timestamp}.{ext}
  /// 반환: storage path (DB recording_url에 저장).
  Future<String> uploadRecording({
    required String meetingNoteId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final ext = switch (mimeType) {
      'audio/webm' => 'webm',
      'audio/mp4' => 'm4a',
      'audio/mpeg' => 'mp3',
      'audio/wav' => 'wav',
      'audio/ogg' => 'ogg',
      _ => 'bin',
    };
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$meetingNoteId/$ts.$ext';
    await supabase.storage.from('meeting-audio').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return path;
  }

  /// recording_url + transcription_status='pending' 으로 업데이트
  Future<MeetingNote> attachRecording(String id, String recordingPath) async {
    final res = await supabase.from('meeting_notes').update({
      'recording_url': recordingPath,
      'transcription_status': 'pending',
    }).eq('id', id).select().single();
    return MeetingNote.fromJson(res);
  }

  /// Edge Function 'transcribe-meeting' 호출 → AI 전사 시작
  Future<void> requestTranscription(String meetingNoteId) async {
    await supabase.functions.invoke(
      'transcribe-meeting',
      body: {'meeting_note_id': meetingNoteId},
    );
  }

  /// 음성 파일 시그니처드 URL (재생용)
  Future<String?> getRecordingSignedUrl(String path) async {
    try {
      final res = await supabase.storage
          .from('meeting-audio')
          .createSignedUrl(path, 60 * 60); // 1시간
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Gemini Edge Function 호출 — 음성 인식 결과를 회의록 형식으로 정리.
  /// 무료 (Gemini 1.5 Flash 무료 티어).
  /// 반환: { content: String, action_items: String }
  Future<({String content, String actionItems})?> aiCleanup(String transcript) async {
    try {
      final res = await supabase.functions.invoke(
        'cleanup-meeting',
        body: {'transcript': transcript},
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) {
        return (
          content: (data['content'] as String?) ?? '',
          actionItems: (data['action_items'] as String?) ?? '',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Comments ─────────────────────────────────────────────────

  Future<List<MeetingComment>> listComments(String meetingNoteId) async {
    final res = await supabase
        .from('meeting_comments')
        .select()
        .eq('meeting_note_id', meetingNoteId)
        .order('created_at', ascending: true);
    return (res as List).map((j) => MeetingComment.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<MeetingComment> addComment({
    required String meetingNoteId,
    required String userId,
    required String content,
  }) async {
    final res = await supabase.from('meeting_comments').insert({
      'meeting_note_id': meetingNoteId,
      'user_id': userId,
      'content': content,
    }).select().single();
    return MeetingComment.fromJson(res);
  }
}
