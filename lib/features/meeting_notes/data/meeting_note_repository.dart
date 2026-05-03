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
