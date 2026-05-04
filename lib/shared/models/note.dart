class Note {
  final String id;
  final String ownerId;
  final String title;
  final String content;
  final String? sharedWithUserId; // null = private
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.content,
    required this.sharedWithUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isShared => sharedWithUserId != null;

  /// iOS Notes-style: title 비어있으면 content 첫 줄을 제목으로 표시.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = content.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    return firstLine.trim();
  }

  /// 미리보기 (제목 줄 제외 본문)
  String get bodyPreview {
    if (title.trim().isNotEmpty) return content.trim();
    final lines = content.split('\n');
    final firstNonEmpty = lines.indexWhere((l) => l.trim().isNotEmpty);
    if (firstNonEmpty == -1) return '';
    return lines.skip(firstNonEmpty + 1).join('\n').trim();
  }

  Note copyWith({
    String? title,
    String? content,
    String? sharedWithUserId,
    bool clearShare = false,
    DateTime? updatedAt,
  }) =>
      Note(
        id: id,
        ownerId: ownerId,
        title: title ?? this.title,
        content: content ?? this.content,
        sharedWithUserId: clearShare ? null : (sharedWithUserId ?? this.sharedWithUserId),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        ownerId: j['owner_id'] as String,
        title: (j['title'] as String?) ?? '',
        content: (j['content'] as String?) ?? '',
        sharedWithUserId: j['shared_with_user_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
