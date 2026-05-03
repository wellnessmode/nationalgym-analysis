import 'enums.dart';

class MeetingNote {
  final String id;
  final String branchId;
  final String authorId;
  final MeetingStatus status;
  final DateTime meetingDate;
  final String? attendees;
  final String topic;
  final String? content;
  final String? actionItems;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MeetingNote({
    required this.id,
    required this.branchId,
    required this.authorId,
    required this.status,
    required this.meetingDate,
    required this.attendees,
    required this.topic,
    required this.content,
    required this.actionItems,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MeetingNote.fromJson(Map<String, dynamic> j) => MeetingNote(
        id: j['id'] as String,
        branchId: j['branch_id'] as String,
        authorId: j['author_id'] as String,
        status: MeetingStatusX.fromDb(j['status'] as String),
        meetingDate: DateTime.parse(j['meeting_date'] as String),
        attendees: j['attendees'] as String?,
        topic: j['topic'] as String,
        content: j['content'] as String?,
        actionItems: j['action_items'] as String?,
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

class MeetingComment {
  final String id;
  final String meetingNoteId;
  final String userId;
  final String content;
  final DateTime createdAt;

  MeetingComment({
    required this.id,
    required this.meetingNoteId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory MeetingComment.fromJson(Map<String, dynamic> j) => MeetingComment(
        id: j['id'] as String,
        meetingNoteId: j['meeting_note_id'] as String,
        userId: j['user_id'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
