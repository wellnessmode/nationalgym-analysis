class Note {
  final String ownerId;
  final String content;
  final String? sharedWithUserId; // null = 본인만 보는 private
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.ownerId,
    required this.content,
    required this.sharedWithUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isShared => sharedWithUserId != null;

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        ownerId: j['owner_id'] as String,
        content: (j['content'] as String?) ?? '',
        sharedWithUserId: j['shared_with_user_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
